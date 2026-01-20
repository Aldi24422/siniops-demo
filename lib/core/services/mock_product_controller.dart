import 'dart:async';
import '../models/product_model.dart';
import 'preview_mode_controller.dart';

/// Mock Product Controller for Preview Mode
/// All operations are performed in-memory only
class MockProductController {
  final MockDataStore _store = MockDataStore.instance;

  // Stream controller for reactive updates
  final StreamController<List<Product>> _streamController =
      StreamController<List<Product>>.broadcast();

  void _emitProducts() {
    final products = _store.products.map((data) {
      return Product.fromMap(data, data['id'] as String);
    }).toList();
    _streamController.add(products);
  }

  /// Stream of all products ordered by name
  Stream<List<Product>> getProducts() {
    // Use async to emit after stream is subscribed
    Future.microtask(() => _emitProducts());
    return _streamController.stream;
  }

  /// Add a new product
  Future<String> addProduct(Product product) async {
    final id = 'prod_${DateTime.now().millisecondsSinceEpoch}';
    final data = product.toMap();
    data['id'] = id;
    _store.products.add(data);
    _emitProducts();
    return id;
  }

  /// Update an existing product
  Future<void> updateProduct(Product product) async {
    if (product.id == null) {
      throw ArgumentError('Product ID is required for update');
    }
    final index = _store.products.indexWhere((p) => p['id'] == product.id);
    if (index != -1) {
      final data = product.toMap();
      data['id'] = product.id;
      _store.products[index] = data;
      _emitProducts();
    }
  }

  /// Delete a product by ID
  Future<void> deleteProduct(String id) async {
    _store.products.removeWhere((p) => p['id'] == id);
    _emitProducts();
  }

  void dispose() {
    _streamController.close();
  }
}
