import 'package:flutter/foundation.dart';

/// Singleton controller to manage Preview Mode state.
/// When in preview mode, all CRUD operations are performed in-memory
/// and data resets when app is reloaded.
class PreviewModeController extends ChangeNotifier {
  // Singleton instance
  static final PreviewModeController _instance = PreviewModeController._();
  static PreviewModeController get instance => _instance;

  PreviewModeController._();

  bool _isPreviewMode = false;
  String _previewRole = 'owner';

  /// Check if app is in preview mode
  bool get isPreviewMode => _isPreviewMode;

  /// Get current preview role ('owner' or 'crew')
  String get previewRole => _previewRole;

  /// Enter preview mode with specified role
  void enterPreviewMode({String role = 'owner'}) {
    _isPreviewMode = true;
    _previewRole = role;
    notifyListeners();
    debugPrint('[PreviewMode] Entered preview mode as $role');
  }

  /// Exit preview mode
  void exitPreviewMode() {
    _isPreviewMode = false;
    _previewRole = 'owner';
    notifyListeners();
    debugPrint('[PreviewMode] Exited preview mode');
  }

  /// Reset all mock data (called when exiting or refreshing)
  void resetMockData() {
    // This will be called to reset mock controllers
    MockDataStore.instance.reset();
    debugPrint('[PreviewMode] Mock data reset');
  }
}

/// Central store for all mock data
/// Keeps data in memory - resets on app reload
class MockDataStore {
  static final MockDataStore _instance = MockDataStore._();
  static MockDataStore get instance => _instance;

  MockDataStore._() {
    reset();
  }

  // Products
  late List<Map<String, dynamic>> products;

  // Ingredients
  late List<Map<String, dynamic>> ingredients;

  // Transactions
  late List<Map<String, dynamic>> transactions;

  /// Reset all data to initial mock values
  void reset() {
    products = _getInitialProducts();
    ingredients = _getInitialIngredients();
    transactions = _getInitialTransactions();
  }

  // ============ INITIAL MOCK DATA ============

  List<Map<String, dynamic>> _getInitialProducts() {
    return [
      {
        'id': 'prod_001',
        'name': 'Dominic',
        'description': 'Americano',
        'price': 10000.0,
        'category': 'Coffee',
        'recipe': [
          {'ingredientId': 'ing_001', 'amount': 18.0},
          {'ingredientId': 'ing_003', 'amount': 200.0},
        ],
      },
      {
        'id': 'prod_002',
        'name': 'Aureto',
        'description': 'Aren Latte',
        'price': 14000.0,
        'category': 'Coffee',
        'recipe': [
          {'ingredientId': 'ing_001', 'amount': 18.0},
          {'ingredientId': 'ing_002', 'amount': 150.0},
          {'ingredientId': 'ing_004', 'amount': 30.0},
        ],
      },
      {
        'id': 'prod_003',
        'name': 'Ryoku',
        'description': 'Matcha Latte',
        'price': 17000.0,
        'category': 'Non-Coffee',
        'recipe': [
          {'ingredientId': 'ing_005', 'amount': 25.0},
          {'ingredientId': 'ing_002', 'amount': 200.0},
        ],
      },
      {
        'id': 'prod_004',
        'name': 'Kopi Susu Gula Aren',
        'description': 'Es Kopi Susu dengan Gula Aren',
        'price': 18000.0,
        'category': 'Coffee',
        'recipe': [
          {'ingredientId': 'ing_001', 'amount': 20.0},
          {'ingredientId': 'ing_002', 'amount': 100.0},
          {'ingredientId': 'ing_004', 'amount': 25.0},
        ],
      },
      {
        'id': 'prod_005',
        'name': 'Chocolatte',
        'description': 'Cokelat Susu Premium',
        'price': 16000.0,
        'category': 'Non-Coffee',
        'recipe': [
          {'ingredientId': 'ing_006', 'amount': 30.0},
          {'ingredientId': 'ing_002', 'amount': 180.0},
        ],
      },
      {
        'id': 'prod_006',
        'name': 'Espresso',
        'description': 'Single Shot Espresso',
        'price': 8000.0,
        'category': 'Coffee',
        'recipe': [
          {'ingredientId': 'ing_001', 'amount': 18.0},
        ],
      },
    ];
  }

  List<Map<String, dynamic>> _getInitialIngredients() {
    return [
      {
        'id': 'ing_001',
        'name': 'Kopi Arabica',
        'stockInBaseUnit': 2500.0,
        'baseUnit': 'gram',
        'minStockAlert': 500.0,
      },
      {
        'id': 'ing_002',
        'name': 'Susu Full Cream',
        'stockInBaseUnit': 5000.0,
        'baseUnit': 'ml',
        'minStockAlert': 1000.0,
      },
      {
        'id': 'ing_003',
        'name': 'Air Mineral',
        'stockInBaseUnit': 10000.0,
        'baseUnit': 'ml',
        'minStockAlert': 2000.0,
      },
      {
        'id': 'ing_004',
        'name': 'Gula Aren',
        'stockInBaseUnit': 1500.0,
        'baseUnit': 'gram',
        'minStockAlert': 300.0,
      },
      {
        'id': 'ing_005',
        'name': 'Matcha Powder',
        'stockInBaseUnit': 800.0,
        'baseUnit': 'gram',
        'minStockAlert': 200.0,
      },
      {
        'id': 'ing_006',
        'name': 'Cokelat Bubuk',
        'stockInBaseUnit': 1200.0,
        'baseUnit': 'gram',
        'minStockAlert': 250.0,
      },
    ];
  }

  List<Map<String, dynamic>> _getInitialTransactions() {
    final now = DateTime.now();
    return [
      {
        'id': 'txn_001',
        'items': [
          {
            'productId': 'prod_001',
            'productName': 'Dominic',
            'price': 10000.0,
            'qty': 2,
            'subtotal': 20000.0,
          },
          {
            'productId': 'prod_002',
            'productName': 'Aureto',
            'price': 14000.0,
            'qty': 1,
            'subtotal': 14000.0,
          },
        ],
        'totalAmount': 34000.0,
        'paymentMethod': 'cash',
        'createdAt': now.subtract(const Duration(hours: 2)),
        'status': 'completed',
      },
      {
        'id': 'txn_002',
        'items': [
          {
            'productId': 'prod_003',
            'productName': 'Ryoku',
            'price': 17000.0,
            'qty': 1,
            'subtotal': 17000.0,
          },
        ],
        'totalAmount': 17000.0,
        'paymentMethod': 'qris',
        'createdAt': now.subtract(const Duration(hours: 4)),
        'status': 'completed',
      },
      {
        'id': 'txn_003',
        'items': [
          {
            'productId': 'prod_004',
            'productName': 'Kopi Susu Gula Aren',
            'price': 18000.0,
            'qty': 3,
            'subtotal': 54000.0,
          },
        ],
        'totalAmount': 54000.0,
        'paymentMethod': 'cash',
        'createdAt': now.subtract(const Duration(days: 1, hours: 3)),
        'status': 'completed',
      },
      {
        'id': 'txn_004',
        'items': [
          {
            'productId': 'prod_005',
            'productName': 'Chocolatte',
            'price': 16000.0,
            'qty': 2,
            'subtotal': 32000.0,
          },
          {
            'productId': 'prod_006',
            'productName': 'Espresso',
            'price': 8000.0,
            'qty': 1,
            'subtotal': 8000.0,
          },
        ],
        'totalAmount': 40000.0,
        'paymentMethod': 'cash',
        'createdAt': now.subtract(const Duration(days: 1, hours: 6)),
        'status': 'completed',
      },
      {
        'id': 'txn_005',
        'items': [
          {
            'productId': 'prod_001',
            'productName': 'Dominic',
            'price': 10000.0,
            'qty': 1,
            'subtotal': 10000.0,
          },
        ],
        'totalAmount': 10000.0,
        'paymentMethod': 'qris',
        'createdAt': now.subtract(const Duration(days: 2)),
        'status': 'completed',
      },
    ];
  }
}
