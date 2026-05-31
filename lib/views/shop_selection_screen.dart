import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/app_providers.dart';
import '../models/app_models.dart';
import '../utils/formatters.dart';

class ShopSelectionScreen extends ConsumerWidget {
  const ShopSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(shopsProvider);
    final selected = ref.watch(selectedShopProvider);
    final user = ref.watch(authProvider);
    final availableShops = shops;
    final canCreateShop = user?.role == UserRole.admin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select shop'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: canCreateShop
          ? FloatingActionButton.extended(
              onPressed: () => _showShopDialog(context, ref),
              icon: const Icon(Icons.add_business),
              label: const Text('New shop'),
            )
          : null,
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisExtent: 180,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: availableShops.length,
        itemBuilder: (context, index) {
          final shop = availableShops[index];
          final active = selected?.id == shop.id;
          return Card(
            color: active
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await ref.read(selectedShopProvider.notifier).select(shop);
                if (context.mounted && Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront,
                      color: Color(shop.themeSeed),
                      size: 34,
                    ),
                    const Spacer(),
                    Text(
                      shop.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('${shop.type} • ${shop.currency}'),
                    if (shop.phone.isNotEmpty) Text(shop.phone),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showShopDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final type = TextEditingController(text: 'Retail');
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create shop'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Shop name'),
              ),
              TextField(
                controller: type,
                decoration: const InputDecoration(labelText: 'Shop type'),
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
              final user = ref.read(authProvider);
              final shop = Shop(
                id: newId('shop'),
                name: name.text.trim(),
                type: type.text.trim().isEmpty ? 'Retail' : type.text.trim(),
                currency: 'PKR',
                ownerAdminId: user?.id,
                createdAt: DateTime.now(),
              );
              await ref.read(shopsProvider.notifier).addShop(shop);
              await ref.read(selectedShopProvider.notifier).select(shop);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
