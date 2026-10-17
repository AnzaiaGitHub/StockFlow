import 'package:flutter_test/flutter_test.dart';
import 'package:stock_flow/core/database/enums.dart';

void main() {
  group('MovementReason', () {
    test('cada motivo declara al menos un tipo compatible', () {
      for (final reason in MovementReason.values) {
        expect(reason.types, isNotEmpty, reason: reason.name);
      }
    });

    test('la correspondencia motivo-tipo coincide con el backlog', () {
      expect(MovementReason.stockInicial.types, {MovementType.entrada});
      expect(MovementReason.compra.types, {MovementType.entrada});
      expect(MovementReason.devolucion.types, {MovementType.entrada});
      expect(MovementReason.ajuste.types, {
        MovementType.entrada,
        MovementType.salida,
      });
      expect(MovementReason.venta.types, {MovementType.salida});
      expect(MovementReason.merma.types, {MovementType.salida});
    });

    test('solo stockInicial es exclusivo del sistema', () {
      final systemOnly = MovementReason.values
          .where((reason) => reason.systemOnly)
          .toSet();

      expect(systemOnly, {MovementReason.stockInicial});
    });

    test('supports refleja la correspondencia', () {
      expect(MovementReason.ajuste.supports(MovementType.entrada), isTrue);
      expect(MovementReason.ajuste.supports(MovementType.salida), isTrue);
      expect(MovementReason.venta.supports(MovementType.entrada), isFalse);
      expect(MovementReason.compra.supports(MovementType.salida), isFalse);
    });
  });
}
