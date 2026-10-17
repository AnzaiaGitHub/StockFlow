import 'package:drift/drift.dart';

import '../../core/database/database.dart';

class InventoryQueriesRepository {
  InventoryQueriesRepository(this._db);

  final AppDatabase _db;

  Stream<List<Product>> watchProducts() {
    return (_db.select(_db.products)
          ..orderBy([(p) => OrderingTerm.asc(p.nombre)]))
        .watch();
  }

  Stream<List<MovementWithProduct>> watchMovements({int? productId}) {
    final query = _db.select(_db.stockMovements).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.stockMovements.productId)),
    ])
      ..orderBy([OrderingTerm.desc(_db.stockMovements.id)]);


    if (productId != null) {
      query.where(_db.stockMovements.productId.equals(productId));
    }

    return query.watch().map((rows) {
      return rows.map((row) {
        return MovementWithProduct(
          movement: row.readTable(_db.stockMovements),
          product: row.readTable(_db.products),
        );
      }).toList();
    });
  }

  Stream<DashboardSummary> watchDashboardSummary() {
    return _db.select(_db.products).watch().asyncMap((products) async {
      final totalProducts = products.length;
      final lowStockProducts = products.where((p) => p.stock <= p.stockMinimo).length;

      int totalValueCentavos = 0;
      for (final p in products) {
        if (p.precioCentavos != null) {
          totalValueCentavos += p.stock * p.precioCentavos!;
        }
      }

      return DashboardSummary(
        totalProducts: totalProducts,
        lowStockProducts: lowStockProducts,
        totalValueCentavos: totalValueCentavos,
      );
    });
  }
}

class MovementWithProduct {
  MovementWithProduct({
    required this.movement,
    required this.product,
  });

  final StockMovement movement;
  final Product product;
}

class DashboardSummary {
  DashboardSummary({
    required this.totalProducts,
    required this.lowStockProducts,
    required this.totalValueCentavos,
  });

  final int totalProducts;
  final int lowStockProducts;
  final int totalValueCentavos;
}
