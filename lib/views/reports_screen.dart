import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_providers.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);
    final bills = ref
        .watch(billsProvider)
        .where((bill) => bill.status == BillStatus.paid)
        .toList();
    final products = ref.watch(productsProvider);
    final users = ref
        .watch(usersProvider)
        .where((user) => user.role != UserRole.admin)
        .toList();
    final totalSalary = users.fold(
      0.0,
      (sum, user) => sum + user.monthlySalary,
    );
    final totalCommission = users.fold(
      0.0,
      (sum, user) =>
          sum + _employeeSales(bills, user.id) * user.commissionPercent / 100,
    );
    final totalPayroll = totalSalary + totalCommission;
    final netProfitAfterSalary = stats.profit - totalPayroll;
    final totalSales = bills.fold(0.0, (sum, bill) => sum + bill.grandTotal);
    final totalDiscount = bills.fold(
      0.0,
      (sum, bill) => sum + bill.itemDiscount + bill.totalDiscount,
    );
    final totalTax = bills.fold(0.0, (sum, bill) => sum + bill.tax);
    final totalDue = bills.fold(0.0, (sum, bill) => sum + bill.dueAmount);
    final averageBill = bills.isEmpty ? 0.0 : totalSales / bills.length;
    final zeroStock = products.where((product) => product.stockQuantity <= 0);
    final lowStock = products.where((product) => product.isLowStock);
    final expiring = products.where((product) => product.isExpiringSoon);
    final methodTotals = <PaymentMethod, double>{};
    final topProducts = <String, _ProductReport>{};

    for (final bill in bills) {
      methodTotals[bill.paymentMethod] =
          (methodTotals[bill.paymentMethod] ?? 0) + bill.grandTotal;
      for (final item in bill.items) {
        final current =
            topProducts[item.product.name] ?? const _ProductReport();
        topProducts[item.product.name] = current.add(item);
      }
    }
    final sortedTop = topProducts.entries.toList()
      ..sort((a, b) => b.value.sales.compareTo(a.value.sales));

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ResponsiveGrid(
            children: [
              MetricTile(
                title: 'Today sales',
                value: moneyFormat.format(stats.todaySales),
                icon: Icons.today,
              ),
              MetricTile(
                title: 'Weekly sales',
                value: moneyFormat.format(stats.weekSales),
                icon: Icons.view_week,
              ),
              MetricTile(
                title: 'Monthly sales',
                value: moneyFormat.format(stats.monthSales),
                icon: Icons.calendar_month,
              ),
              MetricTile(
                title: 'Yearly sales',
                value: moneyFormat.format(stats.yearSales),
                icon: Icons.event_available,
              ),
              MetricTile(
                title: 'Profit',
                value: moneyFormat.format(stats.profit),
                icon: Icons.trending_up,
              ),
              MetricTile(
                title: 'Salary',
                value: moneyFormat.format(totalPayroll),
                icon: Icons.badge,
              ),
              MetricTile(
                title: 'Profit after salary',
                value: moneyFormat.format(netProfitAfterSalary),
                icon: Icons.account_balance_wallet,
              ),
              MetricTile(
                title: 'Total bills',
                value: bills.length.toString(),
                icon: Icons.receipt_long,
              ),
              MetricTile(
                title: 'Average bill',
                value: moneyFormat.format(averageBill),
                icon: Icons.functions,
              ),
              MetricTile(
                title: 'Inventory value',
                value: moneyFormat.format(stats.inventoryValue),
                icon: Icons.warehouse,
              ),
              MetricTile(
                title: 'Zero stock',
                value: zeroStock.length.toString(),
                icon: Icons.remove_shopping_cart,
              ),
              MetricTile(
                title: 'Expiring soon',
                value: expiring.length.toString(),
                icon: Icons.event_busy,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ReportCard(
            title: 'Sales totals',
            children: [
              _reportRow('Gross sales', moneyFormat.format(totalSales)),
              _reportRow('Discounts', moneyFormat.format(totalDiscount)),
              _reportRow('Tax collected', moneyFormat.format(totalTax)),
              _reportRow(
                'Profit before salary',
                moneyFormat.format(stats.profit),
              ),
              _reportRow('Monthly salary', moneyFormat.format(totalSalary)),
              _reportRow('Commission', moneyFormat.format(totalCommission)),
              _reportRow(
                'Salary + commission',
                moneyFormat.format(totalPayroll),
              ),
              _reportRow(
                'Total profit after salary',
                moneyFormat.format(netProfitAfterSalary),
              ),
              _reportRow('Due amount', moneyFormat.format(totalDue)),
            ],
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Employee salary',
            children: [
              for (final user in users)
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: Text(user.name),
                  subtitle: Text(
                    '${user.roleLabel} • ${_employeeSoldQuantity(bills, user.id)} products sold • Earned ${moneyFormat.format(_employeeSales(bills, user.id))} • Commission ${user.commissionPercent}%',
                  ),
                  trailing: Text(
                    moneyFormat.format(
                      user.monthlySalary +
                          _employeeSales(bills, user.id) *
                              user.commissionPercent /
                              100,
                    ),
                  ),
                ),
              if (users.isEmpty) const Text('No employees found.'),
            ],
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Payment breakdown',
            children: [
              for (final entry in methodTotals.entries)
                ListTile(
                  leading: const Icon(Icons.payments),
                  title: Text(entry.key.name.toUpperCase()),
                  trailing: Text(moneyFormat.format(entry.value)),
                ),
              if (methodTotals.isEmpty) const Text('No paid bills yet.'),
            ],
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Top selling products',
            children: [
              for (final entry in sortedTop.take(10))
                ListTile(
                  leading: const Icon(Icons.local_fire_department),
                  title: Text(entry.key),
                  subtitle: Text(
                    '${entry.value.quantityText} sold • P/L ${moneyFormat.format(entry.value.profit)}',
                  ),
                  trailing: Text(moneyFormat.format(entry.value.sales)),
                ),
              if (sortedTop.isEmpty)
                const Text('Sales will appear here after checkout.'),
            ],
          ),
          const SizedBox(height: 12),
          _ReportCard(
            title: 'Stock status',
            children: [
              _reportRow('Products', products.length.toString()),
              _reportRow('Low stock', lowStock.length.toString()),
              _reportRow('Zero stock', zeroStock.length.toString()),
              _reportRow(
                'Expiring within 2 months',
                expiring.length.toString(),
              ),
              if (zeroStock.isNotEmpty) ...[
                const Divider(),
                for (final product in zeroStock.take(8))
                  ListTile(
                    leading: const Icon(Icons.remove_shopping_cart),
                    title: Text(product.name),
                    subtitle: Text('${product.sku} • ${product.category}'),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _employeeSoldQuantity(List<Bill> bills, String userId) {
    final quantity = bills
        .where((bill) => bill.sellerId == userId)
        .expand((bill) => bill.items)
        .fold(0.0, (sum, item) => sum + item.quantity);
    return quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
  }

  double _employeeSales(List<Bill> bills, String userId) {
    return bills
        .where((bill) => bill.sellerId == userId)
        .fold(0.0, (sum, bill) => sum + bill.grandTotal);
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProductReport {
  const _ProductReport({this.quantity = 0, this.sales = 0, this.profit = 0});

  final double quantity;
  final double sales;
  final double profit;

  _ProductReport add(CartItem item) {
    return _ProductReport(
      quantity: quantity + item.quantity,
      sales: sales + item.total,
      profit: profit + item.profit,
    );
  }

  String get quantityText =>
      quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 2);
}
