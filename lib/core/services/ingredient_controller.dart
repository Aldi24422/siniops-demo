import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient_model.dart';

/// Controller for managing ingredients (bahan baku) in Firestore
class IngredientController {
  final CollectionReference _ingredientCollection = FirebaseFirestore.instance
      .collection('ingredients');

  /// Stream of all ingredients ordered by name
  Stream<List<Ingredient>> getIngredients() {
    return _ingredientCollection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Ingredient.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  /// Get single ingredient by ID
  Future<Ingredient?> getIngredientById(String id) async {
    final doc = await _ingredientCollection.doc(id).get();
    if (doc.exists) {
      return Ingredient.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }
    return null;
  }

  /// Add a new ingredient
  Future<String> addIngredient(Ingredient ingredient) async {
    final doc = await _ingredientCollection.add(ingredient.toMap());
    return doc.id;
  }

  /// Update an existing ingredient
  Future<void> updateIngredient(Ingredient ingredient) async {
    if (ingredient.id == null) {
      throw ArgumentError('Ingredient ID is required for update');
    }
    await _ingredientCollection.doc(ingredient.id).update(ingredient.toMap());
  }

  /// Delete an ingredient by ID
  Future<void> deleteIngredient(String id) async {
    await _ingredientCollection.doc(id).delete();
  }

  /// Restock ingredient (INCREMENT, not replace)
  /// Adds the specified amount to stockInBaseUnit
  Future<void> restockIngredient(String id, double amount) async {
    if (amount <= 0) {
      throw ArgumentError('Restock amount must be positive');
    }
    await _ingredientCollection.doc(id).update({
      'stockInBaseUnit': FieldValue.increment(amount),
    });
  }

  /// Deduct stock (used internally by TransactionController)
  Future<void> deductStock(String id, double amount) async {
    if (amount <= 0) {
      throw ArgumentError('Deduct amount must be positive');
    }
    await _ingredientCollection.doc(id).update({
      'stockInBaseUnit': FieldValue.increment(-amount),
    });
  }

  /// Get ingredients with low stock
  Stream<List<Ingredient>> getLowStockIngredients() {
    return getIngredients().map((ingredients) {
      return ingredients.where((i) => i.isLowStock).toList();
    });
  }
}
