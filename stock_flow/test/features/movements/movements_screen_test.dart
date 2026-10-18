import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/core/database/enums.dart';
import 'package:stock_flow/features/movements/movements_repository.dart';
import 'package:stock_flow/features/movements/movements_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MovementsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Muestra estado vacío cuando no hay movimientos', (tester) async {
    await pumpScreen(tester);

    expect(find.text('No hay movimientos registrados'), findsOneWidget);
  });

  testWidgets('Muestra producto, cantidad con signo y motivo', (tester) async {
    final id = await productsRepository.createProduct(
      sku: 'MAN-1',
      nombre: 'Manzana',
      stockInicial: 10,
    );
    await movementsRepository.registerMovement(
      productId: id,
      tipo: MovementType.salida,
      motivo: MovementReason.venta,
      cantidad: 4,
    );

    await pumpScreen(tester);

    expect(
      find.descendant(of: find.byType(ListView), matching: find.text('Manzana')),
      findsNWidgets(2), // stock inicial + venta
    );
    expect(find.text('+10'), findsOneWidget); // stock inicial
    expect(find.text('-4'), findsOneWidget); // venta
    expect(find.textContaining('Stock inicial'), findsOneWidget);
    expect(find.textContaining('Venta'), findsOneWidget);
  });

  testWidgets('Filtra los movimientos por producto', (tester) async {
    final manzana = await productsRepository.createProduct(
      sku: 'MAN-1',
      nombre: 'Manzana',
      stockInicial: 10,
    );
    await productsRepository.createProduct(
      sku: 'ZAN-1',
      nombre: 'Zanahoria',
      stockInicial: 20,
    );
    await movementsRepository.registerMovement(
      productId: manzana,
      tipo: MovementType.salida,
      motivo: MovementReason.venta,
      cantidad: 4,
    );

    await pumpScreen(tester);

    // Sin filtro se ven ambos productos
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);

    // Abrir el desplegable de filtro y seleccionar Manzana
    await tester.tap(find.byKey(const Key('productFilterDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manzana').last);
    await tester.pumpAndSettle();

    // Solo se ven los movimientos de Manzana
    expect(find.text('+10'), findsOneWidget);
    expect(find.text('-4'), findsOneWidget);
    expect(find.text('+20'), findsNothing);
  });
}
