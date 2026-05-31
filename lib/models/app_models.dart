enum UserRole { admin, editor, seller, editorSeller, manager, marketingManager }

extension UserRoleLabel on UserRole {
  String get label {
    return switch (this) {
      UserRole.admin => 'Admin',
      UserRole.editor => 'Editor',
      UserRole.seller => 'Seller',
      UserRole.editorSeller => 'Editor + Seller',
      UserRole.manager => 'Manager',
      UserRole.marketingManager => 'Marketing Manager',
    };
  }
}

enum PaymentMethod { cash, card, mixed, credit }

enum BillStatus { draft, held, paid, cancelled }

enum StockMovementType { purchase, sale, adjustment, returnItem }

enum ApprovalStatus { approved, pending, declined }

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.createdAt,
    this.ownerAdminId,
    this.address = '',
    this.phone = '',
    this.themeSeed = 0xff0f766e,
  });

  final String id;
  final String name;
  final String type;
  final String currency;
  final String? ownerAdminId;
  final String address;
  final String phone;
  final int themeSeed;
  final DateTime createdAt;

  Shop copyWith({
    String? id,
    String? name,
    String? type,
    String? currency,
    String? ownerAdminId,
    String? address,
    String? phone,
    int? themeSeed,
    DateTime? createdAt,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      currency: currency ?? this.currency,
      ownerAdminId: ownerAdminId ?? this.ownerAdminId,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      themeSeed: themeSeed ?? this.themeSeed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'type': type,
    'currency': currency,
    'ownerAdminId': ownerAdminId,
    'address': address,
    'phone': phone,
    'themeSeed': themeSeed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Shop.fromMap(Map<dynamic, dynamic> map) => Shop(
    id: map['id'] as String,
    name: map['name'] as String,
    type: map['type'] as String,
    currency: map['currency'] as String? ?? 'PKR',
    ownerAdminId: map['ownerAdminId'] as String?,
    address: map['address'] as String? ?? '',
    phone: map['phone'] as String? ?? '',
    themeSeed: map['themeSeed'] as int? ?? 0xff0f766e,
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}

class EmployeeLeave {
  const EmployeeLeave({
    required this.startDate,
    required this.endDate,
    this.rejoinDate,
  });

  final DateTime startDate;
  final DateTime endDate;
  final DateTime? rejoinDate;

  bool get isActive => rejoinDate == null;

  Map<String, dynamic> toMap() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'rejoinDate': rejoinDate?.toIso8601String(),
  };

  factory EmployeeLeave.fromMap(Map<dynamic, dynamic> map) => EmployeeLeave(
    startDate: DateTime.parse(map['startDate'] as String),
    endDate: DateTime.parse(map['endDate'] as String),
    rejoinDate: map['rejoinDate'] == null
        ? null
        : DateTime.parse(map['rejoinDate'] as String),
  );

  EmployeeLeave copyWith({
    DateTime? startDate,
    DateTime? endDate,
    DateTime? rejoinDate,
  }) {
    return EmployeeLeave(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rejoinDate: rejoinDate ?? this.rejoinDate,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.email = '',
    this.shopId,
    this.managerId,
    this.biometricEnabled = false,
    this.monthlySalary = 0,
    this.commissionPercent = 0,
    this.phone = '',
    this.idCardNumber = '',
    this.address = '',
    this.photoPath = '',
    this.startDate,
    this.dutyStartTime = '',
    this.dutyEndTime = '',
    this.lastLoginAt,
    this.lastLogoutAt,
    this.lastSeenAt,
    this.isLoggedIn = false,
    this.leaves = const [],
  });

  final String id;
  final String name;
  final String pin;
  final UserRole role;
  final String email;
  final String? shopId;
  final String? managerId;
  final bool biometricEnabled;
  final double monthlySalary;
  final double commissionPercent;
  final String phone;
  final String idCardNumber;
  final String address;
  final String photoPath;
  final DateTime? startDate;
  final String dutyStartTime;
  final String dutyEndTime;
  final DateTime? lastLoginAt;
  final DateTime? lastLogoutAt;
  final DateTime? lastSeenAt;
  final bool isLoggedIn;
  final List<EmployeeLeave> leaves;

  bool get canManageSettings => role == UserRole.admin;
  bool get canDeleteRecords => role == UserRole.admin;
  bool get canManageProducts =>
      role == UserRole.admin ||
      role == UserRole.editor ||
      role == UserRole.editorSeller ||
      role == UserRole.manager ||
      role == UserRole.marketingManager;
  bool get canSellProducts =>
      role == UserRole.admin ||
      role == UserRole.seller ||
      role == UserRole.editorSeller ||
      role == UserRole.manager ||
      role == UserRole.marketingManager;

  String get roleLabel {
    return role.label;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'pin': pin,
    'role': role.name,
    'email': email,
    'shopId': shopId,
    'managerId': managerId,
    'biometricEnabled': biometricEnabled,
    'monthlySalary': monthlySalary,
    'commissionPercent': commissionPercent,
    'phone': phone,
    'idCardNumber': idCardNumber,
    'address': address,
    'photoPath': photoPath,
    'startDate': startDate?.toIso8601String(),
    'dutyStartTime': dutyStartTime,
    'dutyEndTime': dutyEndTime,
    'lastLoginAt': lastLoginAt?.toIso8601String(),
    'lastLogoutAt': lastLogoutAt?.toIso8601String(),
    'lastSeenAt': lastSeenAt?.toIso8601String(),
    'isLoggedIn': isLoggedIn,
    'leaves': leaves.map((leave) => leave.toMap()).toList(),
  };

  factory AppUser.fromMap(Map<dynamic, dynamic> map) => AppUser(
    id: map['id'] as String,
    name: map['name'] as String,
    pin: map['pin'] as String,
    role: _roleFromName(map['role'] as String? ?? 'admin'),
    email: map['email'] as String? ?? '',
    shopId: map['shopId'] as String?,
    managerId: map['managerId'] as String?,
    biometricEnabled: map['biometricEnabled'] as bool? ?? false,
    monthlySalary: (map['monthlySalary'] as num?)?.toDouble() ?? 0,
    commissionPercent: (map['commissionPercent'] as num?)?.toDouble() ?? 0,
    phone: map['phone'] as String? ?? '',
    idCardNumber: map['idCardNumber'] as String? ?? '',
    address: map['address'] as String? ?? '',
    photoPath: map['photoPath'] as String? ?? '',
    startDate: map['startDate'] == null
        ? null
        : DateTime.parse(map['startDate'] as String),
    dutyStartTime: map['dutyStartTime'] as String? ?? '',
    dutyEndTime: map['dutyEndTime'] as String? ?? '',
    lastLoginAt: map['lastLoginAt'] == null
        ? null
        : DateTime.parse(map['lastLoginAt'] as String),
    lastLogoutAt: map['lastLogoutAt'] == null
        ? null
        : DateTime.parse(map['lastLogoutAt'] as String),
    lastSeenAt: map['lastSeenAt'] == null
        ? null
        : DateTime.parse(map['lastSeenAt'] as String),
    isLoggedIn: map['isLoggedIn'] as bool? ?? false,
    leaves: (map['leaves'] as List<dynamic>? ?? const [])
        .map((leave) => EmployeeLeave.fromMap(leave as Map<dynamic, dynamic>))
        .toList(),
  );

  AppUser copyWith({
    String? id,
    String? name,
    String? pin,
    UserRole? role,
    String? email,
    String? shopId,
    String? managerId,
    bool? biometricEnabled,
    double? monthlySalary,
    double? commissionPercent,
    String? phone,
    String? idCardNumber,
    String? address,
    String? photoPath,
    DateTime? startDate,
    String? dutyStartTime,
    String? dutyEndTime,
    DateTime? lastLoginAt,
    DateTime? lastLogoutAt,
    DateTime? lastSeenAt,
    bool? isLoggedIn,
    List<EmployeeLeave>? leaves,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      email: email ?? this.email,
      shopId: shopId ?? this.shopId,
      managerId: managerId ?? this.managerId,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      monthlySalary: monthlySalary ?? this.monthlySalary,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      phone: phone ?? this.phone,
      idCardNumber: idCardNumber ?? this.idCardNumber,
      address: address ?? this.address,
      photoPath: photoPath ?? this.photoPath,
      startDate: startDate ?? this.startDate,
      dutyStartTime: dutyStartTime ?? this.dutyStartTime,
      dutyEndTime: dutyEndTime ?? this.dutyEndTime,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastLogoutAt: lastLogoutAt ?? this.lastLogoutAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      leaves: leaves ?? this.leaves,
    );
  }

  static UserRole _roleFromName(String name) {
    if (name == 'employee') return UserRole.seller;
    if (name == 'editor_seller') return UserRole.editorSeller;
    if (name == 'both') return UserRole.editorSeller;
    if (name == 'marketing_manager') return UserRole.marketingManager;
    return UserRole.values.byName(name);
  }
}

class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.name,
    required this.sku,
    required this.category,
    required this.buyingPrice,
    required this.sellingPrice,
    required this.stockQuantity,
    required this.unit,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.dealerId,
    this.expiryDate,
    this.imagePath,
    this.lowStockThreshold = 5,
    this.approvalStatus = ApprovalStatus.approved,
    this.requestedBy,
  });

  final String id;
  final String shopId;
  final String name;
  final String sku;
  final String category;
  final double buyingPrice;
  final double sellingPrice;
  final double stockQuantity;
  final String unit;
  final double discountPercent;
  final double taxPercent;
  final String? dealerId;
  final DateTime? expiryDate;
  final String? imagePath;
  final double lowStockThreshold;
  final ApprovalStatus approvalStatus;
  final String? requestedBy;

  bool get isLowStock => stockQuantity <= lowStockThreshold;
  bool get isExpiringSoon {
    if (expiryDate == null || stockQuantity <= 0) return false;
    final daysLeft = expiryDate!.difference(DateTime.now()).inDays;
    return daysLeft >= 0 && daysLeft <= 60;
  }

  Product copyWith({
    String? id,
    String? shopId,
    String? name,
    String? sku,
    String? category,
    double? buyingPrice,
    double? sellingPrice,
    double? stockQuantity,
    String? unit,
    double? discountPercent,
    double? taxPercent,
    String? dealerId,
    DateTime? expiryDate,
    String? imagePath,
    double? lowStockThreshold,
    ApprovalStatus? approvalStatus,
    String? requestedBy,
  }) {
    return Product(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      buyingPrice: buyingPrice ?? this.buyingPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      unit: unit ?? this.unit,
      discountPercent: discountPercent ?? this.discountPercent,
      taxPercent: taxPercent ?? this.taxPercent,
      dealerId: dealerId ?? this.dealerId,
      expiryDate: expiryDate ?? this.expiryDate,
      imagePath: imagePath ?? this.imagePath,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      requestedBy: requestedBy ?? this.requestedBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'name': name,
    'sku': sku,
    'category': category,
    'buyingPrice': buyingPrice,
    'sellingPrice': sellingPrice,
    'stockQuantity': stockQuantity,
    'unit': unit,
    'discountPercent': discountPercent,
    'taxPercent': taxPercent,
    'dealerId': dealerId,
    'expiryDate': expiryDate?.toIso8601String(),
    'imagePath': imagePath,
    'lowStockThreshold': lowStockThreshold,
    'approvalStatus': approvalStatus.name,
    'requestedBy': requestedBy,
  };

  factory Product.fromMap(Map<dynamic, dynamic> map) => Product(
    id: map['id'] as String,
    shopId: map['shopId'] as String,
    name: map['name'] as String,
    sku: map['sku'] as String,
    category: map['category'] as String,
    buyingPrice: (map['buyingPrice'] as num).toDouble(),
    sellingPrice: (map['sellingPrice'] as num).toDouble(),
    stockQuantity: (map['stockQuantity'] as num).toDouble(),
    unit: map['unit'] as String,
    discountPercent: (map['discountPercent'] as num?)?.toDouble() ?? 0,
    taxPercent: (map['taxPercent'] as num?)?.toDouble() ?? 0,
    dealerId: map['dealerId'] as String?,
    expiryDate: map['expiryDate'] == null
        ? null
        : DateTime.parse(map['expiryDate'] as String),
    imagePath: map['imagePath'] as String?,
    lowStockThreshold: (map['lowStockThreshold'] as num?)?.toDouble() ?? 5,
    approvalStatus: _approvalFromName(map['approvalStatus'] as String?),
    requestedBy: map['requestedBy'] as String?,
  );
}

ApprovalStatus _approvalFromName(String? name) {
  if (name == null) return ApprovalStatus.approved;
  return ApprovalStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => ApprovalStatus.approved,
  );
}

class CartItem {
  const CartItem({
    required this.product,
    required this.quantity,
    this.discountPercent,
  });

  final Product product;
  final double quantity;
  final double? discountPercent;

  double get effectiveDiscount => discountPercent ?? product.discountPercent;
  double get gross => product.sellingPrice * quantity;
  double get discount => gross * effectiveDiscount / 100;
  double get taxableAmount => gross - discount;
  double get tax => taxableAmount * product.taxPercent / 100;
  double get total => taxableAmount + tax;
  double get profit =>
      (product.sellingPrice - product.buyingPrice) * quantity - discount;

  CartItem copyWith({
    Product? product,
    double? quantity,
    double? discountPercent,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }

  Map<String, dynamic> toMap() => {
    'product': product.toMap(),
    'quantity': quantity,
    'discountPercent': discountPercent,
  };

  factory CartItem.fromMap(Map<dynamic, dynamic> map) => CartItem(
    product: Product.fromMap(map['product'] as Map<dynamic, dynamic>),
    quantity: (map['quantity'] as num).toDouble(),
    discountPercent: (map['discountPercent'] as num?)?.toDouble(),
  );
}

class Bill {
  const Bill({
    required this.id,
    required this.shopId,
    required this.invoiceNumber,
    required this.items,
    required this.createdAt,
    required this.status,
    required this.paymentMethod,
    this.sellerId,
    this.customerId,
    this.totalDiscount = 0,
    this.paidAmount = 0,
    this.note = '',
  });

  final String id;
  final String shopId;
  final String invoiceNumber;
  final List<CartItem> items;
  final DateTime createdAt;
  final BillStatus status;
  final PaymentMethod paymentMethod;
  final String? sellerId;
  final String? customerId;
  final double totalDiscount;
  final double paidAmount;
  final String note;

  double get subTotal => items.fold(0.0, (sum, item) => sum + item.gross);
  double get itemDiscount =>
      items.fold(0.0, (sum, item) => sum + item.discount);
  double get tax => items.fold(0.0, (sum, item) => sum + item.tax);
  double get grandTotal => subTotal - itemDiscount - totalDiscount + tax;
  double get profit =>
      items.fold(0.0, (sum, item) => sum + item.profit) - totalDiscount;
  double get dueAmount => grandTotal - paidAmount;

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'invoiceNumber': invoiceNumber,
    'items': items.map((item) => item.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'paymentMethod': paymentMethod.name,
    'sellerId': sellerId,
    'customerId': customerId,
    'totalDiscount': totalDiscount,
    'paidAmount': paidAmount,
    'note': note,
  };

  factory Bill.fromMap(Map<dynamic, dynamic> map) => Bill(
    id: map['id'] as String,
    shopId: map['shopId'] as String,
    invoiceNumber: map['invoiceNumber'] as String,
    items: (map['items'] as List<dynamic>)
        .map((item) => CartItem.fromMap(item as Map<dynamic, dynamic>))
        .toList(),
    createdAt: DateTime.parse(map['createdAt'] as String),
    status: BillStatus.values.byName(map['status'] as String? ?? 'paid'),
    paymentMethod: PaymentMethod.values.byName(
      map['paymentMethod'] as String? ?? 'cash',
    ),
    sellerId: map['sellerId'] as String?,
    customerId: map['customerId'] as String?,
    totalDiscount: (map['totalDiscount'] as num?)?.toDouble() ?? 0,
    paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0,
    note: map['note'] as String? ?? '',
  );
}

class Customer {
  const Customer({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone = '',
    this.address = '',
    this.creditDue = 0,
    this.loyaltyPoints = 0,
    this.approvalStatus = ApprovalStatus.approved,
    this.requestedBy,
  });

  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String address;
  final double creditDue;
  final int loyaltyPoints;
  final ApprovalStatus approvalStatus;
  final String? requestedBy;

  Customer copyWith({ApprovalStatus? approvalStatus, String? requestedBy}) {
    return Customer(
      id: id,
      shopId: shopId,
      name: name,
      phone: phone,
      address: address,
      creditDue: creditDue,
      loyaltyPoints: loyaltyPoints,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      requestedBy: requestedBy ?? this.requestedBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'name': name,
    'phone': phone,
    'address': address,
    'creditDue': creditDue,
    'loyaltyPoints': loyaltyPoints,
    'approvalStatus': approvalStatus.name,
    'requestedBy': requestedBy,
  };

  factory Customer.fromMap(Map<dynamic, dynamic> map) => Customer(
    id: map['id'] as String,
    shopId: map['shopId'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String? ?? '',
    address: map['address'] as String? ?? '',
    creditDue: (map['creditDue'] as num?)?.toDouble() ?? 0,
    loyaltyPoints: map['loyaltyPoints'] as int? ?? 0,
    approvalStatus: _approvalFromName(map['approvalStatus'] as String?),
    requestedBy: map['requestedBy'] as String?,
  );
}

class Supplier {
  const Supplier({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone = '',
    this.company = '',
    this.due = 0,
    this.approvalStatus = ApprovalStatus.approved,
    this.requestedBy,
  });

  final String id;
  final String shopId;
  final String name;
  final String phone;
  final String company;
  final double due;
  final ApprovalStatus approvalStatus;
  final String? requestedBy;

  Supplier copyWith({ApprovalStatus? approvalStatus, String? requestedBy}) {
    return Supplier(
      id: id,
      shopId: shopId,
      name: name,
      phone: phone,
      company: company,
      due: due,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      requestedBy: requestedBy ?? this.requestedBy,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'name': name,
    'phone': phone,
    'company': company,
    'due': due,
    'approvalStatus': approvalStatus.name,
    'requestedBy': requestedBy,
  };

  factory Supplier.fromMap(Map<dynamic, dynamic> map) => Supplier(
    id: map['id'] as String,
    shopId: map['shopId'] as String,
    name: map['name'] as String,
    phone: map['phone'] as String? ?? '',
    company: map['company'] as String? ?? '',
    due: (map['due'] as num?)?.toDouble() ?? 0,
    approvalStatus: _approvalFromName(map['approvalStatus'] as String?),
    requestedBy: map['requestedBy'] as String?,
  );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.quantity,
    required this.type,
    required this.createdAt,
    this.supplierId,
    this.note = '',
  });

  final String id;
  final String shopId;
  final String productId;
  final double quantity;
  final StockMovementType type;
  final DateTime createdAt;
  final String? supplierId;
  final String note;

  Map<String, dynamic> toMap() => {
    'id': id,
    'shopId': shopId,
    'productId': productId,
    'quantity': quantity,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'supplierId': supplierId,
    'note': note,
  };

  factory StockMovement.fromMap(Map<dynamic, dynamic> map) => StockMovement(
    id: map['id'] as String,
    shopId: map['shopId'] as String,
    productId: map['productId'] as String,
    quantity: (map['quantity'] as num).toDouble(),
    type: StockMovementType.values.byName(map['type'] as String),
    createdAt: DateTime.parse(map['createdAt'] as String),
    supplierId: map['supplierId'] as String?,
    note: map['note'] as String? ?? '',
  );
}
