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

  test('crea un producto sin stock inicial y no registra movimientos', () async {
    final id = await repository.createProduct(sku: 'AB-1', nombre: 'Café');

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();

    expect(product.sku, 'AB-1');
    expect(product.nombre, 'Café');
    expect(product.stock, 0);
    expect(await db.select(db.stockMovements).get(), isEmpty);
  });

  test('con stock inicial registra el movimiento en la misma transacción', () async {
    final id = await repository.createProduct(
      sku: 'AB-2',
      nombre: 'Té',
      stockInicial: 10,
    );

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 10);

    final movement = await db.select(db.stockMovements).getSingle();
    expect(movement.productId, id);
    expect(movement.tipo, MovementType.entrada);
    expect(movement.motivo, MovementReason.stockInicial);
    expect(movement.cantidad, 10);
  });

  test('normaliza el SKU con trim y mayúsculas', () async {
    final id = await repository.createProduct(sku: ' ab-1 ', nombre: 'Café');

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.sku, 'AB-1');
  });

  test('` ab-1 ` equivale a AB-1 para la unicidad', () async {
    await repository.createProduct(sku: ' ab-1 ', nombre: 'Café');

    await expectLater(
      repository.createProduct(sku: 'AB-1', nombre: 'Otro'),
      throwsA(isA<DuplicateSkuException>()),
    );
  });

  test('SKU duplicado lanza DuplicateSkuException sin datos a medias', () async {
    await repository.createProduct(sku: 'AB-3', nombre: 'Café');

    await expectLater(
      repository.createProduct(sku: 'AB-3', nombre: 'Otro', stockInicial: 5),
      throwsA(isA<DuplicateSkuException>()),
    );

    expect(await db.select(db.products).get(), hasLength(1));
    expect(await db.select(db.stockMovements).get(), isEmpty);
  });

  group('validaciones', () {
    test('rechaza un nombre vacío', () async {
      await expectLater(
        repository.createProduct(sku: 'AB-4', nombre: '   '),
        throwsArgumentError,
      );
    });

    test('rechaza un stock inicial negativo', () async {
      await expectLater(
        repository.createProduct(sku: 'AB-5', nombre: 'Café', stockInicial: -1),
        throwsArgumentError,
      );
    });

    test('rechaza un stock mínimo negativo', () async {
      await expectLater(
        repository.createProduct(sku: 'AB-6', nombre: 'Café', stockMinimo: -1),
        throwsArgumentError,
      );
    });

    test('rechaza un precio negativo', () async {
      await expectLater(
        repository.createProduct(
          sku: 'AB-7',
          nombre: 'Café',
          precioCentavos: -1,
        ),
        throwsArgumentError,
      );
    });
  });
}
