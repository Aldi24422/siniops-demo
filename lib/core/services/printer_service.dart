import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import '../models/product_model.dart';

// =============================================================================
// DATA MODELS
// =============================================================================

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
  final double? cashReceived;
  final double? changeAmount;
  final String? staffName;

  ReceiptData({
    this.transactionId,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    DateTime? timestamp,
    this.cashReceived,
    this.changeAmount,
    this.staffName,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Permission check result
enum PermissionResult { granted, denied, permanentlyDenied }

/// Connection result with detailed status
class ConnectionResult {
  final bool success;
  final String message;
  final String? deviceName;

  ConnectionResult({
    required this.success,
    required this.message,
    this.deviceName,
  });
}

/// Bluetooth device info wrapper
class PrinterDevice {
  final String name;
  final String address;

  PrinterDevice({required this.name, required this.address});

  @override
  String toString() => 'PrinterDevice(name: $name, address: $address)';
}

// =============================================================================
// DANTSU-STYLE PRINTER SERVICE
// =============================================================================

/// Singleton service for Bluetooth thermal printer operations
/// Implements Dantsu ESCPOS library logic for stable connection and printing
class PrinterService {
  // Singleton pattern
  static final PrinterService _instance = PrinterService._internal();
  static PrinterService get instance => _instance;
  PrinterService._internal();

  // Connection state
  PrinterDevice? _connectedDevice;
  PrinterDevice? get connectedDevice => _connectedDevice;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // Cached logo bytes
  Uint8List? _cachedLogoBytes;

  // Store settings
  static const String _storeName = "SINI.NGOPI";
  static const String _logoAssetPath = 'assets/images/logo.png';

  // Paper width for 58mm thermal printer
  // 58mm paper = ~48mm printable area = 384 dots max
  // Using 140 for smaller, compact logo
  static const int _logoTargetWidth = 140;

  // SharedPreferences keys
  static const String _keyWifiSsid = 'receipt_wifi_ssid';
  static const String _keyWifiPass = 'receipt_wifi_password';
  static const String _keyShopAddress = 'shop_address';
  static const String _keySavedPrinterName = 'saved_printer_name';
  static const String _keySavedPrinterAddress = 'saved_printer_address';

  // Default values
  static const String _defaultWifiSsid = 'SiniNgopi';
  static const String _defaultWifiPass = 'kopi123';
  static const String _defaultShopAddress = 'Jl. Contoh No. 123, Surabaya';

  // ===========================================================================
  // PERMISSION HANDLING (Hybrid: Library native + permission_handler fallback)
  // ===========================================================================

  /// Check permissions using library's native check which AUTO-REQUESTS on Android 12+
  /// This is more reliable than permission_handler for Bluetooth permissions
  Future<PermissionResult> checkBluetoothPermissions() async {
    try {
      debugPrint('[PrinterService] Checking Bluetooth permissions...');

      // First, use library's native permission check
      // This will AUTO-TRIGGER permission dialog on Android 12+
      final bool isGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      debugPrint('[PrinterService] Library permission check: $isGranted');

      if (isGranted) {
        debugPrint(
          '[PrinterService] Bluetooth permissions granted (native check)',
        );
        return PermissionResult.granted;
      }

      // If native check fails, check with permission_handler for detailed status
      final connectStatus = await Permission.bluetoothConnect.status;
      final scanStatus = await Permission.bluetoothScan.status;

      debugPrint(
        '[PrinterService] permission_handler: connect=$connectStatus, scan=$scanStatus',
      );

      // Check if permanently denied
      if (connectStatus.isPermanentlyDenied || scanStatus.isPermanentlyDenied) {
        debugPrint('[PrinterService] Permission permanently denied');
        return PermissionResult.permanentlyDenied;
      }

      // Try requesting with permission_handler as fallback
      debugPrint(
        '[PrinterService] Requesting permissions via permission_handler...',
      );
      final results = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.bluetooth, // For older Android versions
      ].request();

      debugPrint('[PrinterService] Request results: $results');

      // Verify with library again after permission request
      final bool recheckGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      debugPrint(
        '[PrinterService] Library recheck after request: $recheckGranted',
      );

      if (recheckGranted) {
        return PermissionResult.granted;
      }

      // Check if now permanently denied
      final newConnectStatus = await Permission.bluetoothConnect.status;
      final newScanStatus = await Permission.bluetoothScan.status;

      if (newConnectStatus.isPermanentlyDenied ||
          newScanStatus.isPermanentlyDenied) {
        return PermissionResult.permanentlyDenied;
      }

      return PermissionResult.denied;
    } catch (e) {
      debugPrint('[PrinterService] Error checking permissions: $e');
      return PermissionResult.denied;
    }
  }

  /// Alias for backward compatibility
  Future<PermissionResult> checkAndRequestBluetoothPermissions() async {
    return await checkBluetoothPermissions();
  }

  /// Check if permissions are granted without requesting
  Future<bool> hasBluetoothPermissions() async {
    final connect = await Permission.bluetoothConnect.status;
    final scan = await Permission.bluetoothScan.status;
    return connect.isGranted && scan.isGranted;
  }

  // ===========================================================================
  // SETTINGS MANAGEMENT
  // ===========================================================================

  Future<bool> saveWifiSettings(String ssid, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyWifiSsid, ssid);
      await prefs.setString(_keyWifiPass, password);
      return true;
    } catch (e) {
      debugPrint('[PrinterService] Error saving Wi-Fi settings: $e');
      return false;
    }
  }

  Future<WifiSettings> getWifiSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return WifiSettings(
        ssid: prefs.getString(_keyWifiSsid) ?? _defaultWifiSsid,
        password: prefs.getString(_keyWifiPass) ?? _defaultWifiPass,
      );
    } catch (e) {
      return WifiSettings(ssid: _defaultWifiSsid, password: _defaultWifiPass);
    }
  }

  Future<bool> saveShopAddress(String address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyShopAddress, address);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<StoreSettings> getStoreSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return StoreSettings(
        address: prefs.getString(_keyShopAddress) ?? _defaultShopAddress,
      );
    } catch (e) {
      return StoreSettings(address: _defaultShopAddress);
    }
  }

  Future<void> _saveLastPrinter(PrinterDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keySavedPrinterName, device.name);
      await prefs.setString(_keySavedPrinterAddress, device.address);
    } catch (e) {
      debugPrint('[PrinterService] Error saving last printer: $e');
    }
  }

  Future<PrinterDevice?> getLastPrinter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_keySavedPrinterName);
      final address = prefs.getString(_keySavedPrinterAddress);
      if (name != null && address != null) {
        return PrinterDevice(name: name, address: address);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

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

  // ===========================================================================
  // BLUETOOTH OPERATIONS (Dantsu-style)
  // ===========================================================================

  /// Check if Bluetooth is enabled
  Future<bool> isBluetoothAvailable() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('[PrinterService] Error checking Bluetooth: $e');
      return false;
    }
  }

  Future<bool> isBluetoothOn() async => await isBluetoothAvailable();

  /// Scan for paired Bluetooth devices
  /// Must call checkBluetoothPermissions() first!
  Future<List<PrinterDevice>> scanDevices() async {
    try {
      debugPrint('[PrinterService] Starting device scan...');

      // Verify Bluetooth is enabled
      final btEnabled = await PrintBluetoothThermal.bluetoothEnabled;
      debugPrint('[PrinterService] Bluetooth enabled: $btEnabled');

      if (!btEnabled) {
        debugPrint('[PrinterService] Bluetooth is OFF');
        return [];
      }

      // Get paired devices
      final List<BluetoothInfo> devices =
          await PrintBluetoothThermal.pairedBluetooths;
      debugPrint('[PrinterService] Found ${devices.length} paired devices');

      // Log each device
      for (var d in devices) {
        debugPrint('[PrinterService]   - ${d.name}: ${d.macAdress}');
      }

      return devices
          .where((d) => d.macAdress.isNotEmpty)
          .map(
            (d) => PrinterDevice(
              name: d.name.isEmpty ? 'Unknown Device' : d.name,
              address: d.macAdress,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('[PrinterService] Error scanning: $e');
      return [];
    }
  }

  /// Connect to a Bluetooth printer
  Future<ConnectionResult> connect(PrinterDevice device) async {
    try {
      debugPrint(
        '[PrinterService] Connecting to ${device.name} (${device.address})...',
      );

      // Disconnect first if already connected
      if (_isConnected) {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Connect using library
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.address,
      );

      debugPrint('[PrinterService] Connection result: $result');

      if (result) {
        _connectedDevice = device;
        _isConnected = true;
        await _saveLastPrinter(device);

        // Pre-cache logo
        await _prepareLogo();

        return ConnectionResult(
          success: true,
          message: 'Terhubung ke ${device.name}',
          deviceName: device.name,
        );
      } else {
        return ConnectionResult(
          success: false,
          message:
              'Gagal terhubung. Pastikan printer menyala dan dalam jangkauan.',
        );
      }
    } catch (e) {
      debugPrint('[PrinterService] Connection error: $e');
      _isConnected = false;
      _connectedDevice = null;
      return ConnectionResult(success: false, message: 'Error: $e');
    }
  }

  /// Connect with retry mechanism
  Future<ConnectionResult> connectWithRetry(
    PrinterDevice device, {
    int maxRetries = 3,
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      debugPrint('[PrinterService] Connection attempt $attempt/$maxRetries');
      final result = await connect(device);
      if (result.success) return result;
      if (attempt < maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return ConnectionResult(
      success: false,
      message: 'Gagal terhubung setelah $maxRetries percobaan.',
    );
  }

  /// Auto-reconnect to last saved printer
  Future<bool> autoReconnect() async {
    try {
      if (await checkConnection()) return true;

      final lastPrinter = await getLastPrinter();
      if (lastPrinter == null) return false;

      final result = await connect(lastPrinter);
      return result.success;
    } catch (e) {
      return false;
    }
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _connectedDevice = null;
      _isConnected = false;
      debugPrint('[PrinterService] Disconnected');
    } catch (e) {
      debugPrint('[PrinterService] Disconnect error: $e');
    }
  }

  /// Check current connection status
  Future<bool> checkConnection() async {
    try {
      _isConnected = await PrintBluetoothThermal.connectionStatus;
      if (!_isConnected) _connectedDevice = null;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // ===========================================================================
  // DANTSU-STYLE IMAGE PROCESSING
  // ===========================================================================

  /// Initialize GS v 0 command header (from EscPosPrinterCommands.java)
  static Uint8List _initGSv0Command(int bytesByLine, int bitmapHeight) {
    final xH = bytesByLine ~/ 256;
    final xL = bytesByLine - (xH * 256);
    final yH = bitmapHeight ~/ 256;
    final yL = bitmapHeight - (yH * 256);

    final imageBytes = Uint8List(8 + bytesByLine * bitmapHeight);
    imageBytes[0] = 0x1D; // GS
    imageBytes[1] = 0x76; // v
    imageBytes[2] = 0x30; // 0
    imageBytes[3] = 0x00; // m = 0 (normal mode)
    imageBytes[4] = xL; // xL
    imageBytes[5] = xH; // xH
    imageBytes[6] = yL; // yL
    imageBytes[7] = yH; // yH

    return imageBytes;
  }

  /// Convert bitmap to ESC/POS bytes using Dantsu's algorithm
  /// This is a direct port of EscPosPrinterCommands.bitmapToBytes()
  static Uint8List _bitmapToBytes(img.Image bitmap, {bool gradient = true}) {
    final bitmapWidth = bitmap.width;
    final bitmapHeight = bitmap.height;
    final bytesByLine = (bitmapWidth / 8).ceil();

    final imageBytes = _initGSv0Command(bytesByLine, bitmapHeight);

    int i = 8;
    int greyscaleCoefficientInit = 0;
    const gradientStep = 6;
    const colorLevelStep = 765.0 / (15 * gradientStep + gradientStep - 1);

    for (int posY = 0; posY < bitmapHeight; posY++) {
      int greyscaleCoefficient = greyscaleCoefficientInit;
      final greyscaleLine = posY % gradientStep;

      for (int j = 0; j < bitmapWidth; j += 8) {
        int b = 0;

        for (int k = 0; k < 8; k++) {
          final posX = j + k;

          if (posX < bitmapWidth) {
            final pixel = bitmap.getPixel(posX, posY);
            final red = pixel.r.toInt();
            final green = pixel.g.toInt();
            final blue = pixel.b.toInt();

            final colorSum = red + green + blue;
            final threshold =
                (greyscaleCoefficient * gradientStep + greyscaleLine) *
                colorLevelStep;

            bool isBlack;
            if (gradient) {
              isBlack = colorSum < threshold;
            } else {
              isBlack = red < 160 || green < 160 || blue < 160;
            }

            if (isBlack) {
              b |= 1 << (7 - k);
            }

            greyscaleCoefficient += 5;
            if (greyscaleCoefficient > 15) {
              greyscaleCoefficient -= 16;
            }
          }
        }

        imageBytes[i++] = b;
      }

      greyscaleCoefficientInit += 2;
      if (greyscaleCoefficientInit > 15) {
        greyscaleCoefficientInit = 0;
      }
    }

    return imageBytes;
  }

  /// Prepare logo: load, resize, and convert to ESC/POS bytes
  Future<void> _prepareLogo() async {
    try {
      // Check if already cached
      if (_cachedLogoBytes != null && _cachedLogoBytes!.isNotEmpty) return;

      debugPrint('[PrinterService] Preparing logo...');

      // Load logo from assets
      final ByteData data = await rootBundle.load(_logoAssetPath);
      final Uint8List bytes = data.buffer.asUint8List();

      // Process in isolate
      _cachedLogoBytes = await compute(_processLogoIsolate, bytes);

      debugPrint(
        '[PrinterService] Logo prepared: ${_cachedLogoBytes!.length} bytes',
      );
    } catch (e) {
      debugPrint('[PrinterService] Error preparing logo: $e');
      _cachedLogoBytes = null;
    }
  }

  /// Isolate function for logo processing
  static Uint8List _processLogoIsolate(Uint8List bytes) {
    // Decode image
    final original = img.decodeImage(bytes);
    if (original == null) return Uint8List(0);

    // Calculate new height maintaining aspect ratio
    final targetHeight = (original.height * _logoTargetWidth / original.width)
        .round();

    // Resize image
    final resized = img.copyResize(
      original,
      width: _logoTargetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // Create a new image with WHITE background
    // This handles transparent PNGs correctly
    final withBackground = img.Image(
      width: resized.width,
      height: resized.height,
    );

    // Fill with white
    img.fill(withBackground, color: img.ColorRgb8(255, 255, 255));

    // Composite the logo on top of white background
    img.compositeImage(withBackground, resized);

    // Convert to grayscale
    final grayscale = img.grayscale(withBackground);

    // Convert to ESC/POS bytes using Dantsu algorithm
    // gradient: true = better quality with dithering
    // The algorithm treats DARK pixels as "print" (black dots)
    return _bitmapToBytes(grayscale, gradient: true);
  }

  // ===========================================================================
  // RECEIPT GENERATION
  // ===========================================================================

  String _formatRupiah(double value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    ).format(value);
  }

  /// Generate complete receipt bytes
  Future<List<int>> _generateReceiptBytes(ReceiptData receipt) async {
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);

      List<int> bytes = [];

      final wifiSettings = await getWifiSettings();
      final storeSettings = await getStoreSettings();
      final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

      // --- LOGO (Dantsu-style raw bytes) ---
      if (_cachedLogoBytes != null && _cachedLogoBytes!.isNotEmpty) {
        // ESC a 1 = Center alignment (0x1B, 0x61, 0x01)
        bytes.addAll([0x1B, 0x61, 0x01]);
        bytes.addAll(_cachedLogoBytes!);
        // Reset to left alignment after logo
        bytes.addAll([0x1B, 0x61, 0x00]);
      }

      // --- HEADER ---
      // Store name - normal size, bold, centered
      bytes += generator.text(
        _storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        storeSettings.address,
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        dateFormat.format(receipt.timestamp),
        styles: const PosStyles(align: PosAlign.center),
      );

      if (receipt.transactionId != null) {
        final formattedId = formatTransactionId(
          receipt.transactionId,
          receipt.timestamp,
        );
        bytes += generator.text(
          '#$formattedId',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      if (receipt.staffName != null) {
        bytes += generator.text(
          'Kasir: ${receipt.staffName}',
          styles: const PosStyles(align: PosAlign.left),
        );
      }

      bytes += generator.hr(ch: '-');

      // --- ITEMS ---
      for (final item in receipt.items) {
        final qty = item.qty > 0 ? item.qty : 1;
        final subtotal = item.price * qty;

        bytes += generator.text(item.name);
        bytes += generator.row([
          PosColumn(text: '$qty x ${_formatRupiah(item.price)}', width: 7),
          PosColumn(
            text: _formatRupiah(subtotal),
            width: 5,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr(ch: '-');

      // --- TOTAL ---
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'Rp ${_formatRupiah(receipt.totalAmount)}',
          width: 6,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);

      // --- PAYMENT DETAILS ---
      if (receipt.paymentMethod.toLowerCase() == 'cash' &&
          receipt.cashReceived != null) {
        bytes += generator.row([
          PosColumn(text: 'Tunai', width: 6),
          PosColumn(
            text: 'Rp ${_formatRupiah(receipt.cashReceived!)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        bytes += generator.row([
          PosColumn(text: 'Kembali', width: 6),
          PosColumn(
            text: 'Rp ${_formatRupiah(receipt.changeAmount ?? 0)}',
            width: 6,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      final paymentDisplay = receipt.paymentMethod.toUpperCase() == 'QRIS'
          ? 'QRIS'
          : receipt.paymentMethod.toUpperCase();
      bytes += generator.text('Bayar: $paymentDisplay');

      bytes += generator.hr(ch: '-');

      // --- FOOTER ---
      bytes += generator.text(
        'Terima Kasih!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      if (wifiSettings.isNotEmpty) {
        bytes += generator.text(
          'Wi-Fi: ${wifiSettings.ssid}',
          styles: const PosStyles(align: PosAlign.center),
        );
        bytes += generator.text(
          'Pass: ${wifiSettings.password}',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      // Direct cut, no extra spacing
      bytes += generator.cut();

      return bytes;
    } catch (e) {
      debugPrint('[PrinterService] Error generating receipt: $e');
      return [];
    }
  }

  // ===========================================================================
  // PRINTING OPERATIONS
  // ===========================================================================

  /// Print a receipt
  Future<bool> printReceipt(ReceiptData receipt) async {
    try {
      if (!await checkConnection()) {
        debugPrint('[PrinterService] Not connected');
        return false;
      }

      final bytes = await _generateReceiptBytes(receipt);
      if (bytes.isEmpty) {
        debugPrint('[PrinterService] Empty receipt bytes');
        return false;
      }

      debugPrint(
        '[PrinterService] Sending ${bytes.length} bytes to printer...',
      );

      // IMPORTANT: writeBytes expects List<int>, not Uint8List
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      debugPrint('[PrinterService] Print result: $result');
      return result;
    } catch (e) {
      debugPrint('[PrinterService] Print error: $e');
      return false;
    }
  }

  /// Print a test receipt
  Future<bool> printTestReceipt() async {
    await _prepareLogo();

    final testReceipt = ReceiptData(
      transactionId: 'TEST-001',
      items: [
        Product(
          id: 'test1',
          name: 'Es Kopi Susu',
          description: '',
          price: 18000,
          category: 'Minuman',
          qty: 2,
        ),
        Product(
          id: 'test2',
          name: 'Roti Bakar',
          description: '',
          price: 15000,
          category: 'Makanan',
          qty: 1,
        ),
      ],
      totalAmount: 51000,
      paymentMethod: 'cash',
      cashReceived: 100000,
      changeAmount: 49000,
      staffName: 'Test Staff',
    );

    return await printReceipt(testReceipt);
  }

  /// Print transaction
  Future<bool> printTransaction({
    required List<Product> items,
    required double totalAmount,
    required String paymentMethod,
    String? transactionId,
    double? cashReceived,
    double? changeAmount,
    String? staffName,
  }) async {
    await _prepareLogo();

    final receipt = ReceiptData(
      transactionId: transactionId,
      items: items,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      cashReceived: cashReceived,
      changeAmount: changeAmount,
      staffName: staffName,
    );

    return await printReceipt(receipt);
  }

  // ===========================================================================
  // DIAGNOSTICS
  // ===========================================================================

  /// Run diagnostic and return status
  Future<Map<String, dynamic>> runDiagnostic() async {
    final result = <String, dynamic>{};

    try {
      result['bluetoothEnabled'] = await PrintBluetoothThermal.bluetoothEnabled;
      result['permissionConnect'] = (await Permission.bluetoothConnect.status)
          .toString();
      result['permissionScan'] = (await Permission.bluetoothScan.status)
          .toString();

      final devices = await PrintBluetoothThermal.pairedBluetooths;
      result['pairedDevicesCount'] = devices.length;
      result['pairedDevices'] = devices
          .map((d) => '${d.name} (${d.macAdress})')
          .toList();

      result['isConnected'] = await PrintBluetoothThermal.connectionStatus;

      final savedPrinter = await getLastPrinter();
      result['savedPrinter'] = savedPrinter?.toString();

      result['success'] = true;
    } catch (e) {
      result['success'] = false;
      result['error'] = e.toString();
    }

    debugPrint('[PrinterService] Diagnostic: $result');
    return result;
  }
}
