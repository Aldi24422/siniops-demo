import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/transaction_controller.dart';

class TransactionHistoryPage extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? periodLabel;

  const TransactionHistoryPage({
    super.key,
    this.startDate,
    this.endDate,
    this.periodLabel,
  });

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final TransactionController _controller = TransactionController();
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startDate =
          widget.startDate ?? now.subtract(const Duration(days: 30));
      final endDate = widget.endDate ?? now;

      final transactions = await _controller.getTransactionsForPeriod(
        startDate,
        endDate,
        limit: 200,
      );

      setState(() {
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[TransactionHistory] Error: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    final formatter = DateFormat('EEEE, d MMMM yyyy', 'id_ID');
    return formatter.format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Riwayat Transaksi",
          style: GoogleFonts.lexendDeca(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            onPressed: _loadTransactions,
            tooltip: "Refresh",
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.accent, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _transactions.isEmpty
          ? _buildEmptyState()
          : _buildTransactionList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "Belum ada transaksi",
            style: GoogleFonts.lexendDeca(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.periodLabel ?? "Periode ini",
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    // Group transactions by date
    final Map<String, List<Map<String, dynamic>>> groupedByDate = {};

    for (final txn in _transactions) {
      final timestamp = txn['createdAt'] as Timestamp?;
      final dateKey = _formatDate(timestamp);

      if (!groupedByDate.containsKey(dateKey)) {
        groupedByDate[dateKey] = [];
      }
      groupedByDate[dateKey]!.add(txn);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedByDate.length,
      itemBuilder: (context, index) {
        final dateKey = groupedByDate.keys.elementAt(index);
        final dayTransactions = groupedByDate[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.calendar_today_rounded,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateKey,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${dayTransactions.length} transaksi",
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Transaction Cards
            ...dayTransactions.map((txn) => _buildTransactionCard(txn)),

            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final totalAmount = (txn['totalAmount'] ?? 0).toDouble();
    final items = txn['items'] as List<dynamic>? ?? [];
    final paymentMethod = txn['paymentMethod'] ?? 'cash';
    final timestamp = txn['createdAt'] as Timestamp?;
    final timeString = timestamp != null
        ? DateFormat('HH:mm').format(timestamp.toDate())
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: paymentMethod == 'qris'
                  ? Colors.purple.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              paymentMethod == 'qris'
                  ? Icons.qr_code_rounded
                  : Icons.payments_rounded,
              color: paymentMethod == 'qris'
                  ? Colors.purple
                  : AppColors.success,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _formatRupiah(totalAmount),
                  style: GoogleFonts.lexendDeca(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                timeString,
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                "${items.length} item",
                style: GoogleFonts.lexendDeca(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: paymentMethod == 'qris'
                      ? Colors.purple.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paymentMethod.toUpperCase(),
                  style: GoogleFonts.lexendDeca(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: paymentMethod == 'qris'
                        ? Colors.purple
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          children: [
            // Item list
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final productName = item['productName'] ?? 'Unknown';
                  final qty = item['qty'] ?? 1;
                  final price = (item['price'] ?? 0).toDouble();
                  final subtotal = (item['subtotal'] ?? 0).toDouble();

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: entry.key < items.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: AppColors.accent,
                                width: 1,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              "$qty×",
                              style: GoogleFonts.lexendDeca(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                "@${_formatRupiah(price)}",
                                style: GoogleFonts.lexendDeca(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatRupiah(subtotal),
                          style: GoogleFonts.lexendDeca(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
