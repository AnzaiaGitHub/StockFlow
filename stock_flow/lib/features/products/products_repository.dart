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

  static String _normalizeSku(String sku) => sku.trim().toUpperCase();

  static void _requireNonNegative(int value, String name) {
    if (value < 0) {
      throw ArgumentError.value(value, name, 'Debe ser mayor o igual que 0');
    }
  }
}
