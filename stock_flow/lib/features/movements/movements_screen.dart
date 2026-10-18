import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/enums.dart';
import '../../core/providers.dart';

class MovementsScreen extends ConsumerStatefulWidget {
  const MovementsScreen({super.key});

  @override
  ConsumerState<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends ConsumerState<MovementsScreen> {
  int? _productIdFilter;

  @override
  Widget build(BuildContext context) {
    final movementsAsync = ref.watch(movementsStreamProvider(_productIdFilter));
    final productsAsync = ref.watch(productsStreamProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: DropdownButtonFormField<int?>(
            key: const Key('productFilterDropdown'),
            initialValue: _productIdFilter,
            decoration: const InputDecoration(
              labelText: 'Filtrar por producto',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todos los productos'),
              ),
              for (final product in productsAsync.valueOrNull ?? const <Product>[])
                DropdownMenuItem<int?>(
                  value: product.id,
                  child: Text(product.nombre),
                ),
            ],
            onChanged: (value) {
              setState(() => _productIdFilter = value);
            },
          ),
        ),
        Expanded(
          child: movementsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (movements) {
              if (movements.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.swap_vert_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay movimientos registrados',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final formatter = DateFormat('dd/MM/yyyy HH:mm');

              return ListView.builder(
                itemCount: movements.length,
                itemBuilder: (context, index) {
                  final item = movements[index];
                  final isEntrada = item.movement.tipo == MovementType.entrada;

                  return ListTile(
                    leading: Icon(
                      isEntrada
                          ? Icons.add_circle_outline
                          : Icons.remove_circle_outline,
                      color: isEntrada ? Colors.green : Colors.red,
                    ),
                    title: Text(item.product.nombre),
                    subtitle: Text(
                      '${item.product.sku} · ${item.movement.motivo.label} · '
                      '${formatter.format(item.movement.fecha)}',
                    ),
                    trailing: Text(
                      '${isEntrada ? '+' : '-'}${item.movement.cantidad}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isEntrada ? Colors.green : Colors.red,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
