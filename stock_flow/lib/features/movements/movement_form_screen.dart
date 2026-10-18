import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/database/enums.dart';
import '../../core/providers.dart';
import '../products/exceptions.dart';

class MovementFormScreen extends ConsumerStatefulWidget {
  const MovementFormScreen({
    super.key,
    required this.productId,
    required this.tipo,
  });

  final int productId;
  final MovementType tipo;

  @override
  ConsumerState<MovementFormScreen> createState() => _MovementFormScreenState();
}

class _MovementFormScreenState extends ConsumerState<MovementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();

  late final List<MovementReason> _reasons;
  late MovementReason _motivo;

  bool _isLoading = false;
  String? _cantidadError;

  bool get _isEntrada => widget.tipo == MovementType.entrada;

  @override
  void initState() {
    super.initState();
    _reasons = MovementReason.values
        .where((reason) => reason.supports(widget.tipo) && !reason.systemOnly)
        .toList();
    _motivo = _reasons.first;
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

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
      return Scaffold(
        appBar: AppBar(title: Text(_isEntrada ? 'Entrada' : 'Salida')),
        body: productsAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : const Center(child: Text('Producto no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEntrada ? 'Registrar entrada' : 'Registrar salida'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  title: Text(product.nombre),
                  subtitle: Text('SKU: ${product.sku}'),
                  trailing: Text(
                    'Stock: ${product.stock}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MovementReason>(
                key: const Key('motivoDropdown'),
                initialValue: _motivo,
                decoration: const InputDecoration(labelText: 'Motivo'),
                items: [
                  for (final reason in _reasons)
                    DropdownMenuItem(
                      value: reason,
                      child: Text(reason.label),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _motivo = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cantidadController,
                decoration: InputDecoration(
                  labelText: 'Cantidad',
                  errorText: _cantidadError,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'Debe ser un número entero mayor que 0';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_cantidadError != null) {
                    setState(() => _cantidadError = null);
                  }
                },
              ),
              if (!_isEntrada) ...[
                const SizedBox(height: 8),
                Text(
                  'Stock actual: ${product.stock}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: const Text('Registrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _cantidadError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final cantidad = int.parse(_cantidadController.text.trim());
    final repository = ref.read(movementsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await repository.registerMovement(
        productId: widget.productId,
        tipo: widget.tipo,
        motivo: _motivo,
        cantidad: cantidad,
      );
      if (!mounted) return;
      navigator.pop(true);
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      setState(() {
        _cantidadError = 'Stock disponible: ${e.disponible}';
        _isLoading = false;
      });
    } on ProductNotFoundException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('El producto ya no existe')),
      );
    } on InvalidMovementException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
