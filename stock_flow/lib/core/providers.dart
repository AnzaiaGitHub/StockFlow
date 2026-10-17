import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/database.dart';
import '../core/database/database_provider.dart';
import '../features/dashboard/inventory_queries_repository.dart';
import '../features/movements/movements_repository.dart';
import '../features/products/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ProductsRepository(db);
});

final movementsRepositoryProvider = Provider<MovementsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return MovementsRepository(db);
});

final inventoryQueriesRepositoryProvider = Provider<InventoryQueriesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return InventoryQueriesRepository(db);
});

final productsStreamProvider = StreamProvider.autoDispose<List<Product>>((ref) {
  final queries = ref.watch(inventoryQueriesRepositoryProvider);
  return queries.watchProducts();
});

final movementsStreamProvider = StreamProvider.autoDispose.family<List<MovementWithProduct>, int?>((ref, productId) {
  final queries = ref.watch(inventoryQueriesRepositoryProvider);
  return queries.watchMovements(productId: productId);
});

final dashboardSummaryStreamProvider = StreamProvider.autoDispose<DashboardSummary>((ref) {
  final queries = ref.watch(inventoryQueriesRepositoryProvider);
  return queries.watchDashboardSummary();
});
