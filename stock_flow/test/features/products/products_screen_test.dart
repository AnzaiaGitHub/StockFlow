import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/features/products/products_repository.dart';
import 'package:stock_flow/features/products/products_screen.dart';

void main() {
  testWidgets('Muestra estado vacío cuando no hay productos', (tester) async {
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
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No hay productos registrados'), findsOneWidget);
  });

  testWidgets('Muestra lista de productos e indicador de stock bajo', (tester) async {
    final memoryDb = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(memoryDb.close);

    final repo = ProductsRepository(memoryDb);
    await repo.createProduct(sku: 'SKU-1', nombre: 'Manzana', stockInicial: 2, stockMinimo: 5);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
        ],
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );

    // Let stream load
    await tester.pumpAndSettle();

    expect(find.text('Manzana'), findsOneWidget);
    expect(find.text('SKU: SKU-1'), findsOneWidget);
    expect(find.text('Stock: 2'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('Al tocar un producto abre el detalle', (tester) async {
    final memoryDb = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    addTearDown(memoryDb.close);

    final repo = ProductsRepository(memoryDb);
    await repo.createProduct(sku: 'SKU-1', nombre: 'Manzana');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(memoryDb),
        ],
        child: const MaterialApp(home: ProductsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('Manzana'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de producto'), findsOneWidget);
  });
}
