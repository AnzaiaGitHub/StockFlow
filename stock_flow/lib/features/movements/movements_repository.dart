import 'package:drift/drift.dart';

import '../../core/database/database.dart';
import '../../core/database/enums.dart';
import '../products/exceptions.dart';

class MovementsRepository {
  MovementsRepository(this._db);

  final AppDatabase _db;

  Future<int> registerMovement({
    required int productId,
    required MovementType tipo,
    required MovementReason motivo,
    required int cantidad,
  }) async {
    if (cantidad <= 0) {
      throw ArgumentError.value(cantidad, 'cantidad', 'Debe ser mayor que 0');
    }

    if (!motivo.supports(tipo)) {
      throw InvalidMovementException('El motivo ${motivo.label} no es compatible con el tipo ${tipo.name}');
    }

    if (motivo.systemOnly) {
      throw InvalidMovementException('El motivo ${motivo.label} solo puede ser generado por el sistema');
    }

    return _db.transaction(() async {
      final product = await (_db.select(_db.products)
            ..where((p) => p.id.equals(productId))
            ..limit(1))
          .getSingleOrNull();

      if (product == null) {
        throw ProductNotFoundException(productId);
      }

      int newStock = product.stock;
      if (tipo == MovementType.entrada) {
        newStock += cantidad;
      } else {
        if (product.stock < cantidad) {
          throw InsufficientStockException(productId, product.stock, cantidad);
        }
        newStock -= cantidad;
      }

      // Update product stock
      await (_db.update(_db.products)..where((p) => p.id.equals(productId))).write(
        ProductsCompanion(stock: Value(newStock)),
      );

      // Insert movement
      final movementId = await _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: productId,
              tipo: tipo,
              motivo: motivo,
              cantidad: cantidad,
            ),
          );

      return movementId;
    });
  }
}
