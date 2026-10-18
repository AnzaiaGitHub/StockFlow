import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/core/database/enums.dart';
import 'package:stock_flow/features/movements/movements_repository.dart';
import 'package:stock_flow/features/products/product_detail_screen.dart';
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

  Future<void> pumpDetail(WidgetTester tester, int productId) async {
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
                      builder: (_) => ProductDetailScreen(productId: productId),
                    ),
                  ),
                  child: const Text('Abrir detalle'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();
  }

  testWidgets('Muestra datos, stock y botones de acción', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'man-1',
      nombre: 'Manzana',
      descripcion: 'Fruta roja',
      precioCentavos: 1250,
      stockInicial: 2,
      stockMinimo: 5,
    );

    await pumpDetail(tester, id);

    expect(find.text('Manzana'), findsOneWidget);
    expect(find.text('MAN-1'), findsOneWidget);
    expect(find.text('Fruta roja'), findsOneWidget);
    expect(find.text('Stock bajo'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Entrada'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Salida'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Editar'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Eliminar'), findsOneWidget);
  });

  testWidgets('Entrada abre el formulario de movimiento', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 5,
    );

    await pumpDetail(tester, id);

    await tester.tap(find.widgetWithText(FilledButton, 'Entrada'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar entrada'), findsOneWidget);
  });

  testWidgets('Salida abre el formulario de movimiento', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 5,
    );

    await pumpDetail(tester, id);

    await tester.tap(find.widgetWithText(FilledButton, 'Salida'));
    await tester.pumpAndSettle();

    expect(find.text('Registrar salida'), findsOneWidget);
  });

  testWidgets('Editar abre el formulario con los datos del producto',
      (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
    );

    await pumpDetail(tester, id);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Editar'));
    await tester.pumpAndSettle();

    expect(find.text('Editar Producto'), findsOneWidget);
    expect(find.text('Producto A'), findsOneWidget);
  });

  testWidgets('Eliminar pide confirmación y cancelar no borra', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
    );

    await pumpDetail(tester, id);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminar producto'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    final products = await db.select(db.products).get();
    expect(products, hasLength(1));
    expect(find.text('Producto A'), findsOneWidget);
  });

  testWidgets('Eliminar un producto sin historial lo borra y cierra el detalle',
      (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
    );

    await pumpDetail(tester, id);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Eliminar'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Eliminar'),
      ),
    );
    await tester.pumpAndSettle();

    final products = await db.select(db.products).get();
    expect(products, isEmpty);
    expect(find.text('Abrir detalle'), findsOneWidget);
  });

  testWidgets('Eliminar un producto con movimientos explica por qué no se puede',
      (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 5,
    );
    final movementsRepository = MovementsRepository(db);
    await movementsRepository.registerMovement(
      productId: id,
      tipo: MovementType.salida,
      motivo: MovementReason.venta,
      cantidad: 2,
    );

    await pumpDetail(tester, id);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Eliminar'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Eliminar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se puede eliminar'), findsOneWidget);
    expect(find.textContaining('movimientos registrados'), findsOneWidget);

    final products = await db.select(db.products).get();
    expect(products, hasLength(1));
  });

  testWidgets('Muestra los últimos movimientos del producto', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'A-1',
      nombre: 'Producto A',
      stockInicial: 5,
    );
    final movementsRepository = MovementsRepository(db);
    await movementsRepository.registerMovement(
      productId: id,
      tipo: MovementType.entrada,
      motivo: MovementReason.compra,
      cantidad: 3,
    );

    await pumpDetail(tester, id);

    expect(find.textContaining('+5 · Stock inicial'), findsOneWidget);
    expect(find.textContaining('+3 · Compra'), findsOneWidget);
  });
}
