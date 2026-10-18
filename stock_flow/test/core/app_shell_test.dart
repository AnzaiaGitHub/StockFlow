import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/app.dart';
import 'package:stock_flow/core/database/database.dart';
import 'package:stock_flow/core/database/database_provider.dart';
import 'package:stock_flow/features/dashboard/dashboard_screen.dart';
import 'package:stock_flow/features/movements/movements_screen.dart';
import 'package:stock_flow/features/products/products_screen.dart';

Finder navLabel(String label) => find.descendant(
  of: find.byType(NavigationBar),
  matching: find.text(label),
);

AppDatabase _memoryDb() {
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

void main() {
  testWidgets('muestra las tres pestañas con Dashboard por defecto', (
    tester,
  ) async {
    final db = _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      StockFlowApp(overrides: [databaseProvider.overrideWithValue(db)]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
  });

  testWidgets('cambiar de pestaña actualiza el título y conserva el estado', (
    tester,
  ) async {
    final db = _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(
      StockFlowApp(overrides: [databaseProvider.overrideWithValue(db)]),
    );
    await tester.pumpAndSettle();

    await tester.tap(navLabel('Productos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Productos'), findsOneWidget);

    await tester.tap(navLabel('Movimientos'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Movimientos'), findsOneWidget);

    expect(find.byType(DashboardScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(ProductsScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(MovementsScreen, skipOffstage: false), findsOneWidget);
  });
}
