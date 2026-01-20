import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/transaction_controller.dart';
import 'transaction_history_page.dart';
import 'widgets/date_range_selector.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TransactionController _controller = TransactionController();

  // Date range state
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  DateRangePreset _selectedPreset = DateRangePreset.today;

  // Report data
  Map<String, double> _chartData = {};
  List<Map<String, dynamic>> _topProducts = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadData();
  }

  void _initializeDates() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  void _onPresetChanged(DateRangePreset preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (preset) {
      case DateRangePreset.today:
        start = DateTime(now.year, now.month, now.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangePreset.thisWeek:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(monday.year, monday.month, monday.day);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangePreset.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case DateRangePreset.custom:
        // Don't change dates for custom, the picker will handle it
        return;
    }

    setState(() {
      _selectedPreset = preset;
      _startDate = start;
      _endDate = end;
    });
    _loadData();
  }

  void _onCustomRangeSelected(DateTimeRange range) {
    setState(() {
      _selectedPreset = DateRangePreset.custom;
      _startDate = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      _endDate = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
    });
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _controller.getRevenueForPeriod(_startDate, _endDate),
        _controller.getTopProductsForPeriod(_startDate, _endDate),
        _controller.getSummaryForPeriod(_startDate, _endDate),
      ]);

      setState(() {
        _chartData = results[0] as Map<String, double>;
        _topProducts = results[1] as List<Map<String, dynamic>>;
        _summary = results[2] as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ReportPage] Error loading data: $e');
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

  String _formatCompact(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}rb';
    }
    return value.toStringAsFixed(0);
  }

  String _getPeriodLabel() {
    switch (_selectedPreset) {
      case DateRangePreset.today:
        return 'Hari Ini';
      case DateRangePreset.thisWeek:
        return 'Minggu Ini';
      case DateRangePreset.thisMonth:
        return 'Bulan Ini';
      case DateRangePreset.custom:
        return 'Periode Kustom';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
      body: Column(
        children: [
          // Date Range Selector - Fixed at top
          DateRangeSelector(
            startDate: _startDate,
            endDate: _endDate,
            selectedPreset: _selectedPreset,
            onPresetChanged: _onPresetChanged,
            onCustomRangeSelected: _onCustomRangeSelected,
          ),

          // Scrollable Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: AppColors.primary,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          _buildSummaryCards(),
                          const SizedBox(height: 24),

                          // Chart Section
                          _buildSectionHeader(
                            "Trend Omzet",
                            Icons.bar_chart_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildChart(),
                          const SizedBox(height: 24),

                          // Top Products Section
                          _buildSectionHeader(
                            "Produk Terlaris",
                            Icons.star_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildTopProductsList(),
                          const SizedBox(height: 24),

                          // Transaction History Button
                          _buildTransactionHistoryButton(),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    final totalRevenue = (_summary['totalRevenue'] ?? 0).toDouble();
    final totalTransactions = _summary['totalTransactions'] ?? 0;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: "Total Omzet",
            value: _formatRupiah(totalRevenue),
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            title: "Jumlah Transaksi",
            value: "$totalTransactions struk",
            icon: Icons.receipt_long_rounded,
            color: AppColors.secondary,
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
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
              fontSize: 28,
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

  Widget _buildChart() {
    if (_chartData.isEmpty) {
      return _buildEmptyState("Belum ada data transaksi");
    }

    final entries = _chartData.entries.toList();
    final maxValue = _chartData.values.fold(0.0, (a, b) => a > b ? a : b);
    final daysDiff = _endDate.difference(_startDate).inDays + 1;
    final isCompact = daysDiff > 7;

    return Container(
      height: 220,
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
                final key = entries[groupIndex].key;
                return BarTooltipItem(
                  '$key\n${_formatRupiah(rod.toY)}',
                  GoogleFonts.lexendDeca(
                    color: Colors.white,
                    fontSize: 11,
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
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= entries.length) {
                    return const SizedBox();
                  }

                  // For compact charts, show fewer labels
                  if (isCompact &&
                      index % 5 != 0 &&
                      index != entries.length - 1) {
                    return const SizedBox();
                  }

                  String label = entries[index].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      label,
                      style: GoogleFonts.lexendDeca(
                        fontSize: isCompact ? 9 : 10,
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
                reservedSize: 45,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _formatCompact(value),
                      style: GoogleFonts.lexendDeca(
                        fontSize: 9,
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
            final isToday =
                index == entries.length - 1 &&
                _selectedPreset != DateRangePreset.custom;

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: value,
                  width: isCompact ? 8 : 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
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

  Widget _buildTransactionHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TransactionHistoryPage(
                startDate: _startDate,
                endDate: _endDate,
                periodLabel: _getPeriodLabel(),
              ),
            ),
          );
        },
        icon: const Icon(Icons.history_rounded),
        label: Text(
          "Lihat Riwayat Transaksi",
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
