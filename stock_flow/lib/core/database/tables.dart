import 'package:drift/drift.dart';

import 'enums.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text().unique()();
  TextColumn get nombre => text()();
  TextColumn get descripcion => text().nullable()();
  IntColumn get precioCentavos => integer()
      .nullable()
      // ignore: recursive_getters
      .check(precioCentavos.isBiggerOrEqualValue(0))();
  IntColumn get stock => integer()
      .withDefault(const Constant(0))
      // ignore: recursive_getters
      .check(stock.isBiggerOrEqualValue(0))();
  IntColumn get stockMinimo => integer()
      .withDefault(const Constant(0))
      // ignore: recursive_getters
      .check(stockMinimo.isBiggerOrEqualValue(0))();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  TextColumn get tipo => textEnum<MovementType>()();
  TextColumn get motivo => textEnum<MovementReason>()();
  IntColumn get cantidad => integer()
      // ignore: recursive_getters
      .check(cantidad.isBiggerThanValue(0))();
  DateTimeColumn get fecha => dateTime().withDefault(currentDateAndTime)();

  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT',
  ];
}
