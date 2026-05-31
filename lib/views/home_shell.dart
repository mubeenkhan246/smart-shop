import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../controllers/app_providers.dart';
import '../models/app_models.dart';
import '../services/backup_service.dart';
import '../services/invoice_service.dart';
import '../utils/formatters.dart';
import '../utils/password_rules.dart';
import '../widgets/app_widgets.dart';
import 'contacts_screen.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'shop_selection_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  Timer? _presenceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).markSeen();
    });
    _presenceTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      ref.read(authProvider.notifier).markSeen();
    });
  }

  @override
  void dispose() {
    _presenceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(selectedShopProvider);
    final user = ref.watch(authProvider);
    final pages = _pagesFor(user);
    if (_index >= pages.length) _index = 0;
    final wide = MediaQuery.sizeOf(context).width >= 880;
    final navigation = pages.length < 2
        ? null
        : NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1120,
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: pages
                .map(
                  (page) => NavigationRailDestination(
                    icon: page.icon,
                    selectedIcon: page.selectedIcon,
                    label: Text(page.label),
                  ),
                )
                .toList(),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: IconButton.filledTonal(
                tooltip: 'Switch shop',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShopSelectionScreen(),
                  ),
                ),
                icon: const Icon(Icons.storefront),
              ),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: IconButton(
                  tooltip: 'Logout',
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                  icon: const Icon(Icons.logout),
                ),
              ),
            ),
          );
    return Scaffold(
      appBar: AppBar(
        title: Text(shop == null ? 'Smart Shop' : shop.name),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.verified_user, size: 18),
                label: Text('${user.name} • ${user.roleLabel}'),
              ),
            ),
          IconButton(
            tooltip: 'Switch shop',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ShopSelectionScreen()),
            ),
            icon: const Icon(Icons.swap_horiz),
          ),
          if (user?.role == UserRole.admin)
            IconButton(
              tooltip: 'Currency',
              onPressed: shop == null ? null : () => _showCurrencyDialog(shop),
              icon: const Icon(Icons.currency_exchange),
            ),
          if (user?.role == UserRole.admin)
            IconButton(
              tooltip: 'Approvals',
              onPressed: shop == null ? null : () => _showApprovalsSheet(shop),
              icon: const Icon(Icons.fact_check_outlined),
            ),
          if (user?.role == UserRole.admin)
            PopupMenuButton<String>(
              tooltip: 'Backup',
              icon: const Icon(Icons.backup_outlined),
              onSelected: (value) {
                if (value == 'save_export') _saveBackupLocally();
                if (value == 'share_export') _shareBackup();
                if (value == 'import') _showImportBackupDialog();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'save_export',
                  child: ListTile(
                    leading: Icon(Icons.download),
                    title: Text('Save backup locally'),
                  ),
                ),
                PopupMenuItem(
                  value: 'share_export',
                  child: ListTile(
                    leading: Icon(Icons.ios_share),
                    title: Text('Share backup'),
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.restore_page),
                    title: Text('Import history'),
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: wide && navigation != null
          ? Row(
              children: [
                navigation,
                const VerticalDivider(width: 1),
                Expanded(child: pages[_index].screen),
              ],
            )
          : pages[_index].screen,
      bottomNavigationBar: wide || pages.length < 2
          ? null
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                destinations: pages.map((page) {
                  return NavigationDestination(
                    icon: page.icon,
                    selectedIcon: page.selectedIcon,
                    label: page.label,
                  );
                }).toList(),
              ),
            ),
    );
  }

  List<_AppPage> _pagesFor(AppUser? user) {
    if (user?.role == UserRole.seller) {
      return const [
        _AppPage(
          label: 'POS',
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          screen: PosScreen(),
        ),
      ];
    }
    if (user?.role == UserRole.editor) {
      return const [
        _AppPage(
          label: 'Products',
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          screen: ProductsScreen(),
        ),
        _AppPage(
          label: 'Suppliers',
          icon: Icon(Icons.store_mall_directory_outlined),
          selectedIcon: Icon(Icons.store_mall_directory),
          screen: ContactsScreen(suppliers: false),
        ),
      ];
    }
    if (user?.role == UserRole.editorSeller ||
        user?.role == UserRole.manager ||
        user?.role == UserRole.marketingManager) {
      return const [
        _AppPage(
          label: 'POS',
          icon: Icon(Icons.point_of_sale_outlined),
          selectedIcon: Icon(Icons.point_of_sale),
          screen: PosScreen(),
        ),
        _AppPage(
          label: 'Products',
          icon: Icon(Icons.inventory_2_outlined),
          selectedIcon: Icon(Icons.inventory_2),
          screen: ProductsScreen(),
        ),
        _AppPage(
          label: 'Suppliers',
          icon: Icon(Icons.store_mall_directory_outlined),
          selectedIcon: Icon(Icons.store_mall_directory),
          screen: ContactsScreen(suppliers: false),
        ),
      ];
    }
    return const [
      _AppPage(
        label: 'Dashboard',
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        screen: DashboardScreen(),
      ),
      _AppPage(
        label: 'POS',
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        screen: PosScreen(),
      ),
      _AppPage(
        label: 'Products',
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        screen: ProductsScreen(),
      ),
      _AppPage(
        label: 'Suppliers',
        icon: Icon(Icons.store_mall_directory_outlined),
        selectedIcon: Icon(Icons.store_mall_directory),
        screen: ContactsScreen(suppliers: false),
      ),
      _AppPage(
        label: 'Employees',
        icon: Icon(Icons.badge_outlined),
        selectedIcon: Icon(Icons.badge),
        screen: EmployeesScreen(),
      ),
      _AppPage(
        label: 'Reports',
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics),
        screen: ReportsScreen(),
      ),
    ];
  }

  Future<void> _showCurrencyDialog(Shop shop) async {
    var currency = shop.currency;
    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final normalized = query.trim().toLowerCase();
          final items = supportedCurrencyOptions.where((option) {
            if (normalized.isEmpty) return true;
            return option.code.toLowerCase().contains(normalized) ||
                option.name.toLowerCase().contains(normalized) ||
                option.symbol.toLowerCase().contains(normalized);
          }).toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: .86,
            minChildSize: .45,
            maxChildSize: .96,
            builder: (context, controller) => Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.viewInsetsOf(context).bottom + 16,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Select currency',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Search currency',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setSheetState(() => query = value),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: controller,
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = items[index];
                        final selected = option.code == currency;
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              option.symbol.trim().isEmpty
                                  ? option.code.substring(0, 1)
                                  : option.symbol.trim(),
                            ),
                          ),
                          title: Text(option.label),
                          subtitle: Text(option.symbol.trim()),
                          trailing: selected
                              ? Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () async {
                            currency = option.code;
                            final updated = shop.copyWith(currency: currency);
                            await ref
                                .read(shopsProvider.notifier)
                                .addShop(updated);
                            await ref
                                .read(selectedShopProvider.notifier)
                                .select(updated);
                            moneyFormat.setCurrency(currency);
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showApprovalsSheet(Shop shop) async {
    final database = ref.read(databaseProvider);
    final products = database
        .getProducts(shop.id, includePending: true)
        .where((product) => product.approvalStatus == ApprovalStatus.pending)
        .toList();
    final suppliers = database
        .getCustomers(shop.id, includePending: true)
        .where((supplier) => supplier.approvalStatus == ApprovalStatus.pending)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .42,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Pending approvals',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (products.isEmpty && suppliers.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No pending products or suppliers.'),
                ),
              ),
            if (products.isNotEmpty) ...[
              Text('Products', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final product in products)
                _approvalTile(
                  title: product.name,
                  subtitle:
                      '${product.sku} • ${product.category} • ${moneyFormat.format(product.sellingPrice)}',
                  onApprove: () async {
                    await ref
                        .read(productsProvider.notifier)
                        .setApproval(product, ApprovalStatus.approved);
                    if (context.mounted) Navigator.pop(context);
                  },
                  onDecline: () async {
                    await ref
                        .read(productsProvider.notifier)
                        .setApproval(product, ApprovalStatus.declined);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 12),
            ],
            if (suppliers.isNotEmpty) ...[
              Text('Suppliers', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final supplier in suppliers)
                _approvalTile(
                  title: supplier.name,
                  subtitle: supplier.phone.isEmpty
                      ? 'No phone'
                      : supplier.phone,
                  onApprove: () async {
                    await ref
                        .read(customersProvider.notifier)
                        .setApproval(supplier, ApprovalStatus.approved);
                    if (context.mounted) Navigator.pop(context);
                  },
                  onDecline: () async {
                    await ref
                        .read(customersProvider.notifier)
                        .setApproval(supplier, ApprovalStatus.declined);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _approvalTile({
    required String title,
    required String subtitle,
    required Future<void> Function() onApprove,
    required Future<void> Function() onDecline,
  }) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Wrap(
          spacing: 4,
          children: [
            IconButton(
              tooltip: 'Approve',
              onPressed: onApprove,
              icon: const Icon(Icons.check_circle_outline),
            ),
            IconButton(
              tooltip: 'Decline',
              onPressed: onDecline,
              icon: const Icon(Icons.cancel_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBackupLocally() async {
    try {
      final location = await BackupService(
        ref.read(databaseProvider),
      ).saveBackupLocally();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup saved: $location')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $error')));
    }
  }

  Future<void> _shareBackup() async {
    try {
      final location = await BackupService(
        ref.read(databaseProvider),
      ).shareBackup();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup shared: $location')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $error')));
    }
  }

  Future<void> _showImportBackupDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import history backup'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: TextField(
              controller: controller,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                labelText: 'Paste backup JSON',
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                await BackupService(
                  ref.read(databaseProvider),
                ).importJson(controller.text.trim());
                _refreshAllData();
                if (context.mounted) Navigator.pop(context);
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('History imported.')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Import failed: $error')),
                );
              }
            },
            icon: const Icon(Icons.restore_page),
            label: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _refreshAllData() {
    ref.invalidate(shopsProvider);
    ref.invalidate(selectedShopProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(billsProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(suppliersProvider);
    ref.invalidate(stockMovementsProvider);
    ref.invalidate(dashboardProvider);
  }
}

class _AppPage {
  const _AppPage({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });

  final String label;
  final Widget icon;
  final Widget selectedIcon;
  final Widget screen;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _customDate;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardProvider);
    final bills = ref.watch(billsProvider);
    final products = ref.watch(productsProvider);
    final paidBills = bills
        .where((bill) => bill.status == BillStatus.paid)
        .toList();
    final customSales = _customDate == null
        ? null
        : _salesForDate(paidBills, _customDate!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ResponsiveGrid(
          children: [
            MetricTile(
              title: 'Today sales',
              value: moneyFormat.format(stats.todaySales),
              icon: Icons.today,
              color: Colors.teal,
            ),
            MetricTile(
              title: 'Weekly sales',
              value: moneyFormat.format(stats.weekSales),
              icon: Icons.view_week,
              color: Colors.deepPurple,
            ),
            MetricTile(
              title: 'Monthly sales',
              value: moneyFormat.format(stats.monthSales),
              icon: Icons.calendar_month,
              color: Colors.indigo,
            ),
            MetricTile(
              title: 'Yearly sales',
              value: moneyFormat.format(stats.yearSales),
              icon: Icons.event_available,
              color: Colors.blue,
            ),
            _CustomSalesTile(
              date: _customDate,
              value: customSales == null
                  ? 'Pick date'
                  : moneyFormat.format(customSales),
              onPick: _pickCustomDate,
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showProductAlerts(
                title: 'Low stock products',
                products: products.where((product) => product.isLowStock),
              ),
              child: MetricTile(
                title: 'Low stock',
                value: stats.lowStock.toString(),
                icon: Icons.warning_amber,
                color: Colors.orange,
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showProductAlerts(
                title: 'Expiring products',
                products: products.where((product) => product.isExpiringSoon),
              ),
              child: MetricTile(
                title: 'Expiring in 2 months',
                value: stats.expiringSoon.toString(),
                icon: Icons.event_busy,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: paidBills.isEmpty ? null : () => _showHistory(paidBills),
            icon: const Icon(Icons.history),
            label: const Text('Show full history'),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final recentBills = _RecentBills(bills: bills);
            final alerts = _Alerts(products: products);
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: recentBills),
                      const SizedBox(width: 12),
                      Expanded(child: alerts),
                    ],
                  )
                : Column(
                    children: [recentBills, const SizedBox(height: 12), alerts],
                  );
          },
        ),
      ],
    );
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _customDate = picked);
  }

  double _salesForDate(List<Bill> bills, DateTime date) {
    return bills
        .where(
          (bill) =>
              bill.createdAt.year == date.year &&
              bill.createdAt.month == date.month &&
              bill.createdAt.day == date.day,
        )
        .fold(0.0, (sum, bill) => sum + bill.grandTotal);
  }

  Future<void> _showHistory(List<Bill> bills) {
    var query = '';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .95,
        builder: (context, controller) => StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = bills.where((bill) {
              final haystack =
                  '${bill.invoiceNumber} ${bill.grandTotal.toStringAsFixed(0)} ${moneyFormat.format(bill.grandTotal)}'
                      .toLowerCase();
              return haystack.contains(query.toLowerCase());
            }).toList();
            return ListView.separated(
              controller: controller,
              padding: const EdgeInsets.all(16),
              itemCount: filtered.isEmpty ? 3 : filtered.length + 2,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Sales history',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  );
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SearchBar(
                      hintText: 'Search invoice ID or total bill',
                      leading: const Icon(Icons.search),
                      onChanged: (value) => setSheetState(() => query = value),
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No invoices matched your search.'),
                  );
                }
                final bill = filtered[index - 2];
                return ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(bill.invoiceNumber),
                  subtitle: Text(compactDateFormat.format(bill.createdAt)),
                  trailing: Text(moneyFormat.format(bill.grandTotal)),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _showProductAlerts({
    required String title,
    required Iterable<Product> products,
  }) {
    final items = products.toList()..sort((a, b) => a.name.compareTo(b.name));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .38,
        maxChildSize: .95,
        builder: (context, controller) => ListView.separated(
          controller: controller,
          padding: const EdgeInsets.all(16),
          itemCount: items.isEmpty ? 2 : items.length + 1,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              );
            }
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No products found.'),
              );
            }
            final product = items[index - 1];
            return ListTile(
              leading: Icon(
                product.isLowStock ? Icons.warning_amber : Icons.event_busy,
              ),
              title: Text(product.name),
              subtitle: Text(
                [
                  product.sku,
                  '${product.stockQuantity} ${product.unit} left',
                  if (product.expiryDate != null)
                    'Expiry ${dateFormat.format(product.expiryDate!)}',
                ].join(' • '),
              ),
              trailing: Text(moneyFormat.format(product.sellingPrice)),
            );
          },
        ),
      ),
    );
  }
}

class _CustomSalesTile extends StatelessWidget {
  const _CustomSalesTile({
    required this.date,
    required this.value,
    required this.onPick,
  });

  final DateTime? date;
  final String value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onPick,
      child: MetricTile(
        title: date == null ? 'Custom date sales' : dateFormat.format(date!),
        value: value,
        icon: Icons.date_range,
        color: Colors.cyan,
      ),
    );
  }
}

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key});

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  final Set<String> _visiblePasswords = {};

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    final shop = ref.watch(selectedShopProvider);
    final admins = users.where((user) => user.role == UserRole.admin).toList();
    final employees = users
        .where((user) => user.role != UserRole.admin)
        .toList();
    final currentEmployees = employees
        .where((user) => !_hasActiveLeave(user))
        .toList();
    final currentUser = ref.watch(authProvider);
    final bills = ref.watch(billsProvider);
    final leaveRecords = [
      for (final user in employees)
        for (var index = 0; index < user.leaves.length; index++)
          if (user.leaves[index].isActive)
            _EmployeeLeaveRecord(
              employee: user,
              leave: user.leaves[index],
              leaveIndex: index,
            ),
    ]..sort((a, b) => b.leave.startDate.compareTo(a.leave.startDate));
    final workingNow = currentEmployees.where(_isWorkingNow).length;
    final onlineNow = currentEmployees.where((user) => user.isLoggedIn).length;
    final offlineNow = currentEmployees.length - onlineNow;
    return Scaffold(
      appBar: AppBar(title: const Text('Employees')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shop == null
            ? null
            : () => _showEmployeeForm(context, ref, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Add employee'),
      ),
      body: users.isEmpty
          ? const Center(child: Text('No employees found.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader('Admin Parent', admins.length),
                if (admins.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No admin account found.'),
                    ),
                  )
                else
                  for (final admin in admins) _adminCard(context, admin),
                const SizedBox(height: 16),
                _presenceSummary(workingNow, onlineNow, offlineNow),
                const SizedBox(height: 16),
                _sectionHeader('Current Employees', currentEmployees.length),
                if (currentEmployees.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No current employees.'),
                    ),
                  )
                else
                  for (final user in currentEmployees)
                    _employeeCard(
                      context,
                      ref,
                      bills,
                      currentUser,
                      user,
                      shop?.name,
                      employees,
                    ),
                const SizedBox(height: 16),
                _sectionHeader('Employee Leave', leaveRecords.length),
                if (leaveRecords.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No employee leave records.'),
                    ),
                  )
                else
                  for (final record in leaveRecords)
                    _leaveCard(context, ref, bills, record),
              ],
            ),
    );
  }

  Widget _adminCard(BuildContext context, AppUser admin) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: _employeeAvatar(admin, true),
          title: Text(admin.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(['Parent account', 'Role: ${admin.roleLabel}'].join(' • ')),
              if (admin.email.isNotEmpty) Text('Email: ${admin.email}'),
              _passwordLine(admin),
            ],
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: 'Edit admin',
                onPressed: () => _showAdminForm(context, ref, admin),
                icon: const Icon(Icons.edit_outlined),
              ),
              const Icon(Icons.admin_panel_settings),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAdminForm(
    BuildContext context,
    WidgetRef ref,
    AppUser admin,
  ) async {
    final name = TextEditingController(text: admin.name);
    final email = TextEditingController(text: admin.email);
    final password = TextEditingController(text: admin.pin);
    var obscure = true;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text('Edit admin', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _spacedField(
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              ),
              _spacedField(
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ),
              _spacedField(
                TextField(
                  controller: password,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText:
                        'Minimum 8 characters with alphabet, number and special character',
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Show password' : 'Hide password',
                      onPressed: () => setSheetState(() => obscure = !obscure),
                      icon: Icon(
                        obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final error = await ref
                            .read(authProvider.notifier)
                            .updateAdminProfile(
                              name: name.text,
                              email: email.text,
                              password: password.text,
                            );
                        if (!context.mounted) return;
                        if (error != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(error)));
                          return;
                        }
                        ref.invalidate(usersProvider);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Chip(label: Text(count.toString())),
        ],
      ),
    );
  }

  Widget _presenceSummary(int workingNow, int onlineNow, int offlineNow) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statusChip(
          icon: Icons.work_history,
          label: 'Working now',
          count: workingNow,
          color: Colors.green,
        ),
        _statusChip(
          icon: Icons.wifi_tethering,
          label: 'Logged in',
          count: onlineNow,
          color: Colors.blue,
        ),
        _statusChip(
          icon: Icons.power_settings_new,
          label: 'Offline',
          count: offlineNow,
          color: Colors.grey,
        ),
      ],
    );
  }

  Widget _statusChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $count'),
    );
  }

  Widget _employeeCard(
    BuildContext context,
    WidgetRef ref,
    List<Bill> bills,
    AppUser? currentUser,
    AppUser user,
    String? shopName,
    List<AppUser> employees,
  ) {
    final sales = _salesForEmployee(bills, user.id);
    final isAdmin = user.role == UserRole.admin;
    final managerName = _managerName(employees, user.managerId);
    final teamCount = _teamCount(employees, user.id);
    final status = _employeeStatus(user);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          enabled: !isAdmin,
          leading: _employeeAvatar(user, isAdmin),
          title: Text(user.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _salaryLine(context, user),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(status.icon, color: status.color, size: 18),
                    label: Text(status.label),
                  ),
                  if (_dutyText(user) != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(_dutyText(user)!),
                    ),
                ],
              ),
              Text(
                [
                  'Role: ${user.roleLabel}',
                  if (user.shopId != null) 'Shop: ${shopName ?? user.shopId}',
                  if (_isManagerRole(user.role))
                    '$teamCount employee(s) under manager',
                  if (managerName != null) 'Manager: $managerName',
                  if (user.startDate != null)
                    'Start: ${dateFormat.format(user.startDate!)}',
                  if (user.leaves.isNotEmpty) '${user.leaves.length} leave(s)',
                  if (user.phone.isNotEmpty) 'Phone: ${user.phone}',
                  if (user.idCardNumber.isNotEmpty) 'ID: ${user.idCardNumber}',
                  if (user.lastSeenAt != null)
                    'Last seen ${compactDateFormat.format(user.lastSeenAt!)}',
                  '${sales.quantityText} products sold',
                  'Earned ${moneyFormat.format(sales.sales)}',
                  'Commission ${moneyFormat.format(_commissionFor(user, sales.sales))}',
                  'Total pay ${moneyFormat.format(user.monthlySalary + _commissionFor(user, sales.sales))}',
                  'Profit ${moneyFormat.format(sales.profit)}',
                ].join(' • '),
              ),
              _passwordLine(user),
            ],
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: isAdmin ? 'Admin cannot be edited' : 'Edit employee',
                onPressed: isAdmin
                    ? null
                    : () => _showEmployeeForm(context, ref, user),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: isAdmin
                    ? 'Admin cannot be deleted'
                    : 'Delete employee',
                onPressed: isAdmin || user.id == currentUser?.id
                    ? null
                    : () => _deleteEmployee(context, ref, user),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          onTap: isAdmin
              ? null
              : () => _showEmployeeHistory(context, ref, bills, user),
        ),
      ),
    );
  }

  String? _managerName(List<AppUser> employees, String? managerId) {
    if (managerId == null || managerId.isEmpty) return null;
    for (final employee in employees) {
      if (employee.id == managerId) return employee.name;
    }
    return null;
  }

  int _teamCount(List<AppUser> employees, String managerId) {
    return employees
        .where((employee) => employee.managerId == managerId)
        .length;
  }

  bool _isManagerRole(UserRole role) {
    return role == UserRole.manager || role == UserRole.marketingManager;
  }

  Widget _passwordLine(AppUser user) {
    final isVisible = _visiblePasswords.contains(user.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Password: ${isVisible ? user.pin : '••••••••'}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: isVisible ? 'Hide password' : 'Show password',
          onPressed: () {
            setState(() {
              if (isVisible) {
                _visiblePasswords.remove(user.id);
              } else {
                _visiblePasswords.add(user.id);
              }
            });
          },
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _leaveCard(
    BuildContext context,
    WidgetRef ref,
    List<Bill> bills,
    _EmployeeLeaveRecord record,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.event_busy),
          title: Text(record.employee.name),
          subtitle: Text(
            '${dateFormat.format(record.leave.startDate)} to '
            '${dateFormat.format(record.leave.endDate)}',
          ),
          trailing: Text('${_leaveDays(record.leave)} day(s)'),
          onTap: () =>
              _showEmployeeHistory(context, ref, bills, record.employee),
        ),
      ),
    );
  }

  _EmployeeSales _salesForEmployee(List<Bill> bills, String employeeId) {
    var quantity = 0.0;
    var sales = 0.0;
    var profit = 0.0;
    for (final bill in bills.where(
      (bill) => bill.status == BillStatus.paid && bill.sellerId == employeeId,
    )) {
      sales += bill.grandTotal;
      profit += bill.profit;
      for (final item in bill.items) {
        quantity += item.quantity;
      }
    }
    return _EmployeeSales(quantity: quantity, sales: sales, profit: profit);
  }

  bool _hasActiveLeave(AppUser employee) {
    return employee.leaves.any((leave) => leave.isActive);
  }

  bool _isWorkingNow(AppUser employee) {
    if (!employee.isLoggedIn) return false;
    final start = _parseDutyTime(employee.dutyStartTime);
    final end = _parseDutyTime(employee.dutyEndTime);
    if (start == null || end == null) return true;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    if (startMinutes == endMinutes) return true;
    if (startMinutes < endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }

  _EmployeePresenceStatus _employeeStatus(AppUser employee) {
    if (!employee.isLoggedIn) {
      return const _EmployeePresenceStatus(
        label: 'Offline',
        icon: Icons.power_settings_new,
        color: Colors.grey,
      );
    }
    if (_isWorkingNow(employee)) {
      return const _EmployeePresenceStatus(
        label: 'Working now',
        icon: Icons.work_history,
        color: Colors.green,
      );
    }
    return const _EmployeePresenceStatus(
      label: 'Logged in outside duty',
      icon: Icons.schedule,
      color: Colors.orange,
    );
  }

  String? _dutyText(AppUser employee) {
    final start = employee.dutyStartTime.trim();
    final end = employee.dutyEndTime.trim();
    if (start.isEmpty && end.isEmpty) return null;
    return 'Duty ${start.isEmpty ? '--:--' : start} - ${end.isEmpty ? '--:--' : end}';
  }

  EmployeeLeave? _activeLeave(AppUser employee) {
    for (final leave in employee.leaves.reversed) {
      if (leave.isActive) return leave;
    }
    return null;
  }

  Future<void> _deleteEmployee(
    BuildContext context,
    WidgetRef ref,
    AppUser employee,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${employee.name}?'),
        content: const Text('This removes the employee login account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(usersProvider.notifier).delete(employee.id);
    }
  }

  Future<void> _showEmployeeHistory(
    BuildContext context,
    WidgetRef ref,
    List<Bill> bills,
    AppUser employee,
  ) {
    final activeLeave = _activeLeave(employee);
    final employees = ref
        .read(usersProvider)
        .where((user) => user.role != UserRole.admin)
        .toList();
    final managerName = _managerName(employees, employee.managerId);
    final teamCount = _teamCount(employees, employee.id);
    final status = _employeeStatus(employee);
    final employeeBills =
        bills
            .where(
              (bill) =>
                  bill.status == BillStatus.paid &&
                  bill.sellerId == employee.id,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        minChildSize: .38,
        maxChildSize: .95,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '${employee.name} sales history',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (employee.photoPath.isNotEmpty)
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 132,
                      height: 132,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _employeePhoto(employee),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => _shareEmployeePhoto(context, employee),
                      icon: const Icon(Icons.download),
                      label: const Text('Download photo'),
                    ),
                  ],
                ),
              ),
            if (employee.photoPath.isNotEmpty) const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _historyRow(
                      'Salary',
                      moneyFormat.format(employee.monthlySalary),
                    ),
                    _historyRow(
                      'Commission %',
                      '${employee.commissionPercent}%',
                    ),
                    _historyRow(
                      'Commission earned',
                      moneyFormat.format(
                        _commissionFor(
                          employee,
                          _salesForEmployee(bills, employee.id).sales,
                        ),
                      ),
                    ),
                    _historyRow(
                      'Salary + commission',
                      moneyFormat.format(
                        employee.monthlySalary +
                            _commissionFor(
                              employee,
                              _salesForEmployee(bills, employee.id).sales,
                            ),
                      ),
                    ),
                    _historyRow('Status', status.label),
                    if (_dutyText(employee) != null)
                      _historyRow('Duty time', _dutyText(employee)!),
                    if (employee.lastLoginAt != null)
                      _historyRow(
                        'Last login',
                        compactDateFormat.format(employee.lastLoginAt!),
                      ),
                    if (employee.lastLogoutAt != null)
                      _historyRow(
                        'Last logout',
                        compactDateFormat.format(employee.lastLogoutAt!),
                      ),
                    if (employee.lastSeenAt != null)
                      _historyRow(
                        'Last seen',
                        compactDateFormat.format(employee.lastSeenAt!),
                      ),
                    if (employee.phone.isNotEmpty)
                      _historyRow('Phone', employee.phone),
                    if (employee.shopId != null)
                      _historyRow(
                        'Shop',
                        ref.read(selectedShopProvider)?.name ??
                            employee.shopId!,
                      ),
                    if (_isManagerRole(employee.role))
                      _historyRow('Employees under manager', '$teamCount'),
                    if (managerName != null)
                      _historyRow('Manager', managerName),
                    if (employee.startDate != null)
                      _historyRow(
                        'Starting date',
                        dateFormat.format(employee.startDate!),
                      ),
                    if (employee.idCardNumber.isNotEmpty)
                      _historyRow('ID card', employee.idCardNumber),
                    if (employee.address.isNotEmpty)
                      _historyRow('Address', employee.address),
                    if (employee.photoPath.isNotEmpty)
                      _historyRow('Photo', employee.photoPath),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Joining date history',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (employee.startDate == null &&
                        !employee.leaves.any(
                          (leave) => leave.rejoinDate != null,
                        ))
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('No joining history found.'),
                      )
                    else ...[
                      if (employee.startDate != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.login),
                          title: const Text('Joined'),
                          subtitle: Text(
                            dateFormat.format(employee.startDate!),
                          ),
                        ),
                      for (final leave in employee.leaves.where(
                        (leave) => leave.rejoinDate != null,
                      ))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.login),
                          title: const Text('Rejoined'),
                          subtitle: Text(dateFormat.format(leave.rejoinDate!)),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Leave section',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: activeLeave == null
                              ? () => _markLeave(context, ref, employee)
                              : () => _rejoinEmployee(context, ref, employee),
                          icon: Icon(
                            activeLeave == null
                                ? Icons.event_busy
                                : Icons.assignment_turned_in,
                          ),
                          label: Text(
                            activeLeave == null ? 'Mark leave' : 'Rejoin',
                          ),
                        ),
                      ],
                    ),
                    if (employee.leaves.isEmpty)
                      const Text('No leaves marked.')
                    else
                      for (final leave in employee.leaves)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event_busy),
                          title: Text(
                            '${dateFormat.format(leave.startDate)} to ${dateFormat.format(leave.endDate)}',
                          ),
                          subtitle: Text(
                            [
                              '${_leaveDays(leave)} day(s)',
                              if (leave.rejoinDate == null)
                                'Active leave'
                              else
                                'Rejoined ${dateFormat.format(leave.rejoinDate!)}',
                            ].join(' • '),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (employeeBills.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No sales found for this employee yet.'),
                ),
              )
            else
              for (final bill in employeeBills)
                Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(bill.invoiceNumber),
                    subtitle: Text(
                      '${compactDateFormat.format(bill.createdAt)} • ${_quantityText(_billQuantity(bill))} products',
                    ),
                    trailing: Text(moneyFormat.format(bill.grandTotal)),
                    children: [
                      for (final item in bill.items)
                        ListTile(
                          title: Text(item.product.name),
                          subtitle: Text(
                            '${item.quantity} x ${moneyFormat.format(item.product.sellingPrice)}',
                          ),
                          trailing: Text(moneyFormat.format(item.total)),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: _historyRow(
                          'Profit',
                          moneyFormat.format(bill.profit),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  double _billQuantity(Bill bill) {
    return bill.items.fold(0.0, (sum, item) => sum + item.quantity);
  }

  String _quantityText(double quantity) {
    return quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
  }

  Widget _historyRow(String label, String value) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  double _commissionFor(AppUser user, double sales) {
    return sales * user.commissionPercent / 100;
  }

  int _leaveDays(EmployeeLeave leave) {
    return leave.endDate.difference(leave.startDate).inDays + 1;
  }

  Future<void> _rejoinEmployee(
    BuildContext context,
    WidgetRef ref,
    AppUser employee,
  ) async {
    final leaves = [...employee.leaves];
    final index = leaves.lastIndexWhere((leave) => leave.isActive);
    if (index == -1) return;
    leaves[index] = leaves[index].copyWith(rejoinDate: DateTime.now());
    await ref
        .read(usersProvider.notifier)
        .save(employee.copyWith(leaves: leaves));
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _markLeave(
    BuildContext context,
    WidgetRef ref,
    AppUser employee,
  ) async {
    final start = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (start == null || !context.mounted) return;
    final end = await showDatePicker(
      context: context,
      initialDate: start,
      firstDate: start,
      lastDate: start.add(const Duration(days: 365)),
    );
    if (end == null) return;
    final updated = employee.copyWith(
      leaves: [
        ...employee.leaves,
        EmployeeLeave(startDate: start, endDate: end),
      ],
    );
    await ref.read(usersProvider.notifier).save(updated);
  }

  Widget _salaryLine(BuildContext context, AppUser user) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium,
        children: [
          const TextSpan(text: 'Salary: '),
          TextSpan(
            text: moneyFormat.format(user.monthlySalary),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const TextSpan(text: ' + '),
          TextSpan(
            text: '${user.commissionPercent}%',
            style: TextStyle(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeAvatar(AppUser user, bool isAdmin) {
    if (user.photoPath.isNotEmpty) {
      final dataBytes = _photoDataBytes(user.photoPath);
      if (dataBytes != null) {
        return CircleAvatar(backgroundImage: MemoryImage(dataBytes));
      }
      final uri = Uri.tryParse(user.photoPath);
      if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
        return CircleAvatar(backgroundImage: NetworkImage(user.photoPath));
      }
      final file = File(user.photoPath);
      if (file.existsSync()) {
        return CircleAvatar(backgroundImage: FileImage(file));
      }
    }
    return CircleAvatar(
      child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.badge),
    );
  }

  Widget _employeePhoto(AppUser user) {
    final dataBytes = _photoDataBytes(user.photoPath);
    if (dataBytes != null) {
      return Image.memory(dataBytes, fit: BoxFit.cover);
    }
    final uri = Uri.tryParse(user.photoPath);
    if (uri != null && uri.hasScheme && uri.scheme.startsWith('http')) {
      return Image.network(user.photoPath, fit: BoxFit.cover);
    }
    final file = File(user.photoPath);
    if (file.existsSync()) {
      return Image.file(file, fit: BoxFit.cover);
    }
    return const ColoredBox(
      color: Colors.black12,
      child: Center(child: Icon(Icons.image_not_supported)),
    );
  }

  Future<void> _shareEmployeePhoto(
    BuildContext context,
    AppUser employee,
  ) async {
    final dataBytes = _photoDataBytes(employee.photoPath);
    if (dataBytes != null) {
      await SharePlus.instance.share(
        ShareParams(
          title: '${employee.name} photo',
          files: [
            XFile.fromData(
              dataBytes,
              mimeType: _dataMimeType(employee.photoPath),
              name: '${employee.name}_photo.jpg',
            ),
          ],
        ),
      );
      return;
    }
    final file = File(employee.photoPath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo file not found on this device.')),
      );
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        title: '${employee.name} photo',
        files: [XFile(file.path)],
        fileNameOverrides: ['${employee.name}_photo${_extension(file.path)}'],
      ),
    );
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    return dot == -1 ? '.jpg' : path.substring(dot);
  }

  Uint8List? _photoDataBytes(String value) {
    if (!value.startsWith('data:image/')) return null;
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    return base64Decode(value.substring(comma + 1));
  }

  String _dataMimeType(String value) {
    final match = RegExp(r'^data:([^;]+);base64,').firstMatch(value);
    return match?.group(1) ?? 'image/jpeg';
  }

  Future<void> _showEmployeeForm(
    BuildContext context,
    WidgetRef ref,
    AppUser? employee,
  ) async {
    final name = TextEditingController(text: employee?.name ?? '');
    final email = TextEditingController(text: employee?.email ?? '');
    final pin = TextEditingController(text: employee?.pin ?? '');
    final salary = TextEditingController(
      text: (employee?.monthlySalary ?? 0).toString(),
    );
    final commission = TextEditingController(
      text: (employee?.commissionPercent ?? 0).toString(),
    );
    final phone = TextEditingController(text: employee?.phone ?? '');
    final idCard = TextEditingController(text: employee?.idCardNumber ?? '');
    final address = TextEditingController(text: employee?.address ?? '');
    final photoPath = TextEditingController(text: employee?.photoPath ?? '');
    final allEmployees = ref
        .read(usersProvider)
        .where((user) => user.role != UserRole.admin)
        .toList();
    var role = employee?.role ?? UserRole.seller;
    var managerId = employee?.managerId ?? '';
    var startDate = employee?.startDate;
    var dutyStart = _parseDutyTime(employee?.dutyStartTime ?? '');
    var dutyEnd = _parseDutyTime(employee?.dutyEndTime ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                employee == null ? 'Add employee' : 'Edit employee',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: photoPath.text.trim().isEmpty
                            ? const ColoredBox(
                                color: Colors.black12,
                                child: Center(child: Icon(Icons.person)),
                              )
                            : _employeePhoto(
                                AppUser(
                                  id: employee?.id ?? '',
                                  name: name.text,
                                  pin: pin.text,
                                  role: role,
                                  photoPath: photoPath.text.trim(),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 82,
                          );
                          if (picked == null) return;
                          final savedPath = await _saveEmployeePhoto(picked);
                          photoPath.text = savedPath;
                          setSheetState(() {});
                        } on PlatformException catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Photo upload failed: ${error.message ?? error.code}',
                              ),
                            ),
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Photo upload failed: $error'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Upload photo'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _spacedField(
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
              ),
              _spacedField(
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
              ),
              _spacedField(
                TextField(
                  controller: pin,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText:
                        'Minimum 8 characters with alphabet, number and special character',
                  ),
                ),
              ),
              _spacedField(
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
              ),
              _spacedField(
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() => startDate = picked);
                    }
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    startDate == null
                        ? 'Set starting date'
                        : 'Starting date ${dateFormat.format(startDate!)}',
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _spacedField(
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                dutyStart ??
                                const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (picked != null) {
                            setSheetState(() => dutyStart = picked);
                          }
                        },
                        icon: const Icon(Icons.schedule),
                        label: Text(
                          dutyStart == null
                              ? 'Duty start'
                              : 'Start ${_formatDutyTime(dutyStart!)}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _spacedField(
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime:
                                dutyEnd ?? const TimeOfDay(hour: 18, minute: 0),
                          );
                          if (picked != null) {
                            setSheetState(() => dutyEnd = picked);
                          }
                        },
                        icon: const Icon(Icons.more_time),
                        label: Text(
                          dutyEnd == null
                              ? 'Duty end'
                              : 'End ${_formatDutyTime(dutyEnd!)}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _spacedField(
                TextField(
                  controller: idCard,
                  decoration: const InputDecoration(
                    labelText: 'ID card number',
                  ),
                ),
              ),
              _spacedField(
                TextField(
                  controller: address,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
              ),
              _spacedField(
                TextField(
                  controller: photoPath,
                  decoration: const InputDecoration(
                    labelText: 'Photo path or URL',
                  ),
                  onChanged: (_) => setSheetState(() {}),
                ),
              ),
              _spacedField(
                DropdownButtonFormField<UserRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: UserRole.values
                      .where((value) => value != UserRole.admin)
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() {
                        role = value;
                        if (_isManagerRole(role)) managerId = '';
                      });
                    }
                  },
                ),
              ),
              if (!_isManagerRole(role))
                _spacedField(
                  DropdownButtonFormField<String>(
                    initialValue: managerId,
                    decoration: const InputDecoration(labelText: 'Manager'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('No manager'),
                      ),
                      for (final manager in allEmployees.where(
                        (user) =>
                            _isManagerRole(user.role) &&
                            user.id != employee?.id,
                      ))
                        DropdownMenuItem(
                          value: manager.id,
                          child: Text(manager.name),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setSheetState(() => managerId = value);
                      }
                    },
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _spacedField(
                      TextField(
                        controller: salary,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monthly salary',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _spacedField(
                      TextField(
                        controller: commission,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Commission %',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        final passwordError = validateStrongPassword(
                          pin.text.trim(),
                        );
                        if (name.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Employee name is required.'),
                            ),
                          );
                          return;
                        }
                        if (email.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Employee email is required.'),
                            ),
                          );
                          return;
                        }
                        if (passwordError != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(passwordError)),
                          );
                          return;
                        }
                        final saved = AppUser(
                          id: employee?.id ?? newId('user'),
                          name: name.text.trim(),
                          email: email.text.trim().toLowerCase(),
                          pin: pin.text.trim(),
                          role: role,
                          managerId: _isManagerRole(role) || managerId.isEmpty
                              ? null
                              : managerId,
                          shopId:
                              employee?.shopId ??
                              ref.read(selectedShopProvider)?.id,
                          monthlySalary: double.tryParse(salary.text) ?? 0,
                          commissionPercent:
                              double.tryParse(commission.text) ?? 0,
                          phone: phone.text.trim(),
                          idCardNumber: idCard.text.trim(),
                          address: address.text.trim(),
                          photoPath: photoPath.text.trim(),
                          startDate: startDate,
                          dutyStartTime: dutyStart == null
                              ? ''
                              : _formatDutyTime(dutyStart!),
                          dutyEndTime: dutyEnd == null
                              ? ''
                              : _formatDutyTime(dutyEnd!),
                          lastLoginAt: employee?.lastLoginAt,
                          lastLogoutAt: employee?.lastLogoutAt,
                          lastSeenAt: employee?.lastSeenAt,
                          isLoggedIn: employee?.isLoggedIn ?? false,
                          leaves: employee?.leaves ?? const [],
                          biometricEnabled: employee?.biometricEnabled ?? false,
                        );
                        await ref.read(usersProvider.notifier).save(saved);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spacedField(Widget child) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: child);
  }

  TimeOfDay? _parseDutyTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDutyTime(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<String> _saveEmployeePhoto(XFile picked) async {
    if (kIsWeb) {
      final bytes = await picked.readAsBytes();
      final mimeType = picked.mimeType ?? 'image/jpeg';
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    }
    final supportDirectory = await getApplicationSupportDirectory();
    final directory = Directory('${supportDirectory.path}/EmployeePhotos');
    if (!await directory.exists()) await directory.create(recursive: true);
    final extension = _extension(picked.path);
    final target = File(
      '${directory.path}/${newId('employee_photo')}$extension',
    );
    await File(picked.path).copy(target.path);
    return target.path;
  }
}

class _EmployeeSales {
  const _EmployeeSales({
    required this.quantity,
    required this.sales,
    required this.profit,
  });

  final double quantity;
  final double sales;
  final double profit;

  String get quantityText =>
      quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
}

class _EmployeeLeaveRecord {
  const _EmployeeLeaveRecord({
    required this.employee,
    required this.leave,
    required this.leaveIndex,
  });

  final AppUser employee;
  final EmployeeLeave leave;
  final int leaveIndex;
}

class _EmployeePresenceStatus {
  const _EmployeePresenceStatus({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

class _RecentBills extends ConsumerStatefulWidget {
  const _RecentBills({required this.bills});

  final List<Bill> bills;

  @override
  ConsumerState<_RecentBills> createState() => _RecentBillsState();
}

class _RecentBillsState extends ConsumerState<_RecentBills> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final shop = ref.watch(selectedShopProvider);
    final filtered = widget.bills.where((bill) {
      final haystack =
          '${bill.invoiceNumber} ${bill.grandTotal.toStringAsFixed(0)} ${moneyFormat.format(bill.grandTotal)}'
              .toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent invoices',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            SearchBar(
              hintText: 'Search invoice ID or total bill',
              leading: const Icon(Icons.search),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            for (final bill in filtered.take(6))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt),
                title: Text(bill.invoiceNumber),
                subtitle: Text(compactDateFormat.format(bill.createdAt)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(moneyFormat.format(bill.grandTotal)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.print, size: 20),
                      tooltip: 'Print receipt',
                      onPressed: shop == null
                          ? null
                          : () {
                              InvoiceService().printInvoice(
                                shop: shop,
                                bill: bill,
                              );
                            },
                    ),
                  ],
                ),
                onTap: shop == null
                    ? null
                    : () {
                        InvoiceService().printInvoice(shop: shop, bill: bill);
                      },
              ),
            if (widget.bills.isEmpty)
              const Text('No invoices yet. Start from POS.'),
            if (widget.bills.isNotEmpty && filtered.isEmpty)
              const Text('No invoices matched your search.'),
          ],
        ),
      ),
    );
  }
}

class _Alerts extends StatelessWidget {
  const _Alerts({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final alerts = products
        .where((product) => product.isLowStock || product.isExpiringSoon)
        .take(8)
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inventory alerts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (final product in alerts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  product.isLowStock ? Icons.warning_amber : Icons.schedule,
                ),
                title: Text(product.name),
                subtitle: Text(
                  product.isLowStock
                      ? '${product.stockQuantity} ${product.unit} left'
                      : 'Expires ${dateFormat.format(product.expiryDate!)}',
                ),
              ),
            if (alerts.isEmpty) const Text('All stock levels look healthy.'),
          ],
        ),
      ),
    );
  }
}
