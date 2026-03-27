import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import 'preview_mode_controller.dart';

/// Transaction result model (previously in transaction_controller.dart)
class TransactionResult {
  final bool success;
  final String? transactionId;
  final String? message;
  final List<String>? errors;
  final List<String>? warnings;

  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;

  TransactionResult({
    required this.success,
    this.transactionId,
    this.message,
    this.errors,
    this.warnings,
  });
}

/// Mock Transaction Controller for Preview Mode
/// All operations are performed in-memory only
class MockTransactionController {
  final MockDataStore _store = MockDataStore.instance;

  /// Process a transaction with cart items
  Future<TransactionResult> processTransaction({
    required List<Product> cartItems,
    required double totalAmount,
    String? paymentMethod,
    String? staffUid,
    double? cashReceived,
    double? changeAmount,
  }) async {
    if (cartItems.isEmpty) {
      return TransactionResult(success: false, message: 'Keranjang kosong');
    }

    try {
      final id = 'txn_${DateTime.now().millisecondsSinceEpoch}';

      // Deduct ingredient stock
      for (final product in cartItems) {
        final qty = product.qty > 0 ? product.qty : 1;
        final productData = _store.products.firstWhere(
          (p) => p['id'] == product.id,
          orElse: () => <String, dynamic>{},
        );

        if (productData.isNotEmpty && productData['recipe'] != null) {
          for (final recipeItem in productData['recipe'] as List) {
            final ingId = recipeItem['ingredientId'] as String;
            final amount = (recipeItem['amount'] as num).toDouble() * qty;

            final ingIndex = _store.ingredients.indexWhere(
              (i) => i['id'] == ingId,
            );
            if (ingIndex != -1) {
              _store.ingredients[ingIndex]['stockInBaseUnit'] =
                  (_store.ingredients[ingIndex]['stockInBaseUnit'] as double) -
                  amount;
            }
          }
        }
      }

      // Create transaction record
      final transaction = {
        'id': id,
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
        'staffUid': staffUid,
        'paymentDetails': cashReceived != null
            ? {'cashReceived': cashReceived, 'changeAmount': changeAmount ?? 0}
            : null,
        'createdAt': DateTime.now(),
        'status': 'completed',
      };

      _store.transactions.insert(0, transaction);

      debugPrint('[MockTransactionController] Transaction completed: $id');

      return TransactionResult(
        success: true,
        transactionId: id,
        message: 'Transaksi berhasil (Preview Mode)',
      );
    } catch (e) {
      debugPrint('[MockTransactionController] Transaction failed: $e');
      return TransactionResult(
        success: false,
        message: 'Transaksi gagal: $e',
        errors: [e.toString()],
      );
    }
  }

  /// Stream for real-time today's revenue
  Stream<double> getTodayRevenueStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    double total = 0;
    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startOfDay)) {
        total += (txn['totalAmount'] as num).toDouble();
      }
    }
    return Stream.value(total);
  }

  /// Stream for yesterday's revenue
  Stream<double> getYesterdayRevenueStream() {
    final now = DateTime.now();
    final startOfYesterday = DateTime(now.year, now.month, now.day - 1);
    final endOfYesterday = DateTime(now.year, now.month, now.day);

    double total = 0;
    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startOfYesterday) &&
          createdAt.isBefore(endOfYesterday)) {
        total += (txn['totalAmount'] as num).toDouble();
      }
    }
    return Stream.value(total);
  }

  /// Stream for today's transaction count
  Stream<int> getTodayTransactionCountStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    int count = 0;
    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startOfDay)) {
        count++;
      }
    }
    return Stream.value(count);
  }

  /// Get revenue for a custom date range
  Future<Map<String, double>> getRevenueForPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final daysDiff = endDate.difference(startDate).inDays + 1;
    final Map<String, double> revenueData = {};

    // Initialize days
    for (int i = 0; i < daysDiff; i++) {
      final date = startDate.add(Duration(days: i));
      revenueData['${date.day}'] = 0;
    }

    // Aggregate
    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
          createdAt.isBefore(endDate.add(const Duration(days: 1)))) {
        final key = '${createdAt.day}';
        final amount = (txn['totalAmount'] as num).toDouble();
        revenueData[key] = (revenueData[key] ?? 0) + amount;
      }
    }

    return revenueData;
  }

  /// Get summary for a date range
  Future<Map<String, dynamic>> getSummaryForPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    double totalRevenue = 0;
    int totalTransactions = 0;

    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
          createdAt.isBefore(endDate.add(const Duration(days: 1)))) {
        totalRevenue += (txn['totalAmount'] as num).toDouble();
        totalTransactions++;
      }
    }

    return {
      'totalRevenue': totalRevenue,
      'totalTransactions': totalTransactions,
    };
  }

  /// Get top selling products for a period
  Future<List<Map<String, dynamic>>> getTopProductsForPeriod(
    DateTime startDate,
    DateTime endDate, {
    int limit = 5,
  }) async {
    final Map<String, Map<String, dynamic>> productStats = {};

    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
          createdAt.isBefore(endDate.add(const Duration(days: 1)))) {
        final items = txn['items'] as List<dynamic>? ?? [];
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

          productStats[productName]!['totalQty'] =
              (productStats[productName]!['totalQty'] as int) + qty;
          productStats[productName]!['totalRevenue'] =
              (productStats[productName]!['totalRevenue'] as double) + subtotal;
        }
      }
    }

    final sorted = productStats.values.toList()
      ..sort((a, b) => (b['totalQty'] as int).compareTo(a['totalQty'] as int));

    return sorted.take(limit).toList();
  }

  /// Helper methods for dashboard compatibility
  Map<String, DateTime> getThisWeekPeriod() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return {
      'start': DateTime(monday.year, monday.month, monday.day),
      'end': DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59),
    };
  }

  Map<String, DateTime> getThisMonthPeriod() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return {'start': startOfMonth, 'end': endOfMonth};
  }

  Map<String, DateTime> getThisYearPeriod() {
    final now = DateTime.now();
    return {
      'start': DateTime(now.year, 1, 1),
      'end': DateTime(now.year, 12, 31, 23, 59, 59),
    };
  }

  /// Get transactions for a date range (used by transaction history page)
  Future<List<Map<String, dynamic>>> getTransactionsForPeriod(
    DateTime startDate,
    DateTime endDate, {
    int limit = 200,
  }) async {
    final results = <Map<String, dynamic>>[];

    for (final txn in _store.transactions) {
      final createdAt = txn['createdAt'] as DateTime;
      if (createdAt.isAfter(startDate.subtract(const Duration(days: 1))) &&
          createdAt.isBefore(endDate.add(const Duration(days: 1)))) {
        results.add(txn);
      }
    }

    // Sort newest first
    results.sort((a, b) => (b['createdAt'] as DateTime)
        .compareTo(a['createdAt'] as DateTime));

    return results.take(limit).toList();
  }
}
