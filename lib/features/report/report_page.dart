import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/transaction_controller.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TransactionController _transactionController = TransactionController();

  Map<String, double> _weeklyData = {};
  List<Map<String, dynamic>> _topProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final weekly = await _transactionController.getWeeklyRevenue();
      final topProducts = await _transactionController.getTopSellingProducts();

      setState(() {
        _weeklyData = weekly;
        _topProducts = topProducts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('[ReportPage] Error loading data: $e');
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

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
    }
    return value.toStringAsFixed(0);
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
          "Laporan Bisnis",
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
            onPressed: _loadData,
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
          : RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Header
                    _buildDateHeader(),
                    const SizedBox(height: 20),

                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),

                    // Weekly Chart Section
                    _buildSectionHeader(
                      "Omzet 7 Hari Terakhir",
                      Icons.bar_chart_rounded,
                    ),
                    const SizedBox(height: 12),
                    _buildWeeklyChart(),
                    const SizedBox(height: 24),

                    // Top Products Section
                    _buildSectionHeader("Produk Terlaris", Icons.star_rounded),
                    const SizedBox(height: 12),
                    _buildTopProductsList(),
                    const SizedBox(height: 24),

                    // Recent Transactions Button
                    _buildRecentTransactionsButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, d MMMM yyyy', 'id_ID');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Periode Laporan",
                  style: GoogleFonts.lexendDeca(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                Text(
                  dateFormat.format(now),
                  style: GoogleFonts.lexendDeca(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        // Today's Revenue Card
        Expanded(
          child: StreamBuilder<double>(
            stream: _transactionController.getTodayRevenueStream(),
            builder: (context, snapshot) {
              final revenue = snapshot.data ?? 0;
              return _buildSummaryCard(
                title: "Omzet Hari Ini",
                value: _formatRupiah(revenue),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.success,
              );
            },
          ),
        ),
        const SizedBox(width: 12),

        // Transaction Count Card
        Expanded(
          child: StreamBuilder<int>(
            stream: _transactionController.getTodayTransactionCountStream(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return _buildSummaryCard(
                title: "Total Transaksi",
                value: "$count struk",
                icon: Icons.receipt_long_rounded,
                color: AppColors.secondary,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.lexendDeca(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.dongle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.lexendDeca(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyChart() {
    if (_weeklyData.isEmpty) {
      return _buildEmptyState("Belum ada data transaksi");
    }

    final entries = _weeklyData.entries.toList();
    final maxValue = _weeklyData.values.fold(0.0, (a, b) => a > b ? a : b);

    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxValue > 0 ? maxValue * 1.2 : 100000,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.primary,
              tooltipBorder: BorderSide.none,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final value = rod.toY;
                return BarTooltipItem(
                  _formatRupiah(value),
                  GoogleFonts.lexendDeca(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox();
                  }

                  final label = entries[index].key.split(
                    ' ',
                  )[0]; // Just day name
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _formatCompact(value),
                      style: GoogleFonts.lexendDeca(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxValue > 0 ? maxValue / 4 : 25000,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.accent, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(entries.length, (index) {
            final value = entries[index].value;
            final isToday = index == entries.length - 1;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: 28,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  gradient: LinearGradient(
                    colors: isToday
                        ? [
                            AppColors.secondary,
                            AppColors.secondary.withValues(alpha: 0.7),
                          ]
                        : [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTopProductsList() {
    if (_topProducts.isEmpty) {
      return _buildEmptyState("Belum ada data penjualan");
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _topProducts.length,
        separatorBuilder: (context, index) =>
            Divider(color: AppColors.accent, height: 1),
        itemBuilder: (context, index) {
          final product = _topProducts[index];
          final rank = index + 1;

          return ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: rank == 1
                    ? AppColors.gold.withValues(alpha: 0.2)
                    : rank == 2
                    ? Colors.grey.shade300
                    : rank == 3
                    ? Colors.orange.shade100
                    : AppColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "#$rank",
                  style: GoogleFonts.lexendDeca(
                    fontWeight: FontWeight.bold,
                    color: rank == 1
                        ? AppColors.gold
                        : rank == 2
                        ? Colors.grey.shade600
                        : rank == 3
                        ? Colors.orange.shade700
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            title: Text(
              product['productName'] ?? 'Unknown',
              style: GoogleFonts.lexendDeca(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              "${product['totalQty']} terjual",
              style: GoogleFonts.lexendDeca(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            trailing: Text(
              _formatRupiah((product['totalRevenue'] ?? 0).toDouble()),
              style: GoogleFonts.lexendDeca(
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
                fontSize: 13,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecentTransactionsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          // Navigate to transaction history page
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Fitur Riwayat Transaksi segera hadir!",
                style: GoogleFonts.lexendDeca(),
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        icon: const Icon(Icons.history_rounded),
        label: Text(
          "Lihat Semua Riwayat Transaksi",
          style: GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 48, color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.lexendDeca(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
