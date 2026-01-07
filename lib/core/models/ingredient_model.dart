/// Model for ingredient (bahan baku) with Smart Unit Conversion
///
/// Stores stock in base units (gram/ml) for precision arithmetic.
/// Provides smart display that converts to Kg/L when >= 1000.
class Ingredient {
  final String? id;
  final String name;
  final double stockInBaseUnit; // Always stored in gram or ml
  final String baseUnit; // Only 'gram' or 'ml'
  final double minStockAlert; // In base unit

  Ingredient({
    this.id,
    required this.name,
    required this.stockInBaseUnit,
    required this.baseUnit,
    this.minStockAlert = 0,
  });

  /// Create from Firestore document
  factory Ingredient.fromMap(Map<String, dynamic> data, String documentId) {
    return Ingredient(
      id: documentId,
      name: data['name'] ?? '',
      stockInBaseUnit: (data['stockInBaseUnit'] ?? data['currentStock'] ?? 0)
          .toDouble(),
      baseUnit: data['baseUnit'] ?? data['unit'] ?? 'gram',
      minStockAlert: (data['minStockAlert'] ?? 0).toDouble(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'stockInBaseUnit': stockInBaseUnit,
      'baseUnit': baseUnit,
      'minStockAlert': minStockAlert,
    };
  }

  /// Create a copy with updated fields
  Ingredient copyWith({
    String? id,
    String? name,
    double? stockInBaseUnit,
    String? baseUnit,
    double? minStockAlert,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      stockInBaseUnit: stockInBaseUnit ?? this.stockInBaseUnit,
      baseUnit: baseUnit ?? this.baseUnit,
      minStockAlert: minStockAlert ?? this.minStockAlert,
    );
  }

  /// Check if stock is below minimum alert level
  bool get isLowStock => stockInBaseUnit < minStockAlert;

  /// Smart display: Shows Kg/L if >= 1000, otherwise gram/ml
  /// Examples: "1.5 Kg", "500 gram", "2.3 L", "750 ml"
  String get displayStock {
    if (stockInBaseUnit >= 1000) {
      final converted = stockInBaseUnit / 1000;
      final bigUnit = baseUnit == 'gram' ? 'Kg' : 'L';
      return '${_formatNumber(converted)} $bigUnit';
    } else {
      return '${_formatNumber(stockInBaseUnit)} $baseUnit';
    }
  }

  /// Display minimum stock with smart units
  String get displayMinStock {
    if (minStockAlert >= 1000) {
      final converted = minStockAlert / 1000;
      final bigUnit = baseUnit == 'gram' ? 'Kg' : 'L';
      return '${_formatNumber(converted)} $bigUnit';
    } else {
      return '${_formatNumber(minStockAlert)} $baseUnit';
    }
  }

  /// Format number: remove unnecessary decimals
  String _formatNumber(double value) {
    if (value == value.toInt().toDouble()) {
      return value.toInt().toString();
    }
    // Show up to 2 decimal places, remove trailing zeros
    String formatted = value.toStringAsFixed(2);
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      formatted = formatted.replaceAll(RegExp(r'\.$'), '');
    }
    return formatted;
  }
}

/// Helper class for unit conversion
class UnitConverter {
  /// Available input units for UI dropdown
  static const List<String> displayUnits = [
    'Gram',
    'Kilogram',
    'MiliLiter',
    'Liter',
  ];

  /// Get base unit from display unit
  static String getBaseUnit(String displayUnit) {
    switch (displayUnit) {
      case 'Gram':
      case 'Kilogram':
        return 'gram';
      case 'MiliLiter':
      case 'Liter':
        return 'ml';
      default:
        return 'gram';
    }
  }

  /// Convert input value to base unit value
  /// Kilogram/Liter -> multiply by 1000
  /// Gram/MiliLiter -> as is
  static double toBaseUnit(double inputValue, String displayUnit) {
    switch (displayUnit) {
      case 'Kilogram':
      case 'Liter':
        return inputValue * 1000;
      case 'Gram':
      case 'MiliLiter':
      default:
        return inputValue;
    }
  }

  /// Convert base unit value to display unit value
  static double fromBaseUnit(double baseValue, String displayUnit) {
    switch (displayUnit) {
      case 'Kilogram':
      case 'Liter':
        return baseValue / 1000;
      case 'Gram':
      case 'MiliLiter':
      default:
        return baseValue;
    }
  }

  /// Get best display unit for a base value
  static String getBestDisplayUnit(double baseValue, String baseUnit) {
    if (baseValue >= 1000) {
      return baseUnit == 'gram' ? 'Kilogram' : 'Liter';
    } else {
      return baseUnit == 'gram' ? 'Gram' : 'MiliLiter';
    }
  }
}
