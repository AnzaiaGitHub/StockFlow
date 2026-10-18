import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/enums.dart';
import '../../core/providers.dart';
import '../movements/movement_form_screen.dart';
import 'exceptions.dart';
import 'product_form_screen.dart';

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final int productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);

    Product? product;
    for (final p in productsAsync.valueOrNull ?? const <Product>[]) {
      if (p.id == widget.productId) {
        product = p;
        break;
      }
    }

    if (product == null) {
      if (productsAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Producto')),
          body: const Center(child: CircularProgressIndicator()),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Producto')),
        body: const Center(child: Text('Producto no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de producto')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildInfoCard(context, product),
          const SizedBox(height: 16),
          _buildActions(context, product),
          const SizedBox(height: 24),
          Text(
            'Últimos movimientos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _buildMovements(context),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Product product) {
    final isLowStock = product.stock <= product.stockMinimo;
    final symbol = r'$';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.nombre,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            _DetailRow(label: 'SKU', value: product.sku),
            if (product.descripcion != null && product.descripcion!.isNotEmpty)
              _DetailRow(label: 'Descripción', value: product.descripcion!),
            _DetailRow(
              label: 'Precio',
              value: product.precioCentavos == null
                  ? 'Sin precio'
                  : '$symbol${(product.precioCentavos! / 100).toStringAsFixed(2)}',
            ),
            _DetailRow(
              label: 'Stock',
              value: '${product.stock}',
              valueColor: isLowStock ? Colors.red : null,
            ),
            _DetailRow(label: 'Stock mínimo', value: '${product.stockMinimo}'),
            if (isLowStock) ...[
              const SizedBox(height: 8),
              Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text('Stock bajo', style: TextStyle(color: Colors.red)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, Product product) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    _openMovementForm(product, MovementType.entrada),
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Entrada'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () =>
                    _openMovementForm(product, MovementType.salida),
                icon: const Icon(Icons.arrow_upward),
                label: const Text('Salida'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : () => _edit(product),
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isDeleting ? null : () => _confirmDelete(product),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMovements(BuildContext context) {
    final movementsAsync = ref.watch(movementsStreamProvider(widget.productId));

    return movementsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Text('Error: $err'),
      data: (movements) {
        if (movements.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin movimientos registrados'),
          );
        }

        final formatter = DateFormat('dd/MM/yyyy HH:mm');
        final recent = movements.take(5).toList();

        return Column(
          children: [
            for (final item in recent)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.movement.tipo == MovementType.entrada
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  color: item.movement.tipo == MovementType.entrada
                      ? Colors.green
                      : Colors.red,
                ),
                title: Text(
                  '${item.movement.tipo == MovementType.entrada ? '+' : '-'}'
                  '${item.movement.cantidad} · ${item.movement.motivo.label}',
                ),
                subtitle: Text(formatter.format(item.movement.fecha)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _edit(Product product) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(product: product),
      ),
    );
  }

  Future<void> _openMovementForm(Product product, MovementType tipo) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) =>
            MovementFormScreen(productId: product.id, tipo: tipo),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Movimiento registrado')),
      );
    }
  }

  Future<void> _confirmDelete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          '¿Seguro que deseas eliminar "${product.nombre}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _delete(product);
    }
  }

  Future<void> _delete(Product product) async {
    setState(() => _isDeleting = true);

    final repository = ref.read(productsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await repository.deleteProduct(product.id);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Producto "${product.nombre}" eliminado')),
      );
    } on ProductHasMovementsException {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: const Text(
            'Este producto tiene movimientos registrados. '
            'Solo se puede eliminar si no tiene movimientos o si su único '
            'movimiento es el de stock inicial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(color: valueColor))),
        ],
      ),
    );
  }
}
