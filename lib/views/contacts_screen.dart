import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_providers.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key, required this.suppliers});

  final bool suppliers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(selectedShopProvider);
    final user = ref.watch(authProvider);
    final dealersList = ref.watch(customersProvider);
    final suppliersList = ref.watch(suppliersProvider);
    final bills = ref.watch(billsProvider);
    final items = suppliers ? suppliersList : dealersList;
    final soldCounts = _dealerSoldCounts(bills);
    return Scaffold(
      appBar: AppBar(title: Text(suppliers ? 'Suppliers' : 'Suppliers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: shop == null || user?.canManageProducts != true
            ? null
            : () => _showDialog(context, ref, shop.id),
        icon: Icon(suppliers ? Icons.local_shipping : Icons.add_business),
        label: Text(suppliers ? 'New supplier' : 'New supplier'),
      ),
      body: items.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * .55,
                  child: EmptyState(
                    icon: suppliers
                        ? Icons.local_shipping_outlined
                        : Icons.store_mall_directory_outlined,
                    title: suppliers ? 'No suppliers yet' : 'No suppliers yet',
                    message:
                        'Create profiles to track purchases, credit, and history.',
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final due = item is Supplier
                    ? item.due
                    : (item as Customer).creditDue;
                final dealer = item is Customer ? item : null;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        suppliers ? Icons.local_shipping : Icons.storefront,
                      ),
                    ),
                    title: Text(
                      item is Supplier ? item.name : (item as Customer).name,
                    ),
                    subtitle: Text(
                      item is Supplier
                          ? item.phone
                          : [
                              if (dealer!.phone.isNotEmpty) dealer.phone,
                              '${soldCounts[dealer.id] ?? 0} products sold',
                            ].join(' • '),
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Due ${moneyFormat.format(due)}'),
                        if (!suppliers && user?.canDeleteRecords == true)
                          IconButton(
                            tooltip: 'Delete supplier',
                            onPressed: () =>
                                _deleteSupplier(context, ref, item as Customer),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    onTap: suppliers || dealer == null
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  SupplierDetailScreen(dealer: dealer),
                            ),
                          ),
                  ),
                );
              },
            ),
    );
  }

  Map<String, double> _dealerSoldCounts(List<Bill> bills) {
    final counts = <String, double>{};
    for (final bill in bills.where((bill) => bill.status == BillStatus.paid)) {
      for (final item in bill.items) {
        final dealerId = item.product.dealerId;
        if (dealerId == null) continue;
        counts[dealerId] = (counts[dealerId] ?? 0) + item.quantity;
      }
    }
    return counts;
  }

  Future<void> _showDialog(
    BuildContext context,
    WidgetRef ref,
    String shopId,
  ) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final company = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(suppliers ? 'Add supplier' : 'Add supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              if (suppliers)
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              if (suppliers) {
                await ref
                    .read(suppliersProvider.notifier)
                    .save(
                      Supplier(
                        id: newId('supplier'),
                        shopId: shopId,
                        name: name.text.trim(),
                        phone: phone.text.trim(),
                        company: company.text.trim(),
                      ),
                    );
              } else {
                await ref
                    .read(customersProvider.notifier)
                    .save(
                      Customer(
                        id: newId('dealer'),
                        shopId: shopId,
                        name: name.text.trim(),
                        phone: phone.text.trim(),
                      ),
                    );
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSupplier(
    BuildContext context,
    WidgetRef ref,
    Customer dealer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${dealer.name}?'),
        content: const Text('This removes the supplier profile.'),
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
      await ref.read(customersProvider.notifier).delete(dealer.id);
    }
  }
}

class SupplierDetailScreen extends ConsumerStatefulWidget {
  const SupplierDetailScreen({super.key, required this.dealer});

  final Customer dealer;

  @override
  ConsumerState<SupplierDetailScreen> createState() =>
      _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends ConsumerState<SupplierDetailScreen> {
  DateTime? _customDate;

  @override
  Widget build(BuildContext context) {
    final bills = ref
        .watch(billsProvider)
        .where((bill) => bill.status == BillStatus.paid)
        .toList();
    final dealerProducts =
        ref
            .watch(productsProvider)
            .where((product) => product.dealerId == widget.dealer.id)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final entries = _entriesForSupplier(bills, widget.dealer.id);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final week = today.subtract(
      Duration(days: today.weekday - DateTime.monday),
    );
    final month = DateTime(now.year, now.month);
    final year = DateTime(now.year);
    final custom = _customDate == null
        ? null
        : _summaryForDate(entries, _customDate!);
    final all = _summarySince(entries, DateTime(2020));

    return Scaffold(
      appBar: AppBar(title: Text(widget.dealer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.storefront)),
              title: Text(widget.dealer.name),
              subtitle: Text(
                [
                  if (widget.dealer.phone.isNotEmpty) widget.dealer.phone,
                  if (widget.dealer.address.isNotEmpty) widget.dealer.address,
                ].join(' • '),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            children: [
              _summaryTile('Daily', _summarySince(entries, today), Icons.today),
              _summaryTile(
                'Weekly',
                _summarySince(entries, week),
                Icons.view_week,
              ),
              _summaryTile(
                'Monthly',
                _summarySince(entries, month),
                Icons.calendar_month,
              ),
              _summaryTile(
                'Yearly',
                _summarySince(entries, year),
                Icons.event_available,
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _pickCustomDate,
                child: _summaryTile(
                  _customDate == null
                      ? 'Custom date'
                      : dateFormat.format(_customDate!),
                  custom ?? const _SupplierSalesSummary(),
                  Icons.date_range,
                ),
              ),
              _summaryTile('All sales', all, Icons.analytics),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'All supplier products',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (dealerProducts.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No products assigned to this supplier yet.'),
              ),
            )
          else
            for (final product in dealerProducts)
              Card(
                child: ListTile(
                  leading: Icon(
                    product.isLowStock
                        ? Icons.warning_amber
                        : Icons.inventory_2,
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    [
                      product.sku,
                      product.category,
                      '${product.stockQuantity} ${product.unit} in stock',
                      if (product.expiryDate != null)
                        'Expiry ${dateFormat.format(product.expiryDate!)}',
                    ].join(' • '),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(moneyFormat.format(product.sellingPrice)),
                      Text('Buy ${moneyFormat.format(product.buyingPrice)}'),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Text(
            'Product sale history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No paid sales found for this supplier yet.'),
              ),
            )
          else
            for (final entry in entries)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2),
                  title: Text(entry.productName),
                  subtitle: Text(
                    '${dateFormat.format(entry.createdAt)} • ${entry.quantityText} sold',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(moneyFormat.format(entry.sales)),
                      Text(
                        'P/L ${moneyFormat.format(entry.profit)}',
                        style: TextStyle(
                          color: entry.profit < 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _summaryTile(
    String title,
    _SupplierSalesSummary summary,
    IconData icon,
  ) {
    final color = summary.profit < 0 ? Colors.red : Colors.teal;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title sales'),
                  const SizedBox(height: 4),
                  Text(
                    moneyFormat.format(summary.sales),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'P/L ${moneyFormat.format(summary.profit)} • ${summary.quantityText} sold',
                    style: TextStyle(color: color),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  List<_SupplierSaleEntry> _entriesForSupplier(
    List<Bill> bills,
    String dealerId,
  ) {
    final entries = <_SupplierSaleEntry>[];
    for (final bill in bills) {
      for (final item in bill.items) {
        if (item.product.dealerId != dealerId) continue;
        entries.add(
          _SupplierSaleEntry(
            createdAt: bill.createdAt,
            invoiceNumber: bill.invoiceNumber,
            productName: item.product.name,
            quantity: item.quantity,
            unit: item.product.unit,
            sales: item.total,
            profit: item.profit,
          ),
        );
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  _SupplierSalesSummary _summarySince(
    List<_SupplierSaleEntry> entries,
    DateTime start,
  ) {
    final now = DateTime.now();
    return _summarize(
      entries.where(
        (entry) =>
            !entry.createdAt.isBefore(start) && !entry.createdAt.isAfter(now),
      ),
    );
  }

  _SupplierSalesSummary _summaryForDate(
    List<_SupplierSaleEntry> entries,
    DateTime date,
  ) {
    return _summarize(
      entries.where(
        (entry) =>
            entry.createdAt.year == date.year &&
            entry.createdAt.month == date.month &&
            entry.createdAt.day == date.day,
      ),
    );
  }

  _SupplierSalesSummary _summarize(Iterable<_SupplierSaleEntry> entries) {
    return entries.fold(
      const _SupplierSalesSummary(),
      (summary, entry) => _SupplierSalesSummary(
        sales: summary.sales + entry.sales,
        profit: summary.profit + entry.profit,
        quantity: summary.quantity + entry.quantity,
      ),
    );
  }
}

class _SupplierSaleEntry {
  const _SupplierSaleEntry({
    required this.createdAt,
    required this.invoiceNumber,
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.sales,
    required this.profit,
  });

  final DateTime createdAt;
  final String invoiceNumber;
  final String productName;
  final double quantity;
  final String unit;
  final double sales;
  final double profit;

  String get quantityText =>
      '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2)} $unit';
}

class _SupplierSalesSummary {
  const _SupplierSalesSummary({
    this.sales = 0,
    this.profit = 0,
    this.quantity = 0,
  });

  final double sales;
  final double profit;
  final double quantity;

  String get quantityText =>
      quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
}
