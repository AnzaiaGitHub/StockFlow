import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/enums.dart';
import 'package:stock_flow/features/movements/movements_repository.dart';
import 'package:stock_flow/features/products/exceptions.dart';
import 'package:stock_flow/features/products/products_repository.dart';

void main() {
  late AppDatabase db;
  late ProductsRepository productsRepository;
  late MovementsRepository movementsRepository;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    productsRepository = ProductsRepository(db);
    movementsRepository = MovementsRepository(db);
  });

  tearDown(() => db.close());

  test('entrada suma stock y registra movimiento', () async {
    final id = await productsRepository.createProduct(sku: 'AB-1', nombre: 'Café', stockInicial: 10);

    await movementsRepository.registerMovement(
      productId: id,
      tipo: MovementType.entrada,
      motivo: MovementReason.compra,
      cantidad: 5,
    );

    final product = await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 15);

    final movements = await db.select(db.stockMovements).get();
    expect(movements, hasLength(2)); // stockInicial + compra
    expect(movements.last.tipo, MovementType.entrada);
    expect(movements.last.motivo, MovementReason.compra);
    expect(movements.last.cantidad, 5);
  });

  test('salida resta stock y salida hasta 0 es válida', () async {
    final id = await productsRepository.createProduct(sku: 'AB-1', nombre: 'Café', stockInicial: 10);

    await movementsRepository.registerMovement(
      productId: id,
      tipo: MovementType.salida,
      motivo: MovementReason.venta,
      cantidad: 10,
    );

    final product = await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 0);
  });

  test('salida mayor que el stock lanza InsufficientStockException sin cambios', () async {
    final id = await productsRepository.createProduct(sku: 'AB-1', nombre: 'Café', stockInicial: 5);

    await expectLater(
      movementsRepository.registerMovement(
        productId: id,
        tipo: MovementType.salida,
        motivo: MovementReason.venta,
        cantidad: 6,
      ),
      throwsA(isA<InsufficientStockException>()),
    );

    final product = await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 5);
    expect(await db.select(db.stockMovements).get(), hasLength(1)); // only stockInicial
  });

  test('producto inexistente revierte todo o lanza ProductNotFoundException', () async {
    await expectLater(
      movementsRepository.registerMovement(
        productId: 999,
        tipo: MovementType.entrada,
        motivo: MovementReason.compra,
        cantidad: 5,
      ),
      throwsA(isA<ProductNotFoundException>()),
    );
  });
}
