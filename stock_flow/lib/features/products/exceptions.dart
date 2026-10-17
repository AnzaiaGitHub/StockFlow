class DuplicateSkuException implements Exception {
  DuplicateSkuException(this.sku);

  final String sku;

  @override
  String toString() => 'El SKU "$sku" ya existe';
}

class ProductNotFoundException implements Exception {
  ProductNotFoundException(this.id);

  final int id;

  @override
  String toString() => 'El producto con ID $id no existe';
}

class ProductHasMovementsException implements Exception {
  ProductHasMovementsException(this.id);

  final int id;

  @override
  String toString() => 'El producto tiene movimientos y no se puede eliminar';
}

class InsufficientStockException implements Exception {
  InsufficientStockException(this.productId, this.disponible, this.solicitado);

  final int productId;
  final int disponible;
  final int solicitado;

  @override
  String toString() => 'Stock insuficiente. Disponible: $disponible, solicitado: $solicitado';
}

class InvalidMovementException implements Exception {
  InvalidMovementException(this.message);

  final String message;

  @override
  String toString() => message;
}

