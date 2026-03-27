import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/preview_mode_banner.dart';
import '../../core/services/preview_mode_controller.dart';
import '../../core/services/mock_transaction_controller.dart';
import '../../core/services/mock_auth_controller.dart';
import '../auth/login_page.dart';
import '../report/report_page.dart';
import 'manage_menu_page.dart';
import '../inventory/manage_ingredients_page.dart';
import '../settings/printer_settings_page.dart';
import '../staff/manage_staff_page.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  // User data (demo)
  String _displayName = 'Demo Owner';
  String _userEmail = 'owner@siniops.demo';
  String _userRole = 'owner';
  final MockTransactionController _mockTransactionController =
      MockTransactionController();

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(value);
  }

  @override
  void initState() {
    super.initState();
    _loadDemoUserData();
  }

  /// Load demo user data from MockAuthController
  void _loadDemoUserData() {
    final mockAuth = MockAuthController.instance;
    setState(() {
      _displayName = mockAuth.currentUserDisplayName ?? 'Demo Owner';
      _userEmail = 'owner@siniops.demo';
      _userRole = PreviewModeController.instance.previewRole;
    });
  }

  /// Format name: First 2 names full, rest as initials
  String _formatDisplayName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 2) {
      return fullName;
    }
    final firstTwo = parts.take(2).join(' ');
    final initials = parts
        .skip(2)
        .map((name) => '${name[0].toUpperCase()}.')
        .join(' ');
    return '$firstTwo $initials';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 2 : 4;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // --- APP BAR OWNER ---
      appBar: AppBar(
        toolbarHeight: 65,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 24,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              height: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            Text(
              'SiniOps',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3E2723),
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            tooltip: 'Akun Owner',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFEFEBE9),
                child: Icon(
                  Icons.person,
                  color: Color(0xFF3E2723),
                  size: 20,
                ),
              ),
            ),
            onSelected: (String value) {
              if (value == 'logout') {
                PreviewModeController.instance.resetMockData();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDisplayName(_displayName),
                      style: GoogleFonts.lexendDeca(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _userEmail,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Keluar",
                      style: GoogleFonts.lexendDeca(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 1.0,
          ),
        ),
      ),

      // --- BODY ---
      body: Column(
        children: [
          const PreviewModeBanner(),

          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Overview Bisnis",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      // Revenue Card — always uses mock
                      StreamBuilder<double>(
                        stream: _mockTransactionController.getTodayRevenueStream(),
                        builder: (context, todaySnapshot) {
                          final todayRevenue = todaySnapshot.data ?? 0;

                          return StreamBuilder<double>(
                            stream: _mockTransactionController
                                .getYesterdayRevenueStream(),
                            builder: (context, yesterdaySnapshot) {
                              final yesterdayRevenue =
                                  yesterdaySnapshot.data ?? 0;

                              double percentChange = 0;
                              if (yesterdayRevenue > 0) {
                                percentChange =
                                    ((todayRevenue - yesterdayRevenue) /
                                        yesterdayRevenue) *
                                    100;
                              } else if (todayRevenue > 0) {
                                percentChange = 100;
                              }

                              final percentText = percentChange
                                  .abs()
                                  .toStringAsFixed(0);

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.account_balance_wallet_rounded,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Total Omzet Hari Ini",
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatRupiah(todayRevenue),
                                      style: GoogleFonts.dongle(
                                        fontSize: 42,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 0.9,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          percentChange > 0
                                              ? Icons.trending_up_rounded
                                              : percentChange < 0
                                              ? Icons.trending_down_rounded
                                              : Icons.trending_flat_rounded,
                                          color: percentChange > 0
                                              ? Colors.greenAccent
                                              : percentChange < 0
                                              ? Colors.redAccent
                                              : Colors.amberAccent,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          percentChange > 0
                                              ? "+$percentText% dari kemarin"
                                              : percentChange < 0
                                              ? "-$percentText% dari kemarin"
                                              : "Sama dengan kemarin",
                                          style: TextStyle(
                                            color: percentChange > 0
                                                ? Colors.greenAccent
                                                : percentChange < 0
                                                ? Colors.redAccent
                                                : Colors.amberAccent,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    StreamBuilder<int>(
                                      stream: _mockTransactionController
                                            .getTodayTransactionCountStream(),
                                      builder: (context, countSnapshot) {
                                        final count = countSnapshot.data ?? 0;
                                        return Row(
                                          children: [
                                            const Icon(
                                              Icons.receipt_long_rounded,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "$count transaksi hari ini",
                                              style: const TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      Text(
                        "Menu Manajemen",
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          _adminMenuCard(
                            context,
                            Icons.restaurant_menu_rounded,
                            "Kelola Menu",
                            "Tambah/Edit Produk",
                            AppColors.primary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageMenuPage(),
                              ),
                            ),
                          ),
                          _adminMenuCard(
                            context,
                            Icons.inventory_2_rounded,
                            "Stok Bahan",
                            "Kelola Bahan Baku",
                            AppColors.secondary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageIngredientsPage(),
                              ),
                            ),
                          ),
                          _adminMenuCard(
                            context,
                            Icons.bar_chart_rounded,
                            "Laporan",
                            "Cek Omzet",
                            Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReportPage(),
                              ),
                            ),
                          ),
                          _adminMenuCard(
                            context,
                            Icons.people_alt_outlined,
                            _userRole == 'owner' ? "Manajemen Tim" : "Crew",
                            _userRole == 'owner'
                                ? "Atur tim & akses"
                                : "Kelola crew",
                            Colors.purple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ManageStaffPage(),
                              ),
                            ),
                          ),
                          _adminMenuCard(
                            context,
                            Icons.settings_outlined,
                            "Pengaturan",
                            "Printer & Toko",
                            Colors.grey,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrinterSettingsPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminMenuCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color color, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.lexendDeca(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
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
}
