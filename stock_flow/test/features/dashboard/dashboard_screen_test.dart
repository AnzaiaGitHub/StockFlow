import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/features/dashboard/dashboard_screen.dart';
import 'package:stock_flow/features/products/products_repository.dart';

void main() {
  late AppDatabase db;
  late ProductsRepository productsRepository;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    productsRepository = ProductsRepository(db);
  });

  tearDown(() => db.close());

  Future<void> pumpDashboard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? valueOf(WidgetTester tester, Key key) =>
      tester.widget<Text>(find.byKey(key)).data;

  testWidgets('Muestra ceros y estado sin stock bajo cuando no hay productos',
      (tester) async {
    await pumpDashboard(tester);

    expect(valueOf(tester, const Key('totalProductsValue')), '0');
    expect(valueOf(tester, const Key('lowStockValue')), '0');
    expect(valueOf(tester, const Key('inventoryValue')), r'$0.00');
    expect(find.text('Sin productos con stock bajo'), findsOneWidget);
    expect(find.text('Excluye los productos sin precio'), findsOneWidget);
  });

  testWidgets('Muestra totales, valor y lista de stock bajo', (tester) async {
    await productsRepository.createProduct(
      sku: 'MAN-1',
      nombre: 'Manzana',
      stockInicial: 2,
      stockMinimo: 5,
      precioCentavos: 100,
    );
    await productsRepository.createProduct(
      sku: 'ZAN-1',
      nombre: 'Zanahoria',
      stockInicial: 10,
      stockMinimo: 2,
    );

    await pumpDashboard(tester);

    expect(valueOf(tester, const Key('totalProductsValue')), '2');
    expect(valueOf(tester, const Key('lowStockValue')), '1');
    // 2 * 100 = 200 centavos -> $2.00 (Zanahoria no tiene precio)
    expect(valueOf(tester, const Key('inventoryValue')), r'$2.00');

    expect(find.text('Manzana'), findsOneWidget);
    expect(find.text('Zanahoria'), findsNothing);
  });

  testWidgets('El valor del inventario ignora los productos sin precio',
      (tester) async {
    await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Con precio',
      stockInicial: 3,
      precioCentavos: 500,
    );
    await productsRepository.createProduct(
      sku: 'B-1',
      nombre: 'Sin precio',
      stockInicial: 100,
    );

    await pumpDashboard(tester);

    expect(valueOf(tester, const Key('inventoryValue')), r'$15.00');
  });

  testWidgets('Al tocar un producto de stock bajo abre el detalle',
      (tester) async {
    await productsRepository.createProduct(
      sku: 'MAN-1',
      nombre: 'Manzana',
      stockInicial: 2,
      stockMinimo: 5,
    );

    await pumpDashboard(tester);

    await tester.tap(find.text('Manzana'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de producto'), findsOneWidget);
    expect(find.text('MAN-1'), findsOneWidget);
  });
}
