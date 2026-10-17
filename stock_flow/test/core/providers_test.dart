import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/core/providers.dart';

void main() {
  test('providers de Riverpod se pueden sobrescribir y consultar correctamente', () async {
    final memoryDb = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(memoryDb),
      ],
    );

    addTearDown(container.dispose);
    addTearDown(memoryDb.close);

    final productsRepo = container.read(productsRepositoryProvider);
    await productsRepo.createProduct(sku: 'PR-1', nombre: 'Test Prod', stockInicial: 5);

    final products = await container.read(productsStreamProvider.future);
    expect(products, hasLength(1));
    expect(products.first.nombre, 'Test Prod');

    final summary = await container.read(dashboardSummaryStreamProvider.future);
    expect(summary.totalProducts, 1);
    expect(summary.lowStockProducts, 0);
  });
}
