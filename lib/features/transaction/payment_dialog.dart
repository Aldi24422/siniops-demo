import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_notification_listener/flutter_notification_listener.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/product_model.dart';
import '../../core/services/notification_controller.dart';
import '../../core/services/transaction_controller.dart';
import '../../core/services/mock_transaction_controller.dart';
import '../../core/services/preview_mode_controller.dart';
import '../../core/services/printer_service.dart';
import '../receipt/receipt_preview_widget.dart';

/// Multi-Payment Dialog with QRIS and Cash tabs
/// QRIS tab preserves existing notification listener logic exactly
class PaymentDialog extends StatefulWidget {
  final double amount;

  final List<Product> cartItems;
  final String? staffUid;
  final String? staffName;

  const PaymentDialog({
    super.key,
    required this.amount,
    required this.cartItems,

    this.staffUid,
    this.staffName,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

/// Custom formatter that adds thousand separators (dots)
/// Example: 50000 -> 50.000, 100000 -> 100.000
class _ThousandSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digit characters
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Format with thousand separators
    final formatted = _formatWithDots(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatWithDots(String digits) {
    final buffer = StringBuffer();
    final length = digits.length;

    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }
}

class _PaymentDialogState extends State<PaymentDialog>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Tab Controller
  late TabController _tabController;

  // Shared state
  bool _isLoading = false;
  bool _isDisposed = false;

  // QRIS Tab State (PRESERVED FROM ORIGINAL)
  String _debugLog = "Silakan scan QR code untuk membayar";
  StreamSubscription<NotificationEvent>? _subscription;
  Timer? _timeoutTimer;
  bool _isReturningFromSettings = false;
  bool _autoPrint = true;

  // Cash Tab State
  final TextEditingController _cashReceivedController = TextEditingController();
  double _cashReceived = 0;
  double get _changeAmount => _cashReceived - widget.amount;
  bool get _isCashSufficient => _cashReceived >= widget.amount;

  // Controllers
  final TransactionController _transactionController = TransactionController();
  final MockTransactionController _mockTransactionController =
      MockTransactionController();
  final PrinterService _printerService = PrinterService.instance;

  bool get _isPreviewMode => PreviewModeController.instance.isPreviewMode;

  /// Detection timeout duration - show manual validation after this
  static const Duration _detectionTimeout = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _startListening();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.dispose();
    _cashReceivedController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _timeoutTimer?.cancel();
    _stopListening();
    super.dispose();
  }

  // ============================================================
  // NOTIFICATION LISTENER LOGIC (PRESERVED 100% FROM ORIGINAL)
  // ============================================================

  /// Handle app lifecycle changes - crucial for returning from Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      // User is leaving the app (possibly to Settings)
      _isReturningFromSettings = true;
      debugPrint(
        '[PaymentDialog] App paused, marking for potential Settings return',
      );
    } else if (state == AppLifecycleState.resumed && _isReturningFromSettings) {
      // User returned from Settings or background
      _isReturningFromSettings = false;
      debugPrint(
        '[PaymentDialog] App resumed, attempting to reinitialize listener',
      );
      _handleResumeFromSettings();
    }
  }

  /// Safe re-initialization after returning from Settings
  Future<void> _handleResumeFromSettings() async {
    if (!mounted || _isDisposed) return;

    setState(() {
      _debugLog = "Memeriksa izin notifikasi...";
    });

    try {
      final success = await NotificationController.instance
          .reinitializeIfNeeded();

      if (!mounted || _isDisposed) return;

      if (success) {
        // Re-subscribe to stream if not already subscribed
        _subscription ??= NotificationController.instance.notificationStream
            .listen(
              (event) => _processNotification(event),
              onError: (error) {
                debugPrint('[PaymentDialog] Stream error after resume: $error');
              },
            );

        setState(() {
          _debugLog = "✅ Siap menerima pembayaran...";
        });

        // Restart timeout timer
        _startTimeoutTimer();
      } else {
        setState(() {
          _debugLog =
              "Permission belum diberikan.\nSilakan aktifkan akses notifikasi di Settings.";
        });
      }
    } catch (e) {
      debugPrint('[PaymentDialog] Error in _handleResumeFromSettings: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _debugLog = "Error saat memeriksa izin: $e";
        });
      }
    }
  }

  void _startListening() async {
    try {
      // 1. Initialize Service (async, returns success status)
      final success = await NotificationController.instance.startListening();

      if (!success) {
        if (mounted && !_isDisposed) {
          setState(() {
            _debugLog =
                "Permission belum diberikan. Silakan aktifkan akses notifikasi.";
          });
        }
        return;
      }

      // 2. Listen to Stream with error handling
      _subscription = NotificationController.instance.notificationStream.listen(
        (event) {
          debugPrint(
            '[PaymentDialog] Stream received event: ${event.packageName} - ${event.title}',
          );
          _processNotification(event);
        },
        onError: (error) {
          debugPrint('[PaymentDialog] Stream error: $error');
          if (mounted && !_isDisposed) {
            setState(() {
              _debugLog = "Error: $error";
            });
          }
        },
        onDone: () {
          debugPrint('[PaymentDialog] Stream is DONE/CLOSED');
        },
      );

      // 3. Start timeout timer
      _startTimeoutTimer();

      if (mounted && !_isDisposed) {
        setState(() {
          _debugLog = "Siap menerima pembayaran...";
        });
      }
    } catch (e, stack) {
      // CRITICAL: Catch any native/plugin crash and prevent app crash
      debugPrint('[PaymentDialog] CRITICAL ERROR in _startListening: $e');
      debugPrint('$stack');

      if (mounted && !_isDisposed) {
        setState(() {
          _debugLog =
              "Error inisialisasi listener: $e\nGunakan validasi manual.";
        });

        // Show snackbar to inform user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "⚠️ Listener gagal dimulai. Gunakan validasi manual.",
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_detectionTimeout, () {
      if (mounted && !_isDisposed) {
        setState(() {
          _debugLog =
              "Timeout: Tidak ada pembayaran terdeteksi dalam 5 menit.\nGunakan validasi manual jika sudah membayar.";
        });
      }
    });
  }

  Future<void> _stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    // Note: Don't stop the controller here as other dialogs might use it
  }

  /// Process incoming notification with improved currency parsing.
  void _processNotification(NotificationEvent event) {
    if (!mounted || _isDisposed) return;

    final String packageName = event.packageName ?? "";
    final String title = event.title ?? "";
    final String body = event.text ?? "";

    // Filter Loop (Abaikan notif dari aplikasi sendiri)
    if (packageName.contains("siniops")) return;

    // Don't show raw package name to user - just log for debugging
    debugPrint(
      '[PaymentDialog] Notification from: $packageName - $title - $body',
    );

    // Parse currency amounts from text with improved regex
    final List<double> amountsInBody = _extractCurrencyAmounts(body);
    final List<double> amountsInTitle = _extractCurrencyAmounts(title);
    final double targetAmount = widget.amount;

    // Check for exact match (with small tolerance for rounding)
    bool isMatch = amountsInBody.any(
      (amount) => _isAmountMatch(amount, targetAmount),
    );
    if (!isMatch) {
      isMatch = amountsInTitle.any(
        (amount) => _isAmountMatch(amount, targetAmount),
      );
    }

    if (isMatch) {
      // AUTO DETECTION: Execute transaction!
      setState(() {
        _debugLog = "💰 Pembayaran terdeteksi! Memproses transaksi...";
      });
      _executeTransaction(paymentMethod: 'qris');
    }
  }

  /// Extract currency amounts from text string.
  /// Smart parsing that handles various Indonesian e-wallet and bank notification formats.
  List<double> _extractCurrencyAmounts(String text) {
    final List<double> amounts = [];
    final Set<String> processedKeys = {};

    void addAmount(double? amount) {
      if (amount != null && amount > 0) {
        final key = amount.toStringAsFixed(2);
        if (!processedKeys.contains(key)) {
          processedKeys.add(key);
          amounts.add(amount);
        }
      }
    }

    // Pattern 1: Indonesian Rupiah with Rp/IDR prefix
    final regexIDR = RegExp(
      r'(?:Rp\.?|IDR)\s*([\d.,\s]+)',
      caseSensitive: false,
    );
    for (final match in regexIDR.allMatches(text)) {
      String numStr = (match.group(1) ?? "").trim();
      numStr = numStr.replaceAll(RegExp(r'[.,\-]+$'), '');
      numStr = numStr.replaceAll(' ', '');
      final amount = _parseNumber(numStr);
      addAmount(amount);
    }

    // Pattern 2: International format (USD)
    final regexIntl = RegExp(r'(?:\$|USD)\s*([\d.,]+)', caseSensitive: false);
    for (final match in regexIntl.allMatches(text)) {
      String numStr = match.group(1) ?? "";
      numStr = numStr.replaceAll(',', '');
      addAmount(double.tryParse(numStr));
    }

    // Pattern 3: Amount with connector words (sejumlah, sebesar, senilai)
    final regexWithConnector = RegExp(
      r'(?:sebesar|sejumlah|senilai)\s*:?\s*([\d.,]+)',
      caseSensitive: false,
    );
    for (final match in regexWithConnector.allMatches(text)) {
      String numStr = match.group(1) ?? "";
      final amount = _parseNumber(numStr);
      addAmount(amount);
    }

    // Pattern 4: Contextual keywords followed directly by amounts
    final regexContextual = RegExp(
      r'(?:nominal|transfer|bayar|terima|masuk|total|jumlah|saldo|kredit|mutasi|diterima|dikreditkan|ditransfer)\s*:?\s*\+?\s*([\d.,]+)',
      caseSensitive: false,
    );
    for (final match in regexContextual.allMatches(text)) {
      String numStr = match.group(1) ?? "";
      final amount = _parseNumber(numStr);
      addAmount(amount);
    }

    // Pattern 5: E-wallet specific formats
    final regexEwallet = RegExp(
      r'(?:dana|gopay|ovo|shopeepay|linkaja|qris)\s+(?:masuk|diterima|berhasil|sukses|bertambah).*?([\d.,]+)',
      caseSensitive: false,
    );
    for (final match in regexEwallet.allMatches(text)) {
      String numStr = match.group(1) ?? "";
      final amount = _parseNumber(numStr);
      addAmount(amount);
    }

    // Pattern 6: Bank notification formats
    final regexBank = RegExp(
      r'(?:CR|kredit|debit|mutasi)\s*:?\s*(?:Rp\.?\s*)?([\d.,]+)',
      caseSensitive: false,
    );
    for (final match in regexBank.allMatches(text)) {
      String numStr = match.group(1) ?? "";
      final amount = _parseNumber(numStr);
      addAmount(amount);
    }

    // Pattern 7: Fallback - any standalone large number
    final regexFallback = RegExp(r'\b([\d]{1,3}(?:[.,][\d]{3})+)\b');
    for (final match in regexFallback.allMatches(text)) {
      String numStr = match.group(1) ?? "";
      final amount = _parseNumber(numStr);
      if (amount != null && amount >= 1000) {
        addAmount(amount);
      }
    }

    return amounts;
  }

  double? _parseNumber(String numStr) {
    if (numStr.isEmpty) return null;

    if (numStr.contains('.') && numStr.contains(',')) {
      final lastDot = numStr.lastIndexOf('.');
      final lastComma = numStr.lastIndexOf(',');

      if (lastComma > lastDot) {
        final cleaned = numStr.replaceAll('.', '').replaceAll(',', '.');
        return double.tryParse(cleaned);
      } else {
        final cleaned = numStr.replaceAll(',', '');
        return double.tryParse(cleaned);
      }
    }

    if (numStr.contains('.') && !numStr.contains(',')) {
      final parts = numStr.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        return double.tryParse(numStr);
      }
      final cleaned = numStr.replaceAll('.', '');
      return double.tryParse(cleaned);
    }

    if (numStr.contains(',') && !numStr.contains('.')) {
      final parts = numStr.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        final cleaned = numStr.replaceAll(',', '.');
        return double.tryParse(cleaned);
      }
      final cleaned = numStr.replaceAll(',', '');
      return double.tryParse(cleaned);
    }

    return double.tryParse(numStr);
  }

  bool _isAmountMatch(double parsed, double target) {
    return (parsed - target).abs() <= 1;
  }

  // ============================================================
  // CENTRALIZED TRANSACTION EXECUTION
  // ============================================================

  /// Execute transaction for both QRIS and Cash
  Future<void> _executeTransaction({
    required String paymentMethod,
    double? cashReceived,
    double? changeAmount,
  }) async {
    if (_isLoading || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = _isPreviewMode
          ? await _mockTransactionController.processTransaction(
              cartItems: widget.cartItems,
              totalAmount: widget.amount,
              paymentMethod: paymentMethod,
              staffUid: widget.staffUid,
              cashReceived: cashReceived,
              changeAmount: changeAmount,
            )
          : await _transactionController.processTransaction(
              cartItems: widget.cartItems,
              totalAmount: widget.amount,
              paymentMethod: paymentMethod,
              staffUid: widget.staffUid,
              cashReceived: cashReceived,
              changeAmount: changeAmount,
            );

      if (!mounted || _isDisposed) return;

      if (result.success) {
        // SUCCESS: Show receipt preview dialog
        if (!mounted) return;

        // Show receipt preview first
        await _showReceiptPreviewDialog(
          result.transactionId,
          paymentMethod,
          cashReceived,
          changeAmount,
          widget.staffName,
        );

        // Reset loading state AFTER receipt dialog closes
        if (mounted && !_isDisposed) {
          setState(() => _isLoading = false);
        }

        // Show low stock warnings AFTER receipt dialog (non-blocking)
        if (result.hasWarnings && mounted && !_isDisposed) {
          _showLowStockWarningDialog(result.warnings);
        }
      } else {
        // FAILED: Show error and keep dialog open
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ ${result.message}"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ Error: $e"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show low stock warning dialog (non-blocking)
  void _showLowStockWarningDialog(List<String> warnings) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Perhatian: Stok Rendah",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Transaksi berhasil, namun beberapa bahan stoknya kurang. Segera update stok bahan!",
              style: GoogleFonts.lexendDeca(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: warnings
                    .map(
                      (w) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          "• $w",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 12,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text("Mengerti"),
          ),
        ],
      ),
    );
  }

  /// Show printer picker popup when printer is offline
  /// Allows user to quickly connect to a paired printer
  Future<void> _showPrinterPickerDialog(StateSetter setDialogState) async {
    // First try auto-reconnect
    final autoConnected = await _printerService.autoReconnect();
    if (autoConnected) {
      setDialogState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "✅ Terhubung ke ${_printerService.connectedDevice?.name ?? 'printer'}",
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show device picker dialog
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setPickerState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.bluetooth, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    "Pilih Printer",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: FutureBuilder<List<PrinterDevice>>(
                future: _printerService.scanDevices(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text("Mencari printer..."),
                          ],
                        ),
                      ),
                    );
                  }

                  final devices = snapshot.data ?? [];

                  if (devices.isEmpty) {
                    return SizedBox(
                      height: 100,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.print_disabled,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tidak ada printer ditemukan",
                              style: GoogleFonts.lexendDeca(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Pair printer via Pengaturan Bluetooth",
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.background,
                            child: Icon(Icons.print, color: AppColors.primary),
                          ),
                          title: Text(
                            device.name,
                            style: GoogleFonts.lexendDeca(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            device.address,
                            style: GoogleFonts.lexendDeca(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          onTap: () async {
                            Navigator.pop(dialogContext);

                            // Capture messenger before async gap
                            final messenger = ScaffoldMessenger.of(context);

                            // Show connecting snackbar
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Menghubungkan ke ${device.name}...",
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );

                            final result = await _printerService
                                .connectWithRetry(device);

                            if (mounted) {
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    result.success
                                        ? "✅ ${result.message}"
                                        : "❌ ${result.message}",
                                  ),
                                  backgroundColor: result.success
                                      ? AppColors.success
                                      : AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );

                              // Update parent dialog state to refresh button
                              setDialogState(() {});
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Batal"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show receipt preview dialog after successful transaction
  Future<void> _showReceiptPreviewDialog(
    String? transactionId,
    String paymentMethod,
    double? cashReceived,
    double? changeAmount,
    String? staffName,
  ) async {
    bool isPrinting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Transaksi Berhasil!",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Receipt Preview (Scrollable)
                Flexible(
                  child: Container(
                    color: AppColors.background,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ReceiptPreviewWidget(
                        items: widget.cartItems,
                        totalAmount: widget.amount,
                        paymentMethod: paymentMethod,
                        transactionId: transactionId,
                        cashReceived: cashReceived,
                        changeAmount: changeAmount,
                      ),
                    ),
                  ),
                ),

                // Action Buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Close Button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            Navigator.pop(
                              context,
                              true,
                            ); // Close Payment dialog & signal cart reset
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppColors.textSecondary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Tutup",
                            style: GoogleFonts.lexendDeca(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Print Button - always clickable
                      // When offline: opens printer picker
                      // When online: prints the receipt
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: isPrinting
                              ? null
                              : () async {
                                  // If not connected, show printer picker
                                  if (!_printerService.isConnected) {
                                    await _showPrinterPickerDialog(
                                      setDialogState,
                                    );
                                    return;
                                  }

                                  // Print the receipt
                                  setDialogState(() => isPrinting = true);
                                  try {
                                    final success = await _printerService
                                        .printTransaction(
                                          items: widget.cartItems,
                                          totalAmount: widget.amount,
                                          paymentMethod: paymentMethod,
                                          transactionId: transactionId,
                                          cashReceived: cashReceived,
                                          changeAmount: changeAmount,
                                          staffName: staffName,
                                        );

                                    if (!context.mounted) return;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? "✅ Struk berhasil dicetak!"
                                              : "❌ Gagal mencetak struk",
                                        ),
                                        backgroundColor: success
                                            ? AppColors.success
                                            : AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text("❌ Error: $e"),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } finally {
                                    if (context.mounted) {
                                      setDialogState(() => isPrinting = false);
                                    }
                                  }
                                },
                          icon: isPrinting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _printerService.isConnected
                                      ? Icons.print
                                      : Icons.bluetooth_searching,
                                ),
                          label: Text(
                            isPrinting
                                ? "Mencetak..."
                                : _printerService.isConnected
                                ? "Cetak Struk"
                                : "Hubungkan Printer",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HELPER METHODS
  // ============================================================

  String formatRupiah(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  void _handleCheckStatus() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _isDisposed) return;
    setState(() => _isLoading = false);
    _showManualValidationDialog();
  }

  void _showManualValidationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 10),
            Text("Konfirmasi Manual"),
          ],
        ),
        content: const Text(
          "Jika dana sudah masuk di mutasi, tekan 'Ya' untuk mencetak struk.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // EXECUTE TRANSACTION on manual confirm!
              _executeTransaction(paymentMethod: 'qris');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text(
              "Ya, Cetak",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _handleCashInput(String value) {
    setState(() {
      _cashReceived = double.tryParse(value.replaceAll('.', '')) ?? 0;
    });
  }

  void _setExactAmount() {
    setState(() {
      _cashReceived = widget.amount;
      _cashReceivedController.text = formatRupiah(widget.amount);
    });
  }

  void _handleCashPayment() {
    if (!_isCashSufficient) return;
    _executeTransaction(
      paymentMethod: 'cash',
      cashReceived: _cashReceived,
      changeAmount: _changeAmount,
    );
  }

  // ============================================================
  // BUILD METHODS
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;
    final isDesktop = screenWidth >= 1024;

    final dialogPadding = isDesktop ? 40.0 : (isTablet ? 32.0 : 24.0);

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 500 : (isTablet ? 420 : 380),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tab Bar Header
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelStyle: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                unselectedLabelStyle: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_2_rounded), text: "QRIS"),
                  Tab(icon: Icon(Icons.payments_outlined), text: "TUNAI"),
                ],
              ),
            ),

            // Tab Content
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildQrisTab(dialogPadding, isTablet, isDesktop),
                  _buildCashTab(dialogPadding, isTablet, isDesktop),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QRIS TAB (PRESERVED FROM ORIGINAL)
  // ============================================================

  Widget _buildQrisTab(double dialogPadding, bool isTablet, bool isDesktop) {
    final qrSize = isDesktop ? 280.0 : (isTablet ? 240.0 : 200.0);
    final titleFontSize = isDesktop ? 22.0 : (isTablet ? 20.0 : 18.0);
    final amountFontSize = isDesktop ? 56.0 : (isTablet ? 52.0 : 48.0);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.primary,
                  size: isDesktop ? 28 : 24,
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Text(
                  "Scan to Pay",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: titleFontSize,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 28 : 20),

            // QR CODE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: QrImageView(
                data: AppConstants.rawQrisData,
                version: QrVersions.auto,
                size: qrSize,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.primary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: isDesktop ? 24 : 16),

            // TOTAL TAGIHAN
            Text(
              "Total Tagihan",
              style: GoogleFonts.lexendDeca(
                color: AppColors.textSecondary,
                fontSize: isTablet ? 16 : 14,
              ),
            ),
            Text(
              "Rp ${formatRupiah(widget.amount)}",
              style: GoogleFonts.dongle(
                fontSize: amountFontSize,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
                height: 0.9,
              ),
            ),

            SizedBox(height: isDesktop ? 16 : 10),

            // DEBUG VIEWER
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: NotificationController.instance.isListening
                              ? AppColors.success
                              : AppColors.gold,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (NotificationController.instance.isListening
                                          ? AppColors.success
                                          : AppColors.gold)
                                      .withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NotificationController.instance.isListening
                            ? "Menunggu Pembayaran"
                            : "Menyiapkan...",
                        style: TextStyle(
                          fontSize: isTablet ? 12 : 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Divider(color: AppColors.accent, height: 20),
                  Text(
                    _debugLog,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isTablet ? 12 : 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 28 : 20),

            // AUTO-PRINT TOGGLE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _printerService.isConnected
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.accent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _printerService.isConnected
                        ? Icons.print
                        : Icons.print_disabled,
                    color: _printerService.isConnected
                        ? AppColors.success
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Cetak Struk Otomatis",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _printerService.isConnected
                              ? "Printer terhubung"
                              : "Printer tidak terhubung",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 11,
                            color: _printerService.isConnected
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoPrint && _printerService.isConnected,
                    onChanged: _printerService.isConnected
                        ? (val) => setState(() => _autoPrint = val)
                        : null,
                    activeTrackColor: AppColors.success,
                  ),
                ],
              ),
            ),

            SizedBox(height: isTablet ? 16 : 12),

            // TOMBOL MANUAL
            SizedBox(
              width: double.infinity,
              height: isTablet ? 56 : 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleCheckStatus,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.8),
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        "Cek Status / Manual",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isTablet ? 17 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            SizedBox(height: isTablet ? 16 : 12),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                "Tutup",
                style: TextStyle(fontSize: isTablet ? 15 : 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CASH TAB (NEW FEATURE)
  // ============================================================

  Widget _buildCashTab(double dialogPadding, bool isTablet, bool isDesktop) {
    final amountFontSize = isDesktop ? 56.0 : (isTablet ? 52.0 : 48.0);

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(dialogPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: AppColors.primary,
                  size: isDesktop ? 28 : 24,
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Text(
                  "Pembayaran Tunai",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 22.0 : (isTablet ? 20.0 : 18.0),
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: isDesktop ? 28 : 20),

            // TOTAL TAGIHAN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    "Total Tagihan",
                    style: GoogleFonts.lexendDeca(
                      color: AppColors.textSecondary,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                  Text(
                    "Rp ${formatRupiah(widget.amount)}",
                    style: GoogleFonts.dongle(
                      fontSize: amountFontSize,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 0.9,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 24 : 16),

            // INPUT UANG DITERIMA
            TextField(
              controller: _cashReceivedController,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandSeparatorInputFormatter()],
              onChanged: _handleCashInput,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: "Uang Diterima",
                labelStyle: GoogleFonts.lexendDeca(
                  color: AppColors.textSecondary,
                ),
                prefixText: "Rp ",
                prefixStyle: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // UANG PAS BUTTON
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _setExactAmount,
                icon: const Icon(Icons.check_circle_outline),
                label: Text("Uang Pas (Rp ${formatRupiah(widget.amount)})"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // KEMBALIAN
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isCashSufficient
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCashSufficient
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isCashSufficient ? "Kembalian:" : "Kurang:",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _isCashSufficient
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  Text(
                    "Rp ${formatRupiah(_changeAmount.abs())}",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _isCashSufficient
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: isDesktop ? 28 : 20),

            // BAYAR BUTTON
            SizedBox(
              width: double.infinity,
              height: isTablet ? 56 : 50,
              child: ElevatedButton.icon(
                onPressed: _isCashSufficient && !_isLoading
                    ? _handleCashPayment
                    : null,
                icon: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.8),
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.receipt_long),
                label: Text(
                  _isLoading ? "Memproses..." : "Bayar & Cetak",
                  style: TextStyle(
                    fontSize: isTablet ? 17 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),

            SizedBox(height: isTablet ? 16 : 12),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
              ),
              child: Text(
                "Tutup",
                style: TextStyle(fontSize: isTablet ? 15 : 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
