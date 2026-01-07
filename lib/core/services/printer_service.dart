import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import '../models/product_model.dart';

/// Wi-Fi settings model for receipt footer
class WifiSettings {
  final String ssid;
  final String password;

  WifiSettings({this.ssid = '', this.password = ''});

  bool get isEmpty => ssid.isEmpty && password.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Store settings model for receipt header
class StoreSettings {
  final String address;

  StoreSettings({this.address = ''});

  bool get isEmpty => address.isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Receipt data model for printing
class ReceiptData {
  final String? transactionId;
  final List<Product> items;
  final double totalAmount;
  final String paymentMethod;
  final DateTime timestamp;

  ReceiptData({
    this.transactionId,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Singleton service for Bluetooth thermal printer operations
class PrinterService {
  // Singleton pattern
  static final PrinterService _instance = PrinterService._internal();
  static PrinterService get instance => _instance;
  PrinterService._internal();

  final BlueThermalPrinter _printer = BlueThermalPrinter.instance;

  // Connection state
  BluetoothDevice? _connectedDevice;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Cached logo path
  String? _cachedLogoPath;

  // Store settings
  static const String _storeName = "SINI.NGOPI";
  static const String _logoAssetPath = 'assets/images/logo.png';

  // SharedPreferences keys
  static const String _keyWifiSsid = 'receipt_wifi_ssid';
  static const String _keyWifiPass = 'receipt_wifi_password';
  static const String _keyShopAddress = 'shop_address';

  // Default values (used when nothing is saved)
  static const String _defaultWifiSsid = 'SiniNgopi';
  static const String _defaultWifiPass = 'kopi123';
  static const String _defaultShopAddress = 'Jl. Contoh No. 123, Surabaya';

  /// Save Wi-Fi settings to SharedPreferences
  Future<bool> saveWifiSettings(String ssid, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWifiSsid, ssid);
      await prefs.setString(_keyWifiPass, password);
      debugPrint('[PrinterService] Wi-Fi settings saved: SSID=$ssid');
      return true;
    } catch (e) {
      debugPrint('[PrinterService] Error saving Wi-Fi settings: $e');
      return false;
    }
  }

  /// Get Wi-Fi settings from SharedPreferences
  Future<WifiSettings> getWifiSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ssid = prefs.getString(_keyWifiSsid) ?? _defaultWifiSsid;
      final password = prefs.getString(_keyWifiPass) ?? _defaultWifiPass;
      return WifiSettings(ssid: ssid, password: password);
    } catch (e) {
      debugPrint('[PrinterService] Error getting Wi-Fi settings: $e');
      return WifiSettings(ssid: _defaultWifiSsid, password: _defaultWifiPass);
    }
  }

  /// Save shop address to SharedPreferences
  Future<bool> saveShopAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyShopAddress, address);
      debugPrint('[PrinterService] Shop address saved: $address');
      return true;
    } catch (e) {
      debugPrint('[PrinterService] Error saving shop address: $e');
      return false;
    }
  }

  /// Get shop address from SharedPreferences
  Future<StoreSettings> getStoreSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_keyShopAddress) ?? _defaultShopAddress;
      return StoreSettings(address: address);
    } catch (e) {
      debugPrint('[PrinterService] Error getting store settings: $e');
      return StoreSettings(address: _defaultShopAddress);
    }
  }

  /// Format transaction ID for display
  /// Format: TRX-ddMM-XXXX (last 4 chars of original ID)
  String formatTransactionId(String? originalId, DateTime timestamp) {
    if (originalId == null || originalId.isEmpty) {
      return 'TRX-${DateFormat('ddMM').format(timestamp)}-0000';
    }

    final datePrefix = DateFormat('ddMM').format(timestamp);
    final suffix = originalId.length >= 4
        ? originalId.substring(originalId.length - 4).toUpperCase()
        : originalId.toUpperCase().padLeft(4, '0');

    return 'TRX-$datePrefix-$suffix';
  }

  /// Scan for available Bluetooth devices
  Future<List<BluetoothDevice>> scanDevices() async {
    try {
      final devices = await _printer.getBondedDevices();
      debugPrint('[PrinterService] Found ${devices.length} bonded devices');
      return devices;
    } catch (e) {
      debugPrint('[PrinterService] Error scanning devices: $e');
      return [];
    }
  }

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable() async {
    try {
      return await _printer.isAvailable ?? false;
    } catch (e) {
      debugPrint('[PrinterService] Error checking Bluetooth: $e');
      return false;
    }
  }

  /// Check if Bluetooth is turned on
  Future<bool> isBluetoothOn() async {
    try {
      return await _printer.isOn ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Connect to a Bluetooth device
  Future<bool> connect(BluetoothDevice device) async {
    try {
      // Disconnect from current device first
      if (_isConnected) {
        await disconnect();
      }

      await _printer.connect(device);
      _connectedDevice = device;
      _isConnected = true;
      debugPrint('[PrinterService] Connected to ${device.name}');

      // Pre-cache logo for faster printing
      await _prepareLogo();

      return true;
    } catch (e) {
      debugPrint('[PrinterService] Error connecting: $e');
      _isConnected = false;
      _connectedDevice = null;
      return false;
    }
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    try {
      await _printer.disconnect();
      _connectedDevice = null;
      _isConnected = false;
      debugPrint('[PrinterService] Disconnected');
    } catch (e) {
      debugPrint('[PrinterService] Error disconnecting: $e');
    }
  }

  /// Check current connection status
  Future<bool> checkConnection() async {
    try {
      _isConnected = await _printer.isConnected ?? false;
      if (!_isConnected) {
        _connectedDevice = null;
      }
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  /// Prepare logo by copying asset to temp file and processing for thermal printer
  /// Resizes to 380px width and converts to grayscale for better print quality
  Future<void> _prepareLogo() async {
    try {
      if (_cachedLogoPath != null) {
        final file = File(_cachedLogoPath!);
        if (await file.exists()) {
          debugPrint('[PrinterService] Using cached logo: $_cachedLogoPath');
          return;
        }
      }

      // Load asset as bytes
      final ByteData data = await rootBundle.load(_logoAssetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Process image: resize and convert to grayscale
      final processedBytes = await _processLogoImage(bytes);

      // Write to temp directory
      final tempDir = await getTemporaryDirectory();
      final logoFile = File('${tempDir.path}/receipt_logo_processed.png');
      await logoFile.writeAsBytes(processedBytes);

      _cachedLogoPath = logoFile.path;
      debugPrint(
        '[PrinterService] Logo processed and cached at: $_cachedLogoPath',
      );
    } catch (e) {
      debugPrint('[PrinterService] Error preparing logo: $e');
      _cachedLogoPath = null;
    }
  }

  /// Process logo image: resize to 380px width and convert to grayscale
  Future<Uint8List> _processLogoImage(Uint8List bytes) async {
    return await compute(_processImageIsolate, bytes);
  }

  /// Isolate function to process image without blocking UI
  static Uint8List _processImageIsolate(Uint8List bytes) {
    // Decode the image
    final img.Image? original = img.decodeImage(bytes);
    if (original == null) {
      return bytes; // Return original if decode fails
    }

    // Resize to 380px width (optimal for 58mm thermal printer)
    const int targetWidth = 380;
    final int targetHeight = (original.height * targetWidth / original.width)
        .round();
    final img.Image resized = img.copyResize(
      original,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Convert to grayscale for better thermal print quality
    final img.Image grayscale = img.grayscale(resized);

    // Encode back to PNG
    return Uint8List.fromList(img.encodePng(grayscale));
  }

  /// Format currency to Rupiah string
  String _formatRupiah(double value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(value);
  }

  /// Print a transaction receipt with logo, dynamic address and Wi-Fi footer
  /// Returns true if print was successful
  Future<bool> printReceipt(ReceiptData receipt) async {
    try {
      // Check connection
      if (!await checkConnection()) {
        debugPrint('[PrinterService] Printer not connected');
        return false;
      }

      // Get dynamic settings from SharedPreferences
      final wifiSettings = await getWifiSettings();
      final storeSettings = await getStoreSettings();

      final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

      // --- LOGO ---
      _printer.printNewLine();
      if (_cachedLogoPath != null) {
        try {
          // Print logo image centered
          _printer.printImage(_cachedLogoPath!);
          _printer.printNewLine();
          debugPrint('[PrinterService] Logo printed');
        } catch (e) {
          debugPrint('[PrinterService] Logo print failed: $e');
          // Continue without logo
        }
      }

      // --- HEADER ---
      _printer.printCustom(_storeName, 3, 1); // Size 3, Center
      _printer.printCustom(storeSettings.address, 1, 1); // Dynamic address
      _printer.printCustom(dateFormat.format(receipt.timestamp), 1, 1);

      // Transaction ID (formatted)
      if (receipt.transactionId != null) {
        final formattedId = formatTransactionId(
          receipt.transactionId,
          receipt.timestamp,
        );
        _printer.printCustom('#$formattedId', 0, 1);
      }
      _printer.printNewLine();

      // --- SEPARATOR ---
      _printer.printCustom("--------------------------------", 1, 1);

      // --- ITEMS ---
      for (final item in receipt.items) {
        final qty = item.qty > 0 ? item.qty : 1;
        final subtotal = item.price * qty;

        // Product name
        _printer.printCustom(item.name, 1, 0); // Left align
        // Qty x Price = Subtotal
        _printer.printLeftRight(
          "$qty x ${_formatRupiah(item.price)}",
          _formatRupiah(subtotal),
          1,
        );
      }

      // --- SEPARATOR ---
      _printer.printCustom("--------------------------------", 1, 1);

      // --- TOTAL ---
      _printer.printLeftRight(
        "TOTAL",
        "Rp ${_formatRupiah(receipt.totalAmount)}",
        2, // Bold
      );

      // --- PAYMENT METHOD ---
      final paymentDisplay = receipt.paymentMethod.toUpperCase() == 'QRIS'
          ? 'QRIS'
          : receipt.paymentMethod.toUpperCase();
      _printer.printCustom("Bayar: $paymentDisplay", 1, 0);

      // --- SEPARATOR ---
      _printer.printCustom("--------------------------------", 1, 1);

      // --- FOOTER (Dynamic Wi-Fi) ---
      _printer.printNewLine();
      _printer.printCustom("Terima Kasih!", 2, 1); // Bold, Center

      // Print Wi-Fi info if available
      if (wifiSettings.isNotEmpty) {
        _printer.printCustom("Wi-Fi: ${wifiSettings.ssid}", 1, 1);
        _printer.printCustom("Pass: ${wifiSettings.password}", 1, 1);
      }

      // Feed and cut
      _printer.printNewLine();
      _printer.printNewLine();
      _printer.printNewLine();
      _printer.paperCut();

      debugPrint(
        '[PrinterService] Receipt printed successfully with dynamic footer',
      );
      return true;
    } catch (e) {
      debugPrint('[PrinterService] Error printing receipt: $e');
      return false;
    }
  }

  /// Print a test receipt with dynamic settings
  Future<bool> printTestReceipt() async {
    // Ensure logo is prepared
    await _prepareLogo();

    final testReceipt = ReceiptData(
      transactionId: 'TEST-001',
      items: [
        Product(
          id: 'test1',
          name: 'Es Kopi Susu',
          description: 'Test',
          price: 18000,
          category: 'Minuman',
          qty: 2,
        ),
        Product(
          id: 'test2',
          name: 'Roti Bakar',
          description: 'Test',
          price: 15000,
          category: 'Makanan',
          qty: 1,
        ),
      ],
      totalAmount: 51000,
      paymentMethod: 'cash',
    );

    return await printReceipt(testReceipt);
  }

  /// Print transaction from TransactionResult data
  Future<bool> printTransaction({
    required List<Product> items,
    required double totalAmount,
    required String paymentMethod,
    String? transactionId,
  }) async {
    // Ensure logo is prepared
    await _prepareLogo();

    final receipt = ReceiptData(
      transactionId: transactionId,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
    );

    return await printReceipt(receipt);
  }
}
