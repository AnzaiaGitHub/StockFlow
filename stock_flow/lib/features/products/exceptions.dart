class DuplicateSkuException implements Exception {
  DuplicateSkuException(this.sku);

  final String sku;

  @override
  String toString() => 'El SKU "$sku" ya existe';
}
