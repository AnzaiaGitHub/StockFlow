import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/enums.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
  });

  tearDown(() => db.close());

  test('inserta y lee un producto en memoria', () async {
    await db.into(db.products).insert(
      ProductsCompanion.insert(
        sku: 'AB-1',
        nombre: 'Café',
        stock: const Value(5),
      ),
    );

    final products = await db.select(db.products).get();

    expect(products, hasLength(1));
    expect(products.single.sku, 'AB-1');
    expect(products.single.nombre, 'Café');
    expect(products.single.stock, 5);
  });

  group('restricciones', () {
    test('sku es único', () async {
      await db
          .into(db.products)
          .insert(ProductsCompanion.insert(sku: 'AB-1', nombre: 'A'));

      await expectLater(
        db
            .into(db.products)
            .insert(ProductsCompanion.insert(sku: 'AB-1', nombre: 'B')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('stock no admite negativos', () async {
      await expectLater(
        db.into(db.products).insert(
              ProductsCompanion.insert(
                sku: 'AB-2',
                nombre: 'A',
                stock: const Value(-1),
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('cantidad debe ser mayor que cero', () async {
      final id = await db
          .into(db.products)
          .insert(ProductsCompanion.insert(sku: 'AB-3', nombre: 'A'));

      await expectLater(
        db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: id,
                tipo: MovementType.entrada,
                motivo: MovementReason.compra,
                cantidad: 0,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('product_id debe referenciar un producto existente', () async {
      await expectLater(
        db.into(db.stockMovements).insert(
              StockMovementsCompanion.insert(
                productId: 999,
                tipo: MovementType.entrada,
                motivo: MovementReason.compra,
                cantidad: 1,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('no se puede eliminar un producto con movimientos', () async {
      final id = await db
          .into(db.products)
          .insert(ProductsCompanion.insert(sku: 'AB-4', nombre: 'A'));
      await db.into(db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: id,
              tipo: MovementType.entrada,
              motivo: MovementReason.compra,
              cantidad: 1,
            ),
          );

      await expectLater(
        (db.delete(db.products)..where((p) => p.id.equals(id))).go(),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
