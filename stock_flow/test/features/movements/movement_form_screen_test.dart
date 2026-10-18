import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/core/database/enums.dart';
import 'package:stock_flow/features/movements/movement_form_screen.dart';
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

  Future<void> pumpForm(
    WidgetTester tester,
    int productId,
    MovementType tipo,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MovementFormScreen(
                        productId: productId,
                        tipo: tipo,
                      ),
                    ),
                  ),
                  child: const Text('Abrir formulario'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
  }

  testWidgets('El motivo se filtra según el tipo (entrada)', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 10,
    );

    await pumpForm(tester, id, MovementType.entrada);

    await tester.tap(find.byKey(const Key('motivoDropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Compra'), findsWidgets);
    expect(find.text('Devolución'), findsOneWidget);
    expect(find.text('Ajuste'), findsOneWidget);
    expect(find.text('Venta'), findsNothing);
    expect(find.text('Merma'), findsNothing);
  });

  testWidgets('El motivo se filtra según el tipo (salida)', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 10,
    );

    await pumpForm(tester, id, MovementType.salida);

    await tester.tap(find.byKey(const Key('motivoDropdown')));
    await tester.pumpAndSettle();

    expect(find.text('Venta'), findsWidgets);
    expect(find.text('Merma'), findsOneWidget);
    expect(find.text('Ajuste'), findsWidgets);
    expect(find.text('Compra'), findsNothing);
    expect(find.text('Devolución'), findsNothing);
  });

  testWidgets('Registrar una entrada suma al stock', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 10,
    );

    await pumpForm(tester, id, MovementType.entrada);

    await tester.enterText(find.byType(TextFormField), '5');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 15);

    final movements = await (db.select(db.stockMovements)
          ..where((m) => m.productId.equals(id)))
        .get();
    expect(movements, hasLength(2));
  });

  testWidgets('Registrar una salida resta del stock', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 10,
    );

    await pumpForm(tester, id, MovementType.salida);

    await tester.enterText(find.byType(TextFormField), '4');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 6);
  });

  testWidgets('Una cantidad inválida no guarda', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 10,
    );

    await pumpForm(tester, id, MovementType.entrada);

    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(find.text('Debe ser un número entero mayor que 0'), findsOneWidget);

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 10);
  });

  testWidgets('Una salida excesiva muestra "Stock disponible" y no guarda',
      (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 5,
    );

    await pumpForm(tester, id, MovementType.salida);

    await tester.enterText(find.byType(TextFormField), '6');
    await tester.tap(find.text('Registrar'));
    await tester.pumpAndSettle();

    expect(find.text('Stock disponible: 5'), findsOneWidget);

    final product =
        await (db.select(db.products)..where((p) => p.id.equals(id))).getSingle();
    expect(product.stock, 5);
    final movements = await (db.select(db.stockMovements)
          ..where((m) => m.productId.equals(id)))
        .get();
    expect(movements, hasLength(1)); // only stock inicial
  });
}
