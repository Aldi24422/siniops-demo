import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/services/printer_service.dart';

/// Reusable Receipt Preview Widget
/// Displays a visual representation of a thermal receipt with dynamic settings
class ReceiptPreviewWidget extends StatelessWidget {
  final List<Product> items;
  final double totalAmount;
  final String paymentMethod;
  final DateTime? timestamp;
  final String? transactionId;
  final double? cashReceived;

  final double? changeAmount;
  final String? staffName;
  final String? footer;

  const ReceiptPreviewWidget({
    super.key,
    required this.items,
    required this.totalAmount,
    required this.paymentMethod,
    this.timestamp,
    this.transactionId,
    this.cashReceived,

    this.changeAmount,
    this.staffName,
    this.footer,
  });

  // Store settings
  static const String _storeName = "SINI.NGOPI";

  String _formatRupiah(double value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  /// Format transaction ID to professional format
  /// Format: TRX-ddMM-XXXX (last 4 chars of original ID)
  String _formatTransactionId(String? originalId, DateTime displayTime) {
    if (originalId == null || originalId.isEmpty) {
      return 'TRX-${DateFormat('ddMM').format(displayTime)}-0000';
    }

    final datePrefix = DateFormat('ddMM').format(displayTime);
    final suffix = originalId.length >= 4
        ? originalId.substring(originalId.length - 4).toUpperCase()
        : originalId.toUpperCase().padLeft(4, '0');

    return 'TRX-$datePrefix-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
    final displayTime = timestamp ?? DateTime.now();

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // === HEADER SECTION (with dynamic address) ===
            FutureBuilder<StoreSettings>(
              future: PrinterService.instance.getStoreSettings(),
              builder: (context, storeSnapshot) {
                final storeAddress =
                    storeSnapshot.data?.address ??
                    'Jl. Contoh No. 123, Surabaya';

                return Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Logo
                      Image.asset(
                        'assets/images/logo.png',
                        height: 80,
                        width: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.storefront,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Store Name
                      Text(
                        _storeName,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Address (Dynamic)
                      Text(
                        storeAddress,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.lexendDeca(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Date/Time
                      Text(
                        dateFormat.format(displayTime),
                        style: GoogleFonts.lexendDeca(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),

                      // Transaction ID (Smart Format)
                      if (transactionId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '#${_formatTransactionId(transactionId, displayTime)}',
                          style: GoogleFonts.robotoMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),

            // === DASHED DIVIDER ===
            _buildDashedDivider(),

            // === ITEMS SECTION ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: items.map((item) {
                  final qty = item.qty > 0 ? item.qty : 1;
                  final subtotal = item.price * qty;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Name
                        Text(
                          item.name,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Qty x Price = Subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$qty x ${_formatRupiah(item.price)}',
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _formatRupiah(subtotal),
                              style: GoogleFonts.lexendDeca(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // === DASHED DIVIDER ===
            _buildDashedDivider(),

            // === TOTAL SECTION ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatRupiah(totalAmount),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Cash Payment Details (show if cash)
                  if (paymentMethod.toLowerCase() == 'cash' &&
                      cashReceived != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tunai',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _formatRupiah(cashReceived!),
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kembali',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _formatRupiah(changeAmount ?? 0),
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Payment Method
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pembayaran',
                        style: GoogleFonts.lexendDeca(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: paymentMethod.toUpperCase() == 'QRIS'
                              ? Colors.purple.withValues(alpha: 0.1)
                              : AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          paymentMethod.toUpperCase(),
                          style: GoogleFonts.lexendDeca(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: paymentMethod.toUpperCase() == 'QRIS'
                                ? Colors.purple
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // === DASHED DIVIDER ===
            _buildDashedDivider(),

            // === FOOTER SECTION (Dynamic Wi-Fi from SharedPreferences) ===
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Terima Kasih!',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Dynamic Wi-Fi footer using FutureBuilder
                  FutureBuilder<WifiSettings>(
                    future: PrinterService.instance.getWifiSettings(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 30,
                          child: Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final settings = snapshot.data;
                      if (settings == null || settings.isEmpty) {
                        return Text(
                          'Silakan atur Wi-Fi di Pengaturan Printer',
                          style: GoogleFonts.lexendDeca(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.wifi,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Wi-Fi: ${settings.ssid}',
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pass: ${settings.password}',
                            style: GoogleFonts.lexendDeca(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Staff Name (if provided)
                  if (staffName != null && staffName!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Kasir: $staffName',
                      style: GoogleFonts.lexendDeca(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  // Custom Footer Message
                  if (footer != null && footer!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      footer!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a dashed line divider
  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 5.0;
          const dashSpace = 3.0;
          final dashCount = (constraints.maxWidth / (dashWidth + dashSpace))
              .floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(dashCount, (_) {
              return Container(
                width: dashWidth,
                height: 1,
                margin: const EdgeInsets.only(right: dashSpace),
                color: AppColors.textSecondary.withValues(alpha: 0.3),
              );
            }),
          );
        },
      ),
    );
  }
}
