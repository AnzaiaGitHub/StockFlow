import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/enums.dart';
import 'package:stock_flow/features/dashboard/inventory_queries_repository.dart';
import 'package:stock_flow/features/movements/movements_repository.dart';
import 'package:stock_flow/features/products/products_repository.dart';

void main() {
  late AppDatabase db;
  late ProductsRepository productsRepository;
  late MovementsRepository movementsRepository;
  late InventoryQueriesRepository queriesRepository;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    productsRepository = ProductsRepository(db);
    movementsRepository = MovementsRepository(db);
    queriesRepository = InventoryQueriesRepository(db);
  });

  tearDown(() => db.close());

  test('watchProducts emite productos ordenados por nombre', () async {
    await productsRepository.createProduct(sku: 'B', nombre: 'Zanahoria');
    await productsRepository.createProduct(sku: 'A', nombre: 'Manzana');

    final products = await queriesRepository.watchProducts().first;
    expect(products, hasLength(2));
    expect(products[0].nombre, 'Manzana');
    expect(products[1].nombre, 'Zanahoria');
  });

  test('watchMovements emite movimientos descendentes con producto relacionado', () async {
    final id = await productsRepository.createProduct(sku: 'A', nombre: 'Manzana', stockInicial: 10);
    await movementsRepository.registerMovement(
      productId: id,
      tipo: MovementType.entrada,
      motivo: MovementReason.compra,
      cantidad: 5,
    );

    final movementsWithProduct = await queriesRepository.watchMovements().first;
    expect(movementsWithProduct, hasLength(2));
    expect(movementsWithProduct[0].movement.cantidad, 5); // Compra first (desc fecha)
    expect(movementsWithProduct[1].movement.cantidad, 10); // stockInicial second
    expect(movementsWithProduct[0].product.nombre, 'Manzana');
  });

  test('dashboard summary calcula total, stock bajo y valor ignorando productos sin precio', () async {
    // Product 1: stock 2 <= min 5 (low stock), price 100 -> value 200
    await productsRepository.createProduct(
      sku: 'P1',
      nombre: 'Prod 1',
      stockInicial: 2,
      stockMinimo: 5,
      precioCentavos: 100,
    );

    // Product 2: stock 10 > min 2, no price -> value 0, low stock false
    await productsRepository.createProduct(
      sku: 'P2',
      nombre: 'Prod 2',
      stockInicial: 10,
      stockMinimo: 2,
    );

    final summary = await queriesRepository.watchDashboardSummary().first;
    expect(summary.totalProducts, 2);
    expect(summary.lowStockProducts, 1);
    expect(summary.totalValueCentavos, 200); // 2 * 100 + (10 * 0)
  });
}
