import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../products/product_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
      data: (summary) {
        final lowStock = (productsAsync.valueOrNull ?? const <Product>[])
            .where((p) => p.stock <= p.stockMinimo)
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.inventory_2_outlined,
                    color: Colors.teal,
                    label: 'Total de productos',
                    valueKey: const Key('totalProductsValue'),
                    value: '${summary.totalProducts}',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.warning_amber_rounded,
                    color: Colors.orange,
                    label: 'Stock bajo',
                    valueKey: const Key('lowStockValue'),
                    value: '${summary.lowStockProducts}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummaryCard(
              icon: Icons.attach_money,
              color: Colors.green,
              label: 'Valor del inventario',
              valueKey: const Key('inventoryValue'),
              value: '\$${(summary.totalValueCentavos / 100).toStringAsFixed(2)}',
            ),
            const SizedBox(height: 4),
            const Text(
              'Excluye los productos sin precio',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
            Text(
              'Productos con stock bajo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (lowStock.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Sin productos con stock bajo'),
              )
            else
              for (final product in lowStock)
                Card(
                  child: ListTile(
                    title: Text(product.nombre),
                    subtitle: Text('SKU: ${product.sku}'),
                    trailing: Text(
                      'Stock: ${product.stock}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              ProductDetailScreen(productId: product.id),
                        ),
                      );
                    },
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.valueKey,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              key: valueKey,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
