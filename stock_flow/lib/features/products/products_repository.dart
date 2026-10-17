import 'package:drift/drift.dart';

import '../../core/database/database.dart';
import '../../core/database/enums.dart';
import 'exceptions.dart';

class ProductsRepository {
  ProductsRepository(this._db);

  final AppDatabase _db;

  Future<int> createProduct({
    required String sku,
    required String nombre,
    String? descripcion,
    int? precioCentavos,
    int stockInicial = 0,
    int stockMinimo = 0,
  }) async {
    final normalizedSku = _normalizeSku(sku);
    final cleanNombre = nombre.trim();

    if (cleanNombre.isEmpty) {
      throw ArgumentError.value(nombre, 'nombre', 'El nombre es obligatorio');
    }
    _requireNonNegative(stockInicial, 'stockInicial');
    _requireNonNegative(stockMinimo, 'stockMinimo');
    if (precioCentavos != null) {
      _requireNonNegative(precioCentavos, 'precioCentavos');
    }

    return _db.transaction(() async {
      final existing = await (_db.select(_db.products)
            ..where((product) => product.sku.equals(normalizedSku))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) {
        throw DuplicateSkuException(normalizedSku);
      }

      final id = await _db.into(_db.products).insert(
            ProductsCompanion.insert(
              sku: normalizedSku,
              nombre: cleanNombre,
              descripcion: Value(descripcion),
              precioCentavos: Value(precioCentavos),
              stock: Value(stockInicial),
              stockMinimo: Value(stockMinimo),
            ),
          );

      if (stockInicial > 0) {
        await _db.into(_db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: id,
                tipo: MovementType.entrada,
                motivo: MovementReason.stockInicial,
                cantidad: stockInicial,
              ),
            );
      }

      return id;
    });
  }

  Future<void> updateProduct({
    required int id,
    required String sku,
    required String nombre,
    String? descripcion,
    int? precioCentavos,
    int? stockMinimo,
  }) async {
    final normalizedSku = _normalizeSku(sku);
    final cleanNombre = nombre.trim();

    if (cleanNombre.isEmpty) {
      throw ArgumentError.value(nombre, 'nombre', 'El nombre es obligatorio');
    }
    if (stockMinimo != null) {
      _requireNonNegative(stockMinimo, 'stockMinimo');
    }
    if (precioCentavos != null) {
      _requireNonNegative(precioCentavos, 'precioCentavos');
    }

    return _db.transaction(() async {
      final existingProduct = await (_db.select(_db.products)
            ..where((p) => p.id.equals(id))
            ..limit(1))
          .getSingleOrNull();

      if (existingProduct == null) {
        throw ProductNotFoundException(id);
      }

      // Check if another product already has this SKU
      final skuOwner = await (_db.select(_db.products)
            ..where((p) => p.sku.equals(normalizedSku) & p.id.isNotValue(id))
            ..limit(1))
          .getSingleOrNull();

      if (skuOwner != null) {
        throw DuplicateSkuException(normalizedSku);
      }

      await (_db.update(_db.products)..where((p) => p.id.equals(id))).write(
        ProductsCompanion(
          sku: Value(normalizedSku),
          nombre: Value(cleanNombre),
          descripcion: Value(descripcion),
          precioCentavos: Value(precioCentavos),
          stockMinimo: stockMinimo != null ? Value(stockMinimo) : const Value.absent(),
        ),
      );
    });
  }

  Future<void> deleteProduct(int id) async {
    return _db.transaction(() async {
      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(id))
            ..limit(1))
          .getSingleOrNull();

      if (product == null) {
        throw ProductNotFoundException(id);
      }

      final movements = await (_db.select(_db.stockMovements)
            ..where((m) => m.productId.equals(id)))
          .get();

      // Rule: Can delete if no movements, or only 1 movement which is stockInicial
      if (movements.isNotEmpty) {
        if (movements.length > 1 || movements.first.motivo != MovementReason.stockInicial) {
          throw ProductHasMovementsException(id);
        }
      }

      // Delete movements if any (stockInicial)
      if (movements.isNotEmpty) {
        await (_db.delete(_db.stockMovements)..where((m) => m.productId.equals(id))).go();
      }

      // Delete product
      await (_db.delete(_db.products)..where((p) => p.id.equals(id))).go();
    });
  }


  static String _normalizeSku(String sku) => sku.trim().toUpperCase();

  static void _requireNonNegative(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'Debe ser mayor o igual que 0');
    }
  }
}
