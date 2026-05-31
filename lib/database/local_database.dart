import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/app_models.dart';

class LocalDatabase {
  static const shopsBox = 'shops';
  static const usersBox = 'users';
  static const productsBox = 'products';
  static const billsBox = 'bills';
  static const customersBox = 'customers';
  static const suppliersBox = 'suppliers';
  static const stockMovementsBox = 'stock_movements';
  static const settingsBox = 'settings';
  static const _remoteSyncTimeout = Duration(seconds: 2);

  bool _importingRemote = false;

  Future<void> initialize() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(shopsBox),
      Hive.openBox(usersBox),
      Hive.openBox(productsBox),
      Hive.openBox(billsBox),
      Hive.openBox(customersBox),
      Hive.openBox(suppliersBox),
      Hive.openBox(stockMovementsBox),
      Hive.openBox(settingsBox),
    ]);
    await _pullRemoteIfAvailable();
    await _seedIfNeeded();
    await _ensureDefaultUsers();
    if (!_importingRemote) await _pushRemoteIfAvailable();
  }

  Box get _shops => Hive.box(shopsBox);
  Box get _users => Hive.box(usersBox);
  Box get _products => Hive.box(productsBox);
  Box get _bills => Hive.box(billsBox);
  Box get _customers => Hive.box(customersBox);
  Box get _suppliers => Hive.box(suppliersBox);
  Box get _stockMovements => Hive.box(stockMovementsBox);
  Box get _settings => Hive.box(settingsBox);

  List<Shop> getShops() =>
      _shops.values
          .map(
            (value) => Shop.fromMap(Map<dynamic, dynamic>.from(value as Map)),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<Shop> getShopsForUser(AppUser? user) {
    final shops = getShops();
    if (user == null) return const [];
    if (user.role == UserRole.admin) {
      return shops.where((shop) => shop.ownerAdminId == user.id).toList();
    }
    return shops.where((shop) => shop.id == user.shopId).toList();
  }

  Future<void> saveShop(Shop shop) async {
    await _shops.put(shop.id, shop.toMap());
    await _pushRemoteIfAvailable();
  }

  String? getSelectedShopId() => _settings.get('selectedShopId') as String?;

  Future<void> setSelectedShopId(String shopId) =>
      _settings.put('selectedShopId', shopId);

  AppUser? currentUser() {
    final userId = _settings.get('currentUserId') as String?;
    if (userId == null || !_users.containsKey(userId)) return null;
    return AppUser.fromMap(
      Map<dynamic, dynamic>.from(_users.get(userId) as Map),
    );
  }

  List<AppUser> getUsers({String? shopId}) {
    final users = _users.values
        .map(
          (value) => AppUser.fromMap(Map<dynamic, dynamic>.from(value as Map)),
        )
        .toList();
    if (shopId == null) return users;
    final shopValue = _shops.get(shopId);
    final ownerAdminId = shopValue == null
        ? null
        : Shop.fromMap(
            Map<dynamic, dynamic>.from(shopValue as Map),
          ).ownerAdminId;
    return users
        .where(
          (user) =>
              (user.role == UserRole.admin && user.id == ownerAdminId) ||
              user.shopId == shopId,
        )
        .toList();
  }

  Future<void> saveUser(AppUser user) async {
    await _users.put(user.id, user.toMap());
    await _pushRemoteIfAvailable();
  }

  Future<void> deleteUser(String id) async {
    await _users.delete(id);
    await _pushRemoteIfAvailable();
  }

  bool emailExists(String email, {String? exceptUserId}) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    for (final value in _users.values) {
      final user = AppUser.fromMap(Map<dynamic, dynamic>.from(value as Map));
      if (user.id == exceptUserId) continue;
      if (user.email.trim().toLowerCase() == normalized) return true;
    }
    return false;
  }

  Future<AppUser?> loginWithPin(String pin, {String email = ''}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;
    final remoteUser = await _remoteLogin(normalizedEmail, pin);
    if (remoteUser != null) return remoteUser;
    await _pullRemoteIfAvailable(force: true);
    for (final value in _users.values) {
      final user = AppUser.fromMap(Map<dynamic, dynamic>.from(value as Map));
      final emailMatches = user.email.trim().toLowerCase() == normalizedEmail;
      if (user.pin == pin && emailMatches) {
        final updated = user.copyWith(
          isLoggedIn: true,
          lastLoginAt: DateTime.now(),
          lastSeenAt: DateTime.now(),
        );
        await _users.put(updated.id, updated.toMap());
        await _settings.put('currentUserId', updated.id);
        await _pushRemoteIfAvailable();
        return updated;
      }
    }
    return null;
  }

  Future<AppUser?> _remoteLogin(String email, String password) async {
    final uri = _remoteAuthUri();
    if (uri == null) return null;
    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_remoteSyncTimeout);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['success'] != true) return null;
      final data = decoded['data'];
      if (data is! Map) return null;
      final database = data['database'];
      final userData = data['user'];
      if (database is Map) {
        final localSettings = Map<dynamic, dynamic>.from(_settings.toMap());
        _importingRemote = true;
        await importBackup(Map<String, dynamic>.from(database));
        await _settings.clear();
        for (final entry in localSettings.entries) {
          await _settings.put(entry.key, entry.value);
        }
        _importingRemote = false;
      }
      if (userData is! Map) return null;
      final user = AppUser.fromMap(Map<dynamic, dynamic>.from(userData));
      final updated = user.copyWith(
        isLoggedIn: true,
        lastLoginAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      );
      await _users.put(updated.id, updated.toMap());
      await _settings.put('currentUserId', updated.id);
      await _pushRemoteIfAvailable();
      return updated;
    } catch (_) {
      _importingRemote = false;
      return null;
    }
  }

  Future<void> logout() async {
    final user = currentUser();
    if (user != null) {
      await _users.put(
        user.id,
        user
            .copyWith(
              isLoggedIn: false,
              lastLogoutAt: DateTime.now(),
              lastSeenAt: DateTime.now(),
            )
            .toMap(),
      );
      await _pushRemoteIfAvailable();
    }
    await _settings.delete('currentUserId');
  }

  Future<void> touchCurrentUser() async {
    final user = currentUser();
    if (user == null) return;
    await _users.put(
      user.id,
      user.copyWith(isLoggedIn: true, lastSeenAt: DateTime.now()).toMap(),
    );
    await _pushRemoteIfAvailable();
  }

  Future<void> clearSelectedShop() => _settings.delete('selectedShopId');

  Future<void> setCurrentUser(String userId) =>
      _settings.put('currentUserId', userId);

  List<Product> getProducts(String shopId, {bool includePending = false}) =>
      _products.values
          .map(
            (value) =>
                Product.fromMap(Map<dynamic, dynamic>.from(value as Map)),
          )
          .where(
            (product) =>
                product.shopId == shopId &&
                (includePending ||
                    product.approvalStatus == ApprovalStatus.approved),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> saveProduct(Product product) async {
    await _products.put(product.id, product.toMap());
    await _pushRemoteIfAvailable();
  }

  Future<void> deleteProduct(String id) async {
    await _products.delete(id);
    await _pushRemoteIfAvailable();
  }

  List<Bill> getBills(String shopId) =>
      _bills.values
          .map(
            (value) => Bill.fromMap(Map<dynamic, dynamic>.from(value as Map)),
          )
          .where((bill) => bill.shopId == shopId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> saveBill(Bill bill) async {
    await _bills.put(bill.id, bill.toMap());
    if (bill.status == BillStatus.paid) {
      for (final item in bill.items) {
        final product = item.product.copyWith(
          stockQuantity: item.product.stockQuantity - item.quantity,
        );
        await saveProduct(product);
        await saveStockMovement(
          StockMovement(
            id: _id('stock'),
            shopId: bill.shopId,
            productId: product.id,
            quantity: -item.quantity,
            type: StockMovementType.sale,
            createdAt: bill.createdAt,
            note: bill.invoiceNumber,
          ),
        );
      }
    }
    await _pushRemoteIfAvailable();
  }

  List<Customer> getCustomers(String shopId, {bool includePending = false}) =>
      _customers.values
          .map(
            (value) =>
                Customer.fromMap(Map<dynamic, dynamic>.from(value as Map)),
          )
          .where(
            (customer) =>
                customer.shopId == shopId &&
                (includePending ||
                    customer.approvalStatus == ApprovalStatus.approved),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> saveCustomer(Customer customer) async {
    await _customers.put(customer.id, customer.toMap());
    await _pushRemoteIfAvailable();
  }

  Future<void> deleteCustomer(String id) async {
    await _customers.delete(id);
    await _pushRemoteIfAvailable();
  }

  List<Supplier> getSuppliers(String shopId, {bool includePending = false}) =>
      _suppliers.values
          .map(
            (value) =>
                Supplier.fromMap(Map<dynamic, dynamic>.from(value as Map)),
          )
          .where(
            (supplier) =>
                supplier.shopId == shopId &&
                (includePending ||
                    supplier.approvalStatus == ApprovalStatus.approved),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> saveSupplier(Supplier supplier) async {
    await _suppliers.put(supplier.id, supplier.toMap());
    await _pushRemoteIfAvailable();
  }

  List<StockMovement> getStockMovements(String shopId) =>
      _stockMovements.values
          .map(
            (value) =>
                StockMovement.fromMap(Map<dynamic, dynamic>.from(value as Map)),
          )
          .where((movement) => movement.shopId == shopId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> saveStockMovement(StockMovement movement) async {
    await _stockMovements.put(movement.id, movement.toMap());
    await _pushRemoteIfAvailable();
  }

  Future<void> purchaseStock({
    required Product product,
    required double quantity,
    String? supplierId,
    String note = 'Purchase stock',
  }) async {
    await saveProduct(
      product.copyWith(stockQuantity: product.stockQuantity + quantity),
    );
    await saveStockMovement(
      StockMovement(
        id: _id('stock'),
        shopId: product.shopId,
        productId: product.id,
        quantity: quantity,
        type: StockMovementType.purchase,
        createdAt: DateTime.now(),
        supplierId: supplierId,
        note: note,
      ),
    );
  }

  Map<String, dynamic> exportBackup() => {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'shops': _shops.values.toList(),
    'users': _users.values.toList(),
    'products': _products.values.toList(),
    'bills': _bills.values.toList(),
    'customers': _customers.values.toList(),
    'suppliers': _suppliers.values.toList(),
    'stockMovements': _stockMovements.values.toList(),
    'settings': Map<String, dynamic>.from(_settings.toMap()),
  };

  Future<void> importBackup(Map<String, dynamic> backup) async {
    if (backup['version'] != 1) {
      throw const FormatException('Unsupported backup version');
    }
    await Future.wait([
      _shops.clear(),
      _users.clear(),
      _products.clear(),
      _bills.clear(),
      _customers.clear(),
      _suppliers.clear(),
      _stockMovements.clear(),
      _settings.clear(),
    ]);
    await _putRecords(_shops, backup['shops']);
    await _putRecords(_users, backup['users']);
    await _putRecords(_products, backup['products']);
    await _putRecords(_bills, backup['bills']);
    await _putRecords(_customers, backup['customers']);
    await _putRecords(_suppliers, backup['suppliers']);
    await _putRecords(_stockMovements, backup['stockMovements']);
    final settings = backup['settings'];
    if (settings is Map) {
      for (final entry in settings.entries) {
        await _settings.put(entry.key, entry.value);
      }
    }
    await _ensureDefaultUsers();
    if (getSelectedShopId() == null && _shops.isNotEmpty) {
      final firstShop = Shop.fromMap(
        Map<dynamic, dynamic>.from(_shops.values.first as Map),
      );
      await setSelectedShopId(firstShop.id);
    }
    await _pushRemoteIfAvailable();
  }

  Future<void> _putRecords(Box box, Object? records) async {
    if (records is! List) return;
    for (final record in records) {
      if (record is! Map || record['id'] == null) continue;
      await box.put(record['id'], Map<String, dynamic>.from(record));
    }
  }

  Future<void> _pullRemoteIfAvailable({bool force = false}) async {
    final uri = _remoteDatabaseUri();
    if (uri == null) return;
    try {
      final response = await http.get(uri).timeout(_remoteSyncTimeout);
      if (response.statusCode != 200) return;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return;
      final data = decoded['data'];
      if (data is! Map) return;
      final backup = Map<String, dynamic>.from(data);
      if (!_hasBusinessData(backup) && _hasLocalBusinessData() && !force) {
        return;
      }
      if (!_hasBusinessData(backup)) return;
      final localSettings = Map<dynamic, dynamic>.from(_settings.toMap());
      _importingRemote = true;
      await importBackup(backup);
      await _settings.clear();
      for (final entry in localSettings.entries) {
        await _settings.put(entry.key, entry.value);
      }
    } catch (_) {
      // Keep local/offline mode when the laptop server is unavailable.
    } finally {
      _importingRemote = false;
    }
  }

  Future<void> _pushRemoteIfAvailable() async {
    final uri = _remoteDatabaseUri();
    if (uri == null || _importingRemote) return;
    try {
      final backup = exportBackup();
      backup['settings'] = <String, dynamic>{};
      await http
          .put(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(backup),
          )
          .timeout(_remoteSyncTimeout);
    } catch (_) {
      // Keep local/offline mode when the laptop server is unavailable.
    }
  }

  Uri? _remoteDatabaseUri() {
    final base = _remoteBaseUrl();
    return base == null ? null : Uri.tryParse('$base/api/smart-shop/database');
  }

  Uri? _remoteAuthUri() {
    final base = _remoteBaseUrl();
    return base == null
        ? null
        : Uri.tryParse('$base/api/smart-shop/auth/login');
  }

  String? _remoteBaseUrl() {
    const configured = String.fromEnvironment('SMART_SHOP_SERVER_URL');
    return configured.isNotEmpty
        ? configured
        : kIsWeb && Uri.base.host.isNotEmpty
        ? 'http://${Uri.base.host}:9090'
        : 'http://localhost:9090';
  }

  bool _hasLocalBusinessData() {
    return _shops.isNotEmpty ||
        _users.isNotEmpty ||
        _products.isNotEmpty ||
        _bills.isNotEmpty ||
        _customers.isNotEmpty ||
        _suppliers.isNotEmpty ||
        _stockMovements.isNotEmpty;
  }

  bool _hasBusinessData(Map<String, dynamic> backup) {
    for (final key in [
      'shops',
      'users',
      'products',
      'bills',
      'customers',
      'suppliers',
      'stockMovements',
    ]) {
      final value = backup[key];
      if (value is List && value.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _seedIfNeeded() async {
    if (_shops.isNotEmpty) return;
    final now = DateTime.now();
    final grocery = Shop(
      id: 'shop_grocery',
      name: 'Green Mart',
      type: 'Grocery',
      currency: 'PKR',
      ownerAdminId: 'admin',
      address: 'Main Market',
      phone: '+92 300 0000000',
      createdAt: now,
      themeSeed: 0xff0f766e,
    );
    final pharmacy = Shop(
      id: 'shop_pharmacy',
      name: 'Care Pharmacy',
      type: 'Pharmacy',
      currency: 'PKR',
      ownerAdminId: 'admin',
      address: 'Clinic Road',
      phone: '+92 301 1111111',
      createdAt: now,
      themeSeed: 0xff2563eb,
    );
    await saveShop(grocery);
    await saveShop(pharmacy);
    await setSelectedShopId(grocery.id);
    await _ensureDefaultUsers();
    final products = [
      Product(
        id: 'p_rice',
        shopId: grocery.id,
        name: 'Basmati Rice',
        sku: '8901001',
        category: 'Grains',
        buyingPrice: 260,
        sellingPrice: 310,
        stockQuantity: 42,
        unit: 'kg',
        lowStockThreshold: 10,
      ),
      Product(
        id: 'p_milk',
        shopId: grocery.id,
        name: 'Fresh Milk 1L',
        sku: '8901002',
        category: 'Dairy',
        buyingPrice: 185,
        sellingPrice: 220,
        stockQuantity: 18,
        unit: 'pcs',
        taxPercent: 2,
        expiryDate: now.add(const Duration(days: 8)),
      ),
      Product(
        id: 'p_shampoo',
        shopId: grocery.id,
        name: 'Herbal Shampoo',
        sku: '8901003',
        category: 'Personal Care',
        buyingPrice: 390,
        sellingPrice: 520,
        stockQuantity: 7,
        unit: 'pcs',
        discountPercent: 5,
      ),
      Product(
        id: 'p_panadol',
        shopId: pharmacy.id,
        name: 'Paracetamol 500mg',
        sku: 'RX5001',
        category: 'Medicine',
        buyingPrice: 26,
        sellingPrice: 35,
        stockQuantity: 120,
        unit: 'strip',
        expiryDate: now.add(const Duration(days: 180)),
      ),
      Product(
        id: 'p_syrup',
        shopId: pharmacy.id,
        name: 'Cough Syrup',
        sku: 'RX5002',
        category: 'Medicine',
        buyingPrice: 145,
        sellingPrice: 190,
        stockQuantity: 9,
        unit: 'bottle',
        lowStockThreshold: 12,
        taxPercent: 1,
        expiryDate: now.add(const Duration(days: 22)),
      ),
    ];
    for (final product in products) {
      await saveProduct(product);
    }
    await saveCustomer(
      Customer(id: 'c_walkin', shopId: grocery.id, name: 'Walk-in Customer'),
    );
    await saveSupplier(
      Supplier(
        id: 's_wholesale',
        shopId: grocery.id,
        name: 'City Wholesale',
        phone: '+92 302 2222222',
        company: 'City Distribution',
      ),
    );
  }

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  Future<void> _ensureDefaultUsers() async {
    final defaultShopId = getShops().isEmpty ? null : getShops().first.id;
    Future<void> putIfMissing(AppUser user) async {
      if (!_users.containsKey(user.id)) await _users.put(user.id, user.toMap());
    }

    await putIfMissing(
      const AppUser(
        id: 'admin',
        name: 'Admin',
        email: 'admin@smartshop.local',
        pin: 'Admin@123',
        role: UserRole.admin,
      ),
    );
    await putIfMissing(
      AppUser(
        id: 'editor',
        name: 'Editor',
        email: 'editor@smartshop.local',
        pin: 'Editor@123',
        role: UserRole.editor,
        shopId: defaultShopId,
      ),
    );
    await putIfMissing(
      AppUser(
        id: 'seller',
        name: 'Seller',
        email: 'seller@smartshop.local',
        pin: 'Seller@123',
        role: UserRole.seller,
        shopId: defaultShopId,
      ),
    );
    await _upgradeDefaultPassword('admin', '1234', 'Admin@123');
    await _upgradeDefaultPassword('editor', '2222', 'Editor@123');
    await _upgradeDefaultPassword('seller', '0000', 'Seller@123');
    await _assignDefaultEmailIfMissing('admin', 'admin@smartshop.local');
    await _assignDefaultEmailIfMissing('editor', 'editor@smartshop.local');
    await _assignDefaultEmailIfMissing('seller', 'seller@smartshop.local');
    if (defaultShopId != null) {
      await _assignLegacyShopOwner('admin');
      await _assignDefaultShopIfMissing('editor', defaultShopId);
      await _assignDefaultShopIfMissing('seller', defaultShopId);
    }
  }

  Future<void> _upgradeDefaultPassword(
    String id,
    String oldPassword,
    String newPassword,
  ) async {
    final value = _users.get(id);
    if (value == null) return;
    final user = AppUser.fromMap(Map<dynamic, dynamic>.from(value as Map));
    if (user.pin == oldPassword) {
      await _users.put(id, user.copyWith(pin: newPassword).toMap());
    }
  }

  Future<void> _assignDefaultShopIfMissing(String id, String shopId) async {
    final value = _users.get(id);
    if (value == null) return;
    final user = AppUser.fromMap(Map<dynamic, dynamic>.from(value as Map));
    if (user.role != UserRole.admin && user.shopId == null) {
      await _users.put(id, user.copyWith(shopId: shopId).toMap());
    }
  }

  Future<void> _assignDefaultEmailIfMissing(String id, String email) async {
    final value = _users.get(id);
    if (value == null) return;
    final user = AppUser.fromMap(Map<dynamic, dynamic>.from(value as Map));
    if (user.email.trim().isEmpty) {
      await _users.put(id, user.copyWith(email: email).toMap());
    }
  }

  Future<void> _assignLegacyShopOwner(String adminId) async {
    for (final key in _shops.keys) {
      final shop = Shop.fromMap(
        Map<dynamic, dynamic>.from(_shops.get(key) as Map),
      );
      if (shop.ownerAdminId == null) {
        await _shops.put(key, shop.copyWith(ownerAdminId: adminId).toMap());
      }
    }
  }
}
