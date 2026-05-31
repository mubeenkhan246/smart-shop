import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../database/local_database.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';
import '../utils/password_rules.dart';

final databaseProvider = Provider<LocalDatabase>(
  (ref) => throw UnimplementedError(),
);

final shopsProvider = StateNotifierProvider<ShopsController, List<Shop>>((ref) {
  return ShopsController(ref.watch(databaseProvider), ref.watch(authProvider));
});

final selectedShopProvider =
    StateNotifierProvider<SelectedShopController, Shop?>((ref) {
      return SelectedShopController(
        ref.watch(databaseProvider),
        ref.watch(shopsProvider),
      );
    });

final authProvider = StateNotifierProvider<AuthController, AppUser?>((ref) {
  return AuthController(ref.watch(databaseProvider));
});

final usersProvider = StateNotifierProvider<UsersController, List<AppUser>>((
  ref,
) {
  final user = ref.watch(authProvider);
  final shop = ref.watch(selectedShopProvider);
  return UsersController(ref.watch(databaseProvider), user, shop?.id);
});

final productsProvider =
    StateNotifierProvider<ProductsController, List<Product>>((ref) {
      final shop = ref.watch(selectedShopProvider);
      final user = ref.watch(authProvider);
      return ProductsController(ref.watch(databaseProvider), shop?.id, user);
    });

final billsProvider = StateNotifierProvider<BillsController, List<Bill>>((ref) {
  final shop = ref.watch(selectedShopProvider);
  return BillsController(ref.watch(databaseProvider), shop?.id);
});

final customersProvider =
    StateNotifierProvider<CustomersController, List<Customer>>((ref) {
      final shop = ref.watch(selectedShopProvider);
      final user = ref.watch(authProvider);
      return CustomersController(ref.watch(databaseProvider), shop?.id, user);
    });

final suppliersProvider =
    StateNotifierProvider<SuppliersController, List<Supplier>>((ref) {
      final shop = ref.watch(selectedShopProvider);
      final user = ref.watch(authProvider);
      return SuppliersController(ref.watch(databaseProvider), shop?.id, user);
    });

final stockMovementsProvider =
    StateNotifierProvider<StockMovementsController, List<StockMovement>>((ref) {
      final shop = ref.watch(selectedShopProvider);
      return StockMovementsController(ref.watch(databaseProvider), shop?.id);
    });

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController(ref);
});

final dashboardProvider = Provider<DashboardStats>((ref) {
  final products = ref.watch(productsProvider);
  final bills = ref.watch(billsProvider);
  final now = DateTime.now();
  final paidBills = bills.where((bill) => bill.status == BillStatus.paid);
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfWeek = startOfToday.subtract(
    Duration(days: startOfToday.weekday - DateTime.monday),
  );
  final startOfMonth = DateTime(now.year, now.month);
  final startOfYear = DateTime(now.year);
  double totalSince(DateTime start) => paidBills
      .where(
        (bill) =>
            !bill.createdAt.isBefore(start) && !bill.createdAt.isAfter(now),
      )
      .fold(0.0, (sum, bill) => sum + bill.grandTotal);
  return DashboardStats(
    todaySales: totalSince(startOfToday),
    weekSales: totalSince(startOfWeek),
    monthSales: totalSince(startOfMonth),
    yearSales: totalSince(startOfYear),
    profit: paidBills.fold(0.0, (sum, bill) => sum + bill.profit),
    lowStock: products.where((product) => product.isLowStock).length,
    expiringSoon: products.where((product) => product.isExpiringSoon).length,
    billsCount: paidBills.length,
    inventoryValue: products.fold(
      0.0,
      (sum, product) => sum + product.buyingPrice * product.stockQuantity,
    ),
  );
});

class ShopsController extends StateNotifier<List<Shop>> {
  ShopsController(this._database, this._user)
    : super(_database.getShopsForUser(_user));
  final LocalDatabase _database;
  final AppUser? _user;

  Future<void> addShop(Shop shop) async {
    await _database.saveShop(shop);
    state = _database.getShopsForUser(_user);
  }
}

class SelectedShopController extends StateNotifier<Shop?> {
  SelectedShopController(this._database, List<Shop> shops)
    : super(_resolveInitial(_database, shops));

  final LocalDatabase _database;

  static Shop? _resolveInitial(LocalDatabase database, List<Shop> shops) {
    if (shops.isEmpty) return null;
    final selectedId = database.getSelectedShopId();
    if (selectedId == null) return null;
    return shops.firstWhere(
      (shop) => shop.id == selectedId,
      orElse: () => shops.first,
    );
  }

  Future<void> select(Shop shop) async {
    await _database.setSelectedShopId(shop.id);
    state = shop;
  }
}

class AuthController extends StateNotifier<AppUser?> {
  AuthController(this._database) : super(_database.currentUser());
  final LocalDatabase _database;

  Future<bool> login(String pin, {String email = ''}) async {
    if (email.trim().isEmpty) return false;
    final user = await _database.loginWithPin(pin, email: email);
    if (user != null) await _database.clearSelectedShop();
    state = user;
    return user != null;
  }

  Future<void> markSeen() async {
    await _database.touchCurrentUser();
    state = _database.currentUser();
  }

  Future<String?> registerAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) return 'Name is required.';
    if (!_validEmail(cleanEmail)) return 'Enter a valid email.';
    final passwordError = validateStrongPassword(password);
    if (passwordError != null) return passwordError;
    if (_database.emailExists(cleanEmail)) {
      return 'This email is already registered.';
    }
    final user = AppUser(
      id: newId('admin'),
      name: cleanName,
      email: cleanEmail,
      pin: password,
      role: UserRole.admin,
    );
    await _database.saveUser(user);
    await _database.setCurrentUser(user.id);
    await _database.touchCurrentUser();
    await _database.clearSelectedShop();
    state = _database.currentUser();
    return null;
  }

  Future<String?> updateAdminProfile({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = state;
    if (user == null || user.role != UserRole.admin) return 'Admin not found.';
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.isEmpty) return 'Name is required.';
    if (!_validEmail(cleanEmail)) return 'Enter a valid email.';
    final passwordError = validateStrongPassword(password);
    if (passwordError != null) return passwordError;
    if (_database.emailExists(cleanEmail, exceptUserId: user.id)) {
      return 'This email is already registered.';
    }
    final updated = user.copyWith(
      name: cleanName,
      email: cleanEmail,
      pin: password,
    );
    await _database.saveUser(updated);
    state = updated;
    return null;
  }

  Future<void> logout() async {
    await _database.logout();
    state = null;
  }

  bool _validEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}

class UsersController extends StateNotifier<List<AppUser>> {
  UsersController(this._database, this._currentUser, this._shopId)
    : super(
        _database.getUsers(shopId: _shopId)
          ..sort((a, b) => a.name.compareTo(b.name)),
      );

  final LocalDatabase _database;
  final AppUser? _currentUser;
  final String? _shopId;

  Future<void> save(AppUser user) async {
    if (_currentUser?.role != UserRole.admin) return;
    await _database.saveUser(user);
    state = _database.getUsers(shopId: _shopId)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> delete(String id) async {
    final currentUser = _currentUser;
    if (currentUser == null ||
        currentUser.role != UserRole.admin ||
        id == currentUser.id) {
      return;
    }
    await _database.deleteUser(id);
    state = _database.getUsers(shopId: _shopId)
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}

class ProductsController extends StateNotifier<List<Product>> {
  ProductsController(this._database, this.shopId, this._user)
    : super(shopId == null ? [] : _database.getProducts(shopId));

  final LocalDatabase _database;
  final String? shopId;
  final AppUser? _user;

  Future<void> save(Product product) async {
    if (_user == null || !_user.canManageProducts) return;
    final status = _user.role == UserRole.admin
        ? ApprovalStatus.approved
        : ApprovalStatus.pending;
    await _database.saveProduct(
      product.copyWith(approvalStatus: status, requestedBy: _user.id),
    );
    state = _database.getProducts(product.shopId);
  }

  Future<void> setApproval(Product product, ApprovalStatus status) async {
    if (_user?.role != UserRole.admin) return;
    await _database.saveProduct(product.copyWith(approvalStatus: status));
    if (shopId != null) state = _database.getProducts(shopId!);
  }

  Future<void> delete(String id) async {
    if (_user == null || !_user.canDeleteRecords) return;
    await _database.deleteProduct(id);
    if (shopId != null) state = _database.getProducts(shopId!);
  }

  Future<void> purchaseStock(
    Product product,
    double quantity, {
    String? dealerId,
  }) async {
    if (_user == null || !_user.canManageProducts) return;
    await _database.purchaseStock(
      product: product,
      quantity: quantity,
      supplierId: dealerId,
    );
    state = _database.getProducts(product.shopId);
  }
}

class BillsController extends StateNotifier<List<Bill>> {
  BillsController(this._database, this.shopId)
    : super(shopId == null ? [] : _database.getBills(shopId));

  final LocalDatabase _database;
  final String? shopId;

  Future<void> save(Bill bill) async {
    await _database.saveBill(bill);
    state = _database.getBills(bill.shopId);
  }
}

class CustomersController extends StateNotifier<List<Customer>> {
  CustomersController(this._database, this.shopId, this._user)
    : super(shopId == null ? [] : _database.getCustomers(shopId));

  final LocalDatabase _database;
  final String? shopId;
  final AppUser? _user;

  Future<void> save(Customer customer) async {
    if (_user == null || !_user.canManageProducts) return;
    final status = _user.role == UserRole.admin
        ? ApprovalStatus.approved
        : ApprovalStatus.pending;
    await _database.saveCustomer(
      customer.copyWith(approvalStatus: status, requestedBy: _user.id),
    );
    state = _database.getCustomers(customer.shopId);
  }

  Future<void> setApproval(Customer customer, ApprovalStatus status) async {
    if (_user?.role != UserRole.admin) return;
    await _database.saveCustomer(customer.copyWith(approvalStatus: status));
    if (shopId != null) state = _database.getCustomers(shopId!);
  }

  Future<void> delete(String id) async {
    if (_user == null || !_user.canDeleteRecords) return;
    await _database.deleteCustomer(id);
    if (shopId != null) state = _database.getCustomers(shopId!);
  }
}

class SuppliersController extends StateNotifier<List<Supplier>> {
  SuppliersController(this._database, this.shopId, this._user)
    : super(shopId == null ? [] : _database.getSuppliers(shopId));

  final LocalDatabase _database;
  final String? shopId;
  final AppUser? _user;

  Future<void> save(Supplier supplier) async {
    if (_user == null || !_user.canManageProducts) return;
    final status = _user.role == UserRole.admin
        ? ApprovalStatus.approved
        : ApprovalStatus.pending;
    await _database.saveSupplier(
      supplier.copyWith(approvalStatus: status, requestedBy: _user.id),
    );
    state = _database.getSuppliers(supplier.shopId);
  }

  Future<void> setApproval(Supplier supplier, ApprovalStatus status) async {
    if (_user?.role != UserRole.admin) return;
    await _database.saveSupplier(supplier.copyWith(approvalStatus: status));
    if (shopId != null) state = _database.getSuppliers(shopId!);
  }
}

class StockMovementsController extends StateNotifier<List<StockMovement>> {
  StockMovementsController(LocalDatabase database, this.shopId)
    : super(shopId == null ? [] : database.getStockMovements(shopId));

  final String? shopId;
}

class CartController extends StateNotifier<CartState> {
  CartController(this._ref) : super(const CartState());

  final Ref _ref;

  void add(Product product) {
    final index = state.items.indexWhere(
      (item) => item.product.id == product.id,
    );
    final items = [...state.items];
    if (index == -1) {
      items.add(CartItem(product: product, quantity: 1));
    } else {
      final item = items[index];
      items[index] = item.copyWith(
        quantity: min(item.quantity + 1, product.stockQuantity),
      );
    }
    state = state.copyWith(items: items);
  }

  void addWithQuantity(Product product, double quantity) {
    final index = state.items.indexWhere(
      (item) => item.product.id == product.id,
    );
    final items = [...state.items];
    if (index == -1) {
      items.add(
        CartItem(
          product: product,
          quantity: min(quantity, product.stockQuantity),
        ),
      );
    } else {
      final item = items[index];
      items[index] = item.copyWith(
        quantity: min(item.quantity + quantity, product.stockQuantity),
      );
    }
    state = state.copyWith(items: items);
  }

  void scan(String sku) {
    final product = _ref
        .read(productsProvider)
        .where((product) => product.sku.toLowerCase() == sku.toLowerCase())
        .firstOrNull;
    if (product != null) add(product);
  }

  void updateQuantity(String productId, double quantity) {
    final items = state.items
        .map(
          (item) => item.product.id == productId
              ? item.copyWith(
                  quantity: quantity
                      .clamp(0, item.product.stockQuantity)
                      .toDouble(),
                )
              : item,
        )
        .where((item) => item.quantity > 0)
        .toList();
    state = state.copyWith(items: items);
  }

  void setTotalDiscount(double value) =>
      state = state.copyWith(totalDiscount: value);

  void setPaymentMethod(PaymentMethod method) =>
      state = state.copyWith(paymentMethod: method);

  void setCustomer(String? customerId) =>
      state = state.copyWith(customerId: customerId);

  void setSeller(String? sellerId) =>
      state = state.copyWith(sellerId: sellerId);

  void setPaidAmount(double value) => state = state.copyWith(paidAmount: value);

  void clear() => state = const CartState();

  Future<Bill?> checkout({BillStatus status = BillStatus.paid}) async {
    final shop = _ref.read(selectedShopProvider);
    final user = _ref.read(authProvider);
    if (shop == null ||
        state.items.isEmpty ||
        user == null ||
        !user.canSellProducts) {
      return null;
    }
    final defaultSellerId = user.role == UserRole.admin
        ? _ref
              .read(usersProvider)
              .where((employee) => employee.role != UserRole.admin)
              .firstOrNull
              ?.id
        : user.id;
    final bill = Bill(
      id: newId('bill'),
      shopId: shop.id,
      invoiceNumber: 'INV-${DateTime.now().millisecondsSinceEpoch}',
      items: state.items,
      createdAt: DateTime.now(),
      status: status,
      paymentMethod: state.paymentMethod,
      sellerId: state.sellerId ?? defaultSellerId ?? user.id,
      customerId: state.customerId,
      totalDiscount: state.totalDiscount,
      paidAmount: status == BillStatus.paid
          ? (state.paymentMethod == PaymentMethod.credit
                ? state.paidAmount.clamp(0, state.grandTotal).toDouble()
                : state.grandTotal)
          : 0,
    );
    await _ref.read(billsProvider.notifier).save(bill);
    _ref.invalidate(productsProvider);
    _ref.invalidate(stockMovementsProvider);
    state = const CartState();
    return bill;
  }
}

class CartState {
  const CartState({
    this.items = const [],
    this.totalDiscount = 0,
    this.paymentMethod = PaymentMethod.cash,
    this.customerId,
    this.sellerId,
    this.paidAmount = 0,
  });

  final List<CartItem> items;
  final double totalDiscount;
  final PaymentMethod paymentMethod;
  final String? customerId;
  final String? sellerId;
  final double paidAmount;

  double get subTotal => items.fold(0.0, (sum, item) => sum + item.gross);
  double get itemDiscount =>
      items.fold(0.0, (sum, item) => sum + item.discount);
  double get tax => items.fold(0.0, (sum, item) => sum + item.tax);
  double get grandTotal => subTotal - itemDiscount - totalDiscount + tax;

  CartState copyWith({
    List<CartItem>? items,
    double? totalDiscount,
    PaymentMethod? paymentMethod,
    String? customerId,
    String? sellerId,
    double? paidAmount,
  }) {
    return CartState(
      items: items ?? this.items,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerId: customerId ?? this.customerId,
      sellerId: sellerId ?? this.sellerId,
      paidAmount: paidAmount ?? this.paidAmount,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.todaySales,
    required this.weekSales,
    required this.monthSales,
    required this.yearSales,
    required this.profit,
    required this.lowStock,
    required this.expiringSoon,
    required this.billsCount,
    required this.inventoryValue,
  });

  final double todaySales;
  final double weekSales;
  final double monthSales;
  final double yearSales;
  final double profit;
  final int lowStock;
  final int expiringSoon;
  final int billsCount;
  final double inventoryValue;
}
