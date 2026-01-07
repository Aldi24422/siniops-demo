import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';

/// Result of a transaction operation
class TransactionResult {
  final bool success;
  final String? transactionId;
  final String message;
  final List<String> errors;

  TransactionResult({
    required this.success,
    this.transactionId,
    required this.message,
    this.errors = const [],
  });
}

/// Exception thrown when stock is insufficient
class InsufficientStockException implements Exception {
  final String ingredientName;
  final double required;
  final double available;
  final String baseUnit;

  InsufficientStockException({
    required this.ingredientName,
    required this.required,
    required this.available,
    required this.baseUnit,
  });

  /// Format stock with smart units (Kg/L if >= 1000)
  String _formatStock(double value) {
    if (value >= 1000) {
      final converted = value / 1000;
      final bigUnit = baseUnit == 'gram' ? 'Kg' : 'L';
      return '${_formatNumber(converted)} $bigUnit';
    }
    return '${_formatNumber(value)} $baseUnit';
  }

  String _formatNumber(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    String formatted = value.toStringAsFixed(2);
    formatted = formatted.replaceAll(RegExp(r'0+$'), '');
    formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    return formatted;
  }

  @override
  String toString() =>
      'Stok "$ingredientName" tidak cukup! Butuh: ${_formatStock(required)}, Sisa: ${_formatStock(available)}';
}

/// Controller for processing transactions with atomic stock deduction
class TransactionController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _ingredientsCollection =>
      _firestore.collection('ingredients');

  CollectionReference get _transactionsCollection =>
      _firestore.collection('transactions');

  /// Process a transaction with cart items
  /// Uses Firestore Transaction for atomic operations
  ///
  /// Steps:
  /// 1. Validate all stock availability
  /// 2. Deduct stock for each ingredient in recipes
  /// 3. Save transaction record
  ///
  /// Throws [InsufficientStockException] if any ingredient has insufficient stock
  Future<TransactionResult> processTransaction({
    required List<Product> cartItems,
    required double totalAmount,
    String? paymentMethod,
    String? cashierUid,
  }) async {
    if (cartItems.isEmpty) {
      return TransactionResult(success: false, message: 'Keranjang kosong');
    }

    try {
      // Run as Firestore transaction for atomicity
      final transactionId = await _firestore.runTransaction<String>((
        transaction,
      ) async {
        // Step 1: Calculate total ingredient requirements
        final Map<String, double> ingredientRequirements = {};
        final Map<String, String> ingredientNames = {};

        for (final product in cartItems) {
          final qty = product.qty > 0 ? product.qty : 1;

          for (final recipeItem in product.recipe) {
            final requiredAmount = recipeItem.amount * qty;
            ingredientRequirements[recipeItem.ingredientId] =
                (ingredientRequirements[recipeItem.ingredientId] ?? 0) +
                requiredAmount;
          }
        }

        // Step 2: Validate stock availability
        for (final entry in ingredientRequirements.entries) {
          final ingredientId = entry.key;
          final requiredAmount = entry.value;

          final docRef = _ingredientsCollection.doc(ingredientId);
          final snapshot = await transaction.get(docRef);

          if (!snapshot.exists) {
            throw Exception('Bahan dengan ID $ingredientId tidak ditemukan');
          }

          final data = snapshot.data() as Map<String, dynamic>;
          // Use stockInBaseUnit field
          final currentStock =
              (data['stockInBaseUnit'] ?? data['currentStock'] ?? 0).toDouble();
          final ingredientName = data['name'] ?? 'Unknown';
          final baseUnit = data['baseUnit'] ?? 'gram';
          ingredientNames[ingredientId] = ingredientName;

          if (currentStock < requiredAmount) {
            throw InsufficientStockException(
              ingredientName: ingredientName,
              required: requiredAmount,
              available: currentStock,
              baseUnit: baseUnit,
            );
          }
        }

        // Step 3: Deduct stock
        for (final entry in ingredientRequirements.entries) {
          final ingredientId = entry.key;
          final deductAmount = entry.value;

          final docRef = _ingredientsCollection.doc(ingredientId);
          transaction.update(docRef, {
            'stockInBaseUnit': FieldValue.increment(-deductAmount),
          });

          debugPrint(
            '[TransactionController] Deducting $deductAmount from ${ingredientNames[ingredientId]}',
          );
        }

        // Step 4: Create transaction record
        final transactionData = {
          'items': cartItems
              .map(
                (p) => {
                  'productId': p.id,
                  'productName': p.name,
                  'price': p.price,
                  'qty': p.qty > 0 ? p.qty : 1,
                  'subtotal': p.price * (p.qty > 0 ? p.qty : 1),
                },
              )
              .toList(),
          'totalAmount': totalAmount,
          'paymentMethod': paymentMethod ?? 'cash',
          'cashierUid': cashierUid,
          'ingredientsUsed': ingredientRequirements.entries
              .map(
                (e) => {
                  'ingredientId': e.key,
                  'ingredientName': ingredientNames[e.key],
                  'amount': e.value,
                },
              )
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'completed',
        };

        final newTransactionRef = _transactionsCollection.doc();
        transaction.set(newTransactionRef, transactionData);

        return newTransactionRef.id;
      });

      debugPrint(
        '[TransactionController] Transaction completed: $transactionId',
      );

      return TransactionResult(
        success: true,
        transactionId: transactionId,
        message: 'Transaksi berhasil',
      );
    } on InsufficientStockException catch (e) {
      debugPrint('[TransactionController] Insufficient stock: $e');
      return TransactionResult(
        success: false,
        message: e.toString(),
        errors: [e.toString()],
      );
    } catch (e) {
      debugPrint('[TransactionController] Transaction failed: $e');
      return TransactionResult(
        success: false,
        message: 'Transaksi gagal: $e',
        errors: [e.toString()],
      );
    }
  }

  /// Get transaction history stream
  Stream<List<Map<String, dynamic>>> getTransactionHistory({int limit = 50}) {
    return _transactionsCollection
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Get today's transactions
  Stream<List<Map<String, dynamic>>> getTodayTransactions() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {'id': doc.id, ...data};
          }).toList();
        });
  }

  /// Calculate today's total revenue
  Future<double> getTodayRevenue() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .get();

    double total = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      total += (data['totalAmount'] ?? 0).toDouble();
    }

    return total;
  }

  /// Stream for real-time today's revenue (for dashboard)
  Stream<double> getTodayRevenueStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .map((snapshot) {
          double total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            total += (data['totalAmount'] ?? 0).toDouble();
          }
          return total;
        });
  }

  /// Stream for today's transaction count
  Stream<int> getTodayTransactionCountStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get weekly revenue data for chart (last 7 days)
  /// Returns Map with day names (Sen, Sel, Rab...) as keys
  Future<Map<String, double>> getWeeklyRevenue() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));
    final startOfWeek = DateTime(weekAgo.year, weekAgo.month, weekAgo.day);

    final snapshot = await _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek),
        )
        .orderBy('createdAt')
        .get();

    // Initialize all 7 days with 0
    final Map<String, double> dailyRevenue = {};
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    for (int i = 0; i < 7; i++) {
      final date = startOfWeek.add(Duration(days: i));
      final dayIndex = (date.weekday - 1) % 7; // Monday = 0
      final key = '${dayNames[dayIndex]} ${date.day}';
      dailyRevenue[key] = 0;
    }

    // Aggregate revenue per day
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['createdAt'] as Timestamp?;
      if (timestamp == null) continue;

      final date = timestamp.toDate();
      final dayIndex = (date.weekday - 1) % 7;
      final key = '${dayNames[dayIndex]} ${date.day}';

      final amount = (data['totalAmount'] ?? 0).toDouble();
      dailyRevenue[key] = (dailyRevenue[key] ?? 0) + amount;
    }

    return dailyRevenue;
  }

  /// Get top selling products (by quantity sold)
  /// Returns list of maps with productName, totalQty, totalRevenue
  Future<List<Map<String, dynamic>>> getTopSellingProducts({
    int limit = 5,
  }) async {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    final startDate = DateTime(monthAgo.year, monthAgo.month, monthAgo.day);

    final snapshot = await _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .get();

    // Aggregate product sales
    final Map<String, Map<String, dynamic>> productStats = {};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final productName = item['productName'] ?? 'Unknown';
        final qty = (item['qty'] ?? 1) as int;
        final subtotal = (item['subtotal'] ?? 0).toDouble();

        if (!productStats.containsKey(productName)) {
          productStats[productName] = {
            'productName': productName,
            'totalQty': 0,
            'totalRevenue': 0.0,
          };
        }

        productStats[productName]!['totalQty'] += qty;
        productStats[productName]!['totalRevenue'] += subtotal;
      }
    }

    // Sort by quantity and take top N
    final sorted = productStats.values.toList()
      ..sort((a, b) => (b['totalQty'] as int).compareTo(a['totalQty'] as int));

    return sorted.take(limit).toList();
  }

  /// Get monthly summary
  Future<Map<String, dynamic>> getMonthlySummary() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);

    final snapshot = await _transactionsCollection
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth),
        )
        .get();

    double totalRevenue = 0;
    int totalTransactions = snapshot.docs.length;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalRevenue += (data['totalAmount'] ?? 0).toDouble();
    }

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': totalTransactions,
      'averageTransaction': totalTransactions > 0
          ? totalRevenue / totalTransactions
          : 0.0,
    };
  }
}
