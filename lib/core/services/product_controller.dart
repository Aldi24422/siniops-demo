import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product_model.dart';

class ProductController {
  final CollectionReference _productCollection = FirebaseFirestore.instance
      .collection('products');

  /// Stream of all products ordered by name
  Stream<List<Product>> getProducts() {
    return _productCollection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Product.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Add a new product
  Future<String> addProduct(Product product) async {
    final doc = await _productCollection.add(product.toMap());
    return doc.id;
  }

  /// Update an existing product
  Future<void> updateProduct(Product product) async {
    if (product.id == null) {
      throw ArgumentError('Product ID is required for update');
    }
    await _productCollection.doc(product.id).update(product.toMap());
  }

  /// Delete a product by ID
  Future<void> deleteProduct(String id) async {
    await _productCollection.doc(id).delete();
  }

  /// Seed dummy data (for initial setup)
  Future<void> uploadDummyData() async {
    List<Product> dummyData = [
      Product(
        name: "Dominic",
        description: "Americano",
        price: 10000,
        category: "Coffee",
      ),
      Product(
        name: "Aureto",
        description: "Aren Latte",
        price: 14000,
        category: "Coffee",
      ),
      Product(
        name: "Ryoku",
        description: "Matcha Latte",
        price: 17000,
        category: "Non-Coffee",
      ),
    ];
    for (var p in dummyData) {
      await _productCollection.add(p.toMap());
    }
  }
}
