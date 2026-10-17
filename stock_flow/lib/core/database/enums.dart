enum MovementType { entrada, salida }

enum MovementReason {
  stockInicial('Stock inicial', {MovementType.entrada}, systemOnly: true),
  compra('Compra', {MovementType.entrada}),
  devolucion('Devolución', {MovementType.entrada}),
  ajuste('Ajuste', {MovementType.entrada, MovementType.salida}),
  venta('Venta', {MovementType.salida}),
  merma('Merma', {MovementType.salida});

  const MovementReason(this.label, this.types, {this.systemOnly = false});

  final String label;
  final Set<MovementType> types;
  final bool systemOnly;

  bool supports(MovementType type) => types.contains(type);
}
