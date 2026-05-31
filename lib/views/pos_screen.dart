import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_providers.dart';
import '../models/app_models.dart';
import '../services/invoice_service.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final cart = ref.watch(cartProvider);
    final filtered = products
        .where(
          (product) => '${product.name} ${product.sku}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .take(30)
        .toList();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final productPane = _ProductPane(
      products: filtered,
      onSearch: (value) => setState(() => _query = value),
      onTap: (product) => ref.read(cartProvider.notifier).add(product),
    );
    final cartPane = _CartPane(cart: cart);
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Billing'),
        actions: [
          IconButton(
            tooltip: 'Barcode scan entry',
            onPressed: () => _barcodeDialog(context),
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: wide
            ? Row(
                children: [
                  Expanded(flex: 3, child: productPane),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: cartPane),
                ],
              )
            : Column(
                children: [
                  SizedBox(height: 310, child: productPane),
                  const SizedBox(height: 12),
                  Expanded(child: cartPane),
                ],
              ),
      ),
    );
  }

  Future<void> _barcodeDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scan or enter barcode'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.qr_code_2),
              labelText: 'Barcode / SKU',
            ),
            onSubmitted: (value) {
              ref.read(cartProvider.notifier).scan(value);
              Navigator.pop(context);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).scan(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ProductPane extends ConsumerStatefulWidget {
  const _ProductPane({
    required this.products,
    required this.onSearch,
    required this.onTap,
  });

  final List<Product> products;
  final ValueChanged<String> onSearch;
  final ValueChanged<Product> onTap;

  @override
  ConsumerState<_ProductPane> createState() => _ProductPaneState();
}

class _ProductPaneState extends ConsumerState<_ProductPane> {
  final Map<String, double> _quantities = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBar(
          hintText: 'Search product or barcode',
          leading: const Icon(Icons.search),
          onChanged: widget.onSearch,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.products.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off,
                  title: 'No match',
                  message: 'Try a product name or SKU.',
                )
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    mainAxisExtent: 168,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: widget.products.length,
                  itemBuilder: (context, index) {
                    final product = widget.products[index];
                    final quantity = _quantities[product.id] ?? 1.0;
                    final canSell = product.stockQuantity > 0;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: canSell
                            ? () => _addProduct(product, quantity)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      moneyFormat.format(product.sellingPrice),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    Text(
                                      canSell
                                          ? '${product.stockQuantity} ${product.unit}'
                                          : 'Out of stock',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: canSell
                                                ? null
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    tooltip: 'Decrease quantity',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: canSell
                                        ? () {
                                            setState(() {
                                              _quantities[product.id] =
                                                  (quantity - 1).clamp(
                                                    1.0,
                                                    product.stockQuantity,
                                                  );
                                            });
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.remove_circle,
                                      size: 20,
                                    ),
                                  ),
                                  Text(
                                    quantity.toStringAsFixed(
                                      quantity % 1 == 0 ? 0 : 1,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Increase quantity',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 32,
                                      minHeight: 32,
                                    ),
                                    onPressed: canSell
                                        ? () {
                                            setState(() {
                                              _quantities[product.id] =
                                                  (quantity + 1).clamp(
                                                    1.0,
                                                    product.stockQuantity,
                                                  );
                                            });
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.add_circle,
                                      size: 20,
                                    ),
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'Add to bill',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 34,
                                      minHeight: 34,
                                    ),
                                    onPressed: canSell
                                        ? () => _addProduct(product, quantity)
                                        : null,
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _addProduct(Product product, double quantity) {
    ref.read(cartProvider.notifier).addWithQuantity(product, quantity);
    setState(() => _quantities[product.id] = 1.0);
  }
}

class _CartPane extends ConsumerWidget {
  const _CartPane({required this.cart});

  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(selectedShopProvider);
    final currentUser = ref.watch(authProvider);
    final employees = ref
        .watch(usersProvider)
        .where((user) => user.role != UserRole.admin)
        .toList();
    final selectedEmployeeId =
        cart.sellerId ??
        (currentUser?.role == UserRole.admin
            ? (employees.isEmpty ? null : employees.first.id)
            : currentUser?.id);
    return Scrollbar(
      child: ListView(
        padding: const EdgeInsets.all(4),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'Current bill',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              IconButton(
                tooltip: 'Clear bill',
                onPressed: cart.items.isEmpty
                    ? null
                    : () => ref.read(cartProvider.notifier).clear(),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              SegmentedButton<PaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: PaymentMethod.cash,
                    icon: Icon(Icons.payments),
                    label: Text('Cash'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.mixed,
                    icon: Icon(Icons.call_split),
                    label: Text('Mixed'),
                  ),
                  ButtonSegment(
                    value: PaymentMethod.credit,
                    icon: Icon(Icons.request_quote),
                    label: Text('Credit'),
                  ),
                ],
                selected: {cart.paymentMethod},
                onSelectionChanged: (value) => ref
                    .read(cartProvider.notifier)
                    .setPaymentMethod(value.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedEmployeeId,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge),
              labelText: 'Employee selling',
            ),
            items: employees
                .map(
                  (employee) => DropdownMenuItem(
                    value: employee.id,
                    child: Text('${employee.name} (${employee.roleLabel})'),
                  ),
                )
                .toList(),
            onChanged: employees.isEmpty
                ? null
                : (value) => ref.read(cartProvider.notifier).setSeller(value),
          ),
          const SizedBox(height: 8),
          if (cart.items.isEmpty)
            const SizedBox(
              height: 180,
              child: EmptyState(
                icon: Icons.point_of_sale,
                title: 'Cart is empty',
                message: 'Tap products to build a bill fast.',
              ),
            )
          else
            ...cart.items.map((item) {
              return Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${item.quantity} x ${moneyFormat.format(item.product.sellingPrice)}',
                    ),
                    trailing: Wrap(
                      spacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Remove',
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(item.product.id, 0),
                          icon: const Icon(Icons.close),
                        ),
                        IconButton(
                          tooltip: 'Decrease',
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                item.product.id,
                                item.quantity - 1,
                              ),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          item.quantity.toStringAsFixed(
                            item.quantity % 1 == 0 ? 0 : 2,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Increase',
                          onPressed: () => ref
                              .read(cartProvider.notifier)
                              .updateQuantity(
                                item.product.id,
                                item.quantity + 1,
                              ),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        SizedBox(
                          width: 72,
                          child: Text(
                            moneyFormat.format(item.total),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              );
            }),
          const SizedBox(height: 8),
          _totalRow('Subtotal', moneyFormat.format(cart.subTotal)),
          _totalRow('Item discounts', moneyFormat.format(cart.itemDiscount)),
          _totalRow('Tax', moneyFormat.format(cart.tax)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.discount),
                labelText: 'Total discount',
              ),
              onChanged: (value) => ref
                  .read(cartProvider.notifier)
                  .setTotalDiscount(double.tryParse(value) ?? 0),
            ),
          ),
          _totalRow(
            'Grand total',
            moneyFormat.format(cart.grandTotal),
            bold: true,
          ),
          if (cart.paymentMethod == PaymentMethod.credit)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.payments_outlined),
                  labelText: 'Paid now',
                ),
                onChanged: (value) => ref
                    .read(cartProvider.notifier)
                    .setPaidAmount(double.tryParse(value) ?? 0),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cart.items.isEmpty
                      ? null
                      : () => ref
                            .read(cartProvider.notifier)
                            .checkout(status: BillStatus.held),
                  icon: const Icon(Icons.pause_circle_outline),
                  label: const Text('Hold'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: cart.items.isEmpty
                      ? null
                      : () async {
                          final bill = await ref
                              .read(cartProvider.notifier)
                              .checkout();
                          if (context.mounted && bill != null && shop != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Paid ${moneyFormat.format(bill.grandTotal)}',
                                ),
                                action: SnackBarAction(
                                  label: 'Print',
                                  onPressed: () => InvoiceService()
                                      .printInvoice(shop: shop, bill: bill),
                                ),
                              ),
                            );
                          }
                        },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Checkout'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
