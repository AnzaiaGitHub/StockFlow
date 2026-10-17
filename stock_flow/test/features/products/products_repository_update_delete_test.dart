import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/enums.dart';
import 'package:stock_flow/features/products/exceptions.dart';
import 'package:stock_flow/features/products/products_repository.dart';

void main() {
  late AppDatabase db;
  late ProductsRepository repository;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repository = ProductsRepository(db);
  });

  tearDown(() => db.close());

  test('edita un producto correctamente sin cambiar el stock', () async {
    final id = await repository.createProduct(
      sku: 'AB-1',
      nombre: 'Café',
      stockInicial: 5,
    );

    await repository.updateProduct(
      id: id,
      sku: 'AB-1-MOD',
      nombre: 'Café Premium',
      descripcion: 'Excelente',
      precioCentavos: 1500,
      stockMinimo: 2,
    );

    final product = await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.sku, 'AB-1-MOD');
    expect(product.nombre, 'Café Premium');
    expect(product.descripcion, 'Excelente');
    expect(product.precioCentavos, 1500);
    expect(product.stockMinimo, 2);
    expect(product.stock, 5); // Stock unchanged
  });

  test('conservar su propio SKU al editar es válido', () async {
    final id = await repository.createProduct(sku: 'AB-1', nombre: 'Café');

    await expectLater(
      repository.updateProduct(id: id, sku: ' ab-1 ', nombre: 'Café Editado'),
      completes,
    );
  });

  test('usar el SKU de otro producto al editar falla con DuplicateSkuException', () async {
    await repository.createProduct(sku: 'AB-1', nombre: 'Café');
    final id2 = await repository.createProduct(sku: 'AB-2', nombre: 'Té');

    await expectLater(
      repository.updateProduct(id: id2, sku: 'AB-1', nombre: 'Té Modificado'),
      throwsA(isA<DuplicateSkuException>()),
    );
  });

  test('eliminar producto sin movimientos', () async {
    final id = await repository.createProduct(sku: 'AB-1', nombre: 'Café');
    await repository.deleteProduct(id);

    expect(await db.select(db.products).get(), isEmpty);
  });

  test('eliminar producto con solo movimiento de stock inicial borra producto y movimiento', () async {
    final id = await repository.createProduct(sku: 'AB-1', nombre: 'Café', stockInicial: 10);
    await repository.deleteProduct(id);

    expect(await db.select(db.products).get(), isEmpty);
    expect(await db.select(db.stockMovements).get(), isEmpty);
  });

  test('eliminar producto con otros movimientos lanza ProductHasMovementsException', () async {
    final id = await repository.createProduct(sku: 'AB-1', nombre: 'Café', stockInicial: 10);
    // Add another movement
    await db.into(db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: id,
            tipo: MovementType.entrada,
            motivo: MovementReason.compra,
            cantidad: 5,
          ),
        );

    await expectLater(
      repository.deleteProduct(id),
      throwsA(isA<ProductHasMovementsException>()),
    );
    expect(await db.select(db.products).get(), hasLength(1));
  });
}
