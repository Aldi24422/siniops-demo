import 'dart:async';
import '../models/ingredient_model.dart';
import 'preview_mode_controller.dart';

/// Mock Ingredient Controller for Preview Mode
/// All operations are performed in-memory only
class MockIngredientController {
  final MockDataStore _store = MockDataStore.instance;

  // Stream controller for reactive updates
  final StreamController<List<Ingredient>> _streamController =
      StreamController<List<Ingredient>>.broadcast();

  void _emitIngredients() {
    final ingredients = _store.ingredients.map((data) {
      return Ingredient.fromMap(data, data['id'] as String);
    }).toList();
    _streamController.add(ingredients);
  }

  /// Stream of all ingredients ordered by name
  Stream<List<Ingredient>> getIngredients() {
    // Use async to emit after stream is subscribed
    Future.microtask(() => _emitIngredients());
    return _streamController.stream;
  }

  /// Get single ingredient by ID
  Future<Ingredient?> getIngredientById(String id) async {
    final data = _store.ingredients.firstWhere(
      (i) => i['id'] == id,
      orElse: () => <String, dynamic>{},
    );
    if (data.isEmpty) return null;
    return Ingredient.fromMap(data, data['id'] as String);
  }

  /// Add a new ingredient
  Future<String> addIngredient(Ingredient ingredient) async {
    final id = 'ing_${DateTime.now().millisecondsSinceEpoch}';
    final data = ingredient.toMap();
    data['id'] = id;
    _store.ingredients.add(data);
    _emitIngredients();
    return id;
  }

  /// Update an existing ingredient
  Future<void> updateIngredient(Ingredient ingredient) async {
    if (ingredient.id == null) {
      throw ArgumentError('Ingredient ID is required for update');
    }
    final index = _store.ingredients.indexWhere(
      (i) => i['id'] == ingredient.id,
    );
    if (index != -1) {
      final data = ingredient.toMap();
      data['id'] = ingredient.id;
      _store.ingredients[index] = data;
      _emitIngredients();
    }
  }

  /// Delete an ingredient by ID
  Future<void> deleteIngredient(String id) async {
    _store.ingredients.removeWhere((i) => i['id'] == id);
    _emitIngredients();
  }

  /// Restock ingredient
  Future<void> restockIngredient(String id, double amount) async {
    if (amount <= 0) {
      throw ArgumentError('Restock amount must be positive');
    }
    final index = _store.ingredients.indexWhere((i) => i['id'] == id);
    if (index != -1) {
      _store.ingredients[index]['stockInBaseUnit'] =
          (_store.ingredients[index]['stockInBaseUnit'] as double) + amount;
      _emitIngredients();
    }
  }

  /// Deduct stock
  Future<void> deductStock(String id, double amount) async {
    if (amount <= 0) {
      throw ArgumentError('Deduct amount must be positive');
    }
    final index = _store.ingredients.indexWhere((i) => i['id'] == id);
    if (index != -1) {
      _store.ingredients[index]['stockInBaseUnit'] =
          (_store.ingredients[index]['stockInBaseUnit'] as double) - amount;
      _emitIngredients();
    }
  }

  /// Get ingredients with low stock
  Stream<List<Ingredient>> getLowStockIngredients() {
    return getIngredients().map((ingredients) {
      return ingredients.where((i) => i.isLowStock).toList();
    });
  }

  void dispose() {
    _streamController.close();
  }
}
