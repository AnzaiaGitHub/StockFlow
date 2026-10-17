import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/providers.dart';
import '../../features/products/exceptions.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _nombreController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _precioController;
  late final TextEditingController _stockInicialController;
  late final TextEditingController _stockMinimoController;

  bool _isLoading = false;
  String? _skuErrorText;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nombreController = TextEditingController(text: p?.nombre ?? '');
    _descripcionController = TextEditingController(text: p?.descripcion ?? '');
    _precioController = TextEditingController(
      text: p?.precioCentavos != null ? (p!.precioCentavos! / 100).toStringAsFixed(2) : '',
    );
    _stockInicialController = TextEditingController(text: p != null ? '${p.stock}' : '0');
    _stockMinimoController = TextEditingController(text: p != null ? '${p.stockMinimo}' : '0');
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _stockInicialController.dispose();
    _stockMinimoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _skuErrorText = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final sku = _skuController.text.trim();
    final nombre = _nombreController.text.trim();
    final descripcion = _descripcionController.text.trim();
    final descripcionValue = descripcion.isEmpty ? null : descripcion;

    final precioText = _precioController.text.trim();
    int? precioCentavos;
    if (precioText.isNotEmpty) {
      final parsedPrice = double.tryParse(precioText.replaceAll(',', '.')) ?? 0.0;
      precioCentavos = (parsedPrice * 100).round();
    }

    final stockMinimo = int.tryParse(_stockMinimoController.text.trim()) ?? 0;
    final stockInicial = int.tryParse(_stockInicialController.text.trim()) ?? 0;

    final repository = ref.read(productsRepositoryProvider);

    try {
      if (_isEditing) {
        await repository.updateProduct(
          id: widget.product!.id,
          sku: sku,
          nombre: nombre,
          descripcion: descripcionValue,
          precioCentavos: precioCentavos,
          stockMinimo: stockMinimo,
        );
      } else {
        await repository.createProduct(
          sku: sku,
          nombre: nombre,
          descripcion: descripcionValue,
          precioCentavos: precioCentavos,
          stockInicial: stockInicial,
          stockMinimo: stockMinimo,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on DuplicateSkuException {
      setState(() {
        _skuErrorText = 'Este SKU ya está registrado';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Producto' : 'Nuevo Producto'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _skuController,
                      decoration: InputDecoration(
                        labelText: 'SKU *',
                        errorText: _skuErrorText,
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El SKU es obligatorio';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (_skuErrorText != null) {
                          setState(() => _skuErrorText = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre *'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'El nombre es obligatorio';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _precioController,
                      decoration: const InputDecoration(
                        labelText: 'Precio (opcional)',
                        prefixText: '\$ ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
                          if (parsed == null || parsed < 0) {
                            return 'Ingrese un precio válido mayor o igual a 0';
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_isEditing) ...[
                      TextFormField(
                        controller: _stockInicialController,
                        decoration: const InputDecoration(labelText: 'Stock inicial'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final parsed = int.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed < 0) {
                            return 'Debe ser un número entero mayor o igual a 0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _stockMinimoController,
                      decoration: const InputDecoration(labelText: 'Stock mínimo'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final parsed = int.tryParse(value?.trim() ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Debe ser un número entero mayor o igual a 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _save,
                      child: Text(_isEditing ? 'Guardar Cambios' : 'Crear Producto'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
