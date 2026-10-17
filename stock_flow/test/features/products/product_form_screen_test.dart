import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/features/products/product_form_screen.dart';
import 'package:stock_flow/features/products/products_repository.dart';

void main() {
  testWidgets('Formulario muestra validaciones en español y rechaza datos inválidos', (tester) async {
    final memoryDb = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(memoryDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );

    // Tap submit without filling required fields
    await tester.tap(find.text('Crear Producto'));
    await tester.pumpAndSettle();

    expect(find.text('El SKU is obligatorio'), findsNothing); // wait, let's check exact string
    expect(find.text('El SKU es obligatorio'), findsOneWidget);
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
  });

  testWidgets('Crea producto exitosamente con precio decimal convertido y stock inicial', (tester) async {
    final memoryDb = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(memoryDb.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );

    // Fill form
    await tester.enterText(find.byType(TextFormField).at(0), 'abc-123'); // SKU
    await tester.enterText(find.byType(TextFormField).at(1), 'Laptop'); // Nombre
    await tester.enterText(find.byType(TextFormField).at(3), '1234.56'); // Precio
    await tester.enterText(find.byType(TextFormField).at(4), '10'); // Stock inicial
    await tester.enterText(find.byType(TextFormField).at(5), '2'); // Stock mínimo

    await tester.tap(find.text('Crear Producto'));
    await tester.pumpAndSettle();

    final repo = ProductsRepository(memoryDb);
    final products = await memoryDb.select(memoryDb.products).get();
    expect(products.length, 1);
    expect(products.first.sku, 'ABC-123');
    expect(products.first.nombre, 'Laptop');
    expect(products.first.precioCentavos, 123456);
    expect(products.first.stock, 10);
    expect(products.first.stockMinimo, 2);
  });

  testWidgets('Muestra error de SKU duplicado bajo el campo correspondiente', (tester) async {
    final memoryDb = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(memoryDb.close);

    final repo = ProductsRepository(memoryDb);
    await repo.createProduct(sku: 'EXISTING', nombre: 'Existente');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
        ],
        child: const MaterialApp(home: ProductFormScreen()),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'EXISTING');
    await tester.enterText(find.byType(TextFormField).at(1), 'Nuevo Producto');

    await tester.tap(find.text('Crear Producto'));
    await tester.pumpAndSettle();

    expect(find.text('Este SKU ya está registrado'), findsOneWidget);
  });
}
