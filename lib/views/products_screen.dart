import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../controllers/app_providers.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';
import '../widgets/app_widgets.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _query = '';
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final dealers = ref.watch(customersProvider);
    final user = ref.watch(authProvider);
    final dealerNames = {for (final dealer in dealers) dealer.id: dealer.name};
    final categories = <String>[
      'All',
      ...{for (final product in products) product.category},
    ];
    final filtered = products.where((product) {
      final dealerName = dealerNames[product.dealerId] ?? '';
      final queryMatch =
          '${product.name} ${product.sku} ${product.category} $dealerName'
              .toLowerCase()
              .contains(_query.toLowerCase());
      final categoryMatch = _category == 'All' || product.category == _category;
      return queryMatch && categoryMatch;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Scan product barcode',
            onPressed: _scanAndAddProduct,
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: user?.canManageProducts == true
            ? () => _showProductSheet(context)
            : null,
        icon: const Icon(Icons.add_box),
        label: const Text('Add product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SearchBar(
                    hintText: 'Search product, barcode, category',
                    leading: const Icon(Icons.search),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _category,
                  items: categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'All'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products found',
                      message: 'Add products or adjust the search filters.',
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final dealerName = dealerNames[product.dealerId] ?? '';
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: product.isLowStock
                                  ? Theme.of(context).colorScheme.errorContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer,
                              child: Icon(
                                product.isLowStock
                                    ? Icons.warning_amber
                                    : Icons.inventory,
                              ),
                            ),
                            title: Text(
                              product.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              [
                                product.sku,
                                product.category,
                                '${product.stockQuantity} ${product.unit}',
                                if (dealerName.isNotEmpty) dealerName,
                              ].join(' • '),
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(moneyFormat.format(product.sellingPrice)),
                                IconButton(
                                  tooltip: 'Purchase stock',
                                  onPressed: () => _purchaseStock(product),
                                  icon: const Icon(Icons.add_shopping_cart),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: user?.canManageProducts == true
                                      ? () => _showProductSheet(
                                          context,
                                          product: product,
                                        )
                                      : null,
                                  icon: const Icon(Icons.edit),
                                ),
                                if (user?.canDeleteRecords == true)
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteProduct(product),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchaseStock(Product product) async {
    final controller = TextEditingController(text: '1');
    final dealers = ref.read(customersProvider);
    String? dealerId = product.dealerId;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Purchase ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity (${product.unit})',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                initialValue: dealerId,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.storefront),
                  labelText: 'Supplier',
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('No supplier selected'),
                  ),
                  ...dealers.map(
                    (dealer) => DropdownMenuItem<String?>(
                      value: dealer.id,
                      child: Text(dealer.name),
                    ),
                  ),
                ],
                onChanged: (value) => setDialogState(() => dealerId = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(controller.text) ?? 0;
                if (qty > 0) {
                  await ref
                      .read(productsProvider.notifier)
                      .purchaseStock(product, qty, dealerId: dealerId);
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${product.name}?'),
        content: const Text('This removes the product from inventory.'),
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
      await ref.read(productsProvider.notifier).delete(product.id);
    }
  }

  Future<void> _scanAndAddProduct() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;
    final barcode = code.trim();
    final existing = ref
        .read(productsProvider)
        .where((product) => product.sku == barcode)
        .firstOrNull;
    await _showProductSheet(context, product: existing, initialSku: barcode);
  }

  Future<String?> _scanBarcode(BuildContext context) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  Future<void> _showProductSheet(
    BuildContext context, {
    Product? product,
    String? initialSku,
  }) async {
    final shop = ref.read(selectedShopProvider);
    if (shop == null) return;
    final name = TextEditingController(text: product?.name ?? '');
    final sku = TextEditingController(text: product?.sku ?? initialSku ?? '');
    final category = TextEditingController(text: product?.category ?? '');
    final buying = TextEditingController(
      text: (product?.buyingPrice ?? 0).toString(),
    );
    final selling = TextEditingController(
      text: (product?.sellingPrice ?? 0).toString(),
    );
    final stock = TextEditingController(
      text: (product?.stockQuantity ?? 0).toString(),
    );
    final unit = TextEditingController(text: product?.unit ?? 'pcs');
    final discount = TextEditingController(
      text: (product?.discountPercent ?? 0).toString(),
    );
    final tax = TextEditingController(
      text: (product?.taxPercent ?? 0).toString(),
    );
    final dealers = ref.read(customersProvider);
    String? dealerId = product?.dealerId;
    DateTime? expiryDate = product?.expiryDate;
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
                product == null ? 'Add product' : 'Edit product',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _field(name, 'Product name'),
              _field(
                sku,
                'Barcode / SKU',
                suffixIcon: IconButton(
                  tooltip: 'Scan barcode',
                  onPressed: () async {
                    final code = await _scanBarcode(context);
                    if (code != null && code.trim().isNotEmpty) {
                      sku.text = code.trim();
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ),
              _field(category, 'Category'),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String?>(
                  initialValue: dealerId,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.storefront),
                    labelText: 'Supplier',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('No supplier selected'),
                    ),
                    ...dealers.map(
                      (dealer) => DropdownMenuItem<String?>(
                        value: dealer.id,
                        child: Text(dealer.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => dealerId = value),
                ),
              ),
              Row(
                children: [
                  Expanded(child: _field(buying, 'Buying price')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(selling, 'Selling price')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(stock, 'Stock')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(unit, 'Unit')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _field(discount, 'Discount %')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(tax, 'Tax %')),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: expiryDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setSheetState(() => expiryDate = picked);
                    }
                  },
                  icon: const Icon(Icons.event),
                  label: Text(
                    expiryDate == null
                        ? 'Set expiry date'
                        : 'Expiry ${dateFormat.format(expiryDate!)}',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final saved = Product(
                    id: product?.id ?? newId('product'),
                    shopId: shop.id,
                    name: name.text.trim(),
                    sku: sku.text.trim(),
                    category: category.text.trim().isEmpty
                        ? 'General'
                        : category.text.trim(),
                    buyingPrice: double.tryParse(buying.text) ?? 0,
                    sellingPrice: double.tryParse(selling.text) ?? 0,
                    stockQuantity: double.tryParse(stock.text) ?? 0,
                    unit: unit.text.trim().isEmpty ? 'pcs' : unit.text.trim(),
                    discountPercent: double.tryParse(discount.text) ?? 0,
                    taxPercent: double.tryParse(tax.text) ?? 0,
                    dealerId: dealerId,
                    expiryDate: expiryDate,
                    imagePath: product?.imagePath,
                    lowStockThreshold: product?.lowStockThreshold ?? 5,
                  );
                  await ref.read(productsProvider.notifier).save(saved);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.save),
                label: const Text('Save product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    Widget? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
      ),
    );
  }
}

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _manualController = TextEditingController();
  bool _handled = false;

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    if (_handled) return;
                    final code = capture.barcodes
                        .map((barcode) => barcode.rawValue)
                        .whereType<String>()
                        .where((value) => value.trim().isNotEmpty)
                        .firstOrNull;
                    if (code == null) return;
                    _handled = true;
                    Navigator.of(context).pop(code.trim());
                  },
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 260,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Enter barcode manually',
                        prefixIcon: Icon(Icons.qr_code_2),
                      ),
                      onSubmitted: _submitManual,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: () => _submitManual(_manualController.text),
                    icon: const Icon(Icons.check),
                    label: const Text('Use'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _submitManual(String value) {
    final code = value.trim();
    if (code.isEmpty) return;
    Navigator.of(context).pop(code);
  }
}
