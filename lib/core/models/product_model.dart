/// Recipe item representing ingredient usage in a product
class RecipeItem {
  final String ingredientId;
  final double amount;

  RecipeItem({required this.ingredientId, required this.amount});

  factory RecipeItem.fromMap(Map<String, dynamic> data) {
    return RecipeItem(
      ingredientId: data['ingredientId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'ingredientId': ingredientId, 'amount': amount};
  }
}

class Product {
  final String? id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<RecipeItem> recipe;
  int qty;

  Product({
    this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    this.recipe = const [],
    this.qty = 0,
  });

  // Dari Firebase ke Aplikasi
  factory Product.fromMap(Map<String, dynamic> data, String documentId) {
    // Parse recipe array
    List<RecipeItem> recipeList = [];
    if (data['recipe'] != null && data['recipe'] is List) {
      recipeList = (data['recipe'] as List)
          .map((item) => RecipeItem.fromMap(item as Map<String, dynamic>))
          .toList();
    }

    return Product(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      category: data['category'] ?? 'General',
      recipe: recipeList,
      qty: 0,
    );
  }

  // Dari Aplikasi ke Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'recipe': recipe.map((r) => r.toMap()).toList(),
      'created_at': DateTime.now().toString(),
    };
  }

  /// Create a copy with updated fields
  Product copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? category,
    List<RecipeItem>? recipe,
    int? qty,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      recipe: recipe ?? this.recipe,
      qty: qty ?? this.qty,
    );
  }

  /// Check if product has a recipe defined
  bool get hasRecipe => recipe.isNotEmpty;
}
