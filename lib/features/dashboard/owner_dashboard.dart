import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
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
  // User data
  String _displayName = 'Owner';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data from Firestore
  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _displayName = doc.data()?['displayName'] ?? 'Owner';
            _userEmail = doc.data()?['email'] ?? user.email ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('[OwnerDashboard] Error loading user data: $e');
    }
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

      // --- APP BAR OWNER (Fixed for Web) ---
      appBar: AppBar(
        toolbarHeight: 65,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0, // Fix blurry popup on web
        surfaceTintColor: Colors.transparent, // Fix blurry popup on web
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
          // MENU PROFIL (Logout ada di dalam sini)
          PopupMenuButton<String>(
            offset: const Offset(0, 50),
            tooltip: 'Akun Owner',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Colors.white, // Solid white background
            // Avatar Button
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFEFEBE9),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF3E2723),
                  size: 20,
                ),
              ),
            ),
            onSelected: (String value) {
              if (value == 'logout') {
                FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // Info User (NOT faded)
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
                        color: AppColors.textPrimary, // Solid color, not faded
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

              // Menu Logout
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

      // --- BODY UTAMA (Responsive with max width constraint) ---
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Judul
                Text(
                  "Overview Bisnis",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Kartu Total Pendapatan
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Total Pendapatan Hari Ini",
                        style: TextStyle(color: Colors.white70),
                      ),
                      Text(
                        "Rp 4.500.000",
                        style: GoogleFonts.dongle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 0.9,
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text(
                            "+12% dari kemarin",
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Grid Menu Manajemen
                Text(
                  "Menu Manajemen",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                      "Cek profit bulanan",
                      Colors.blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportPage()),
                      ),
                    ),
                    _adminMenuCard(
                      context,
                      Icons.people_alt_outlined,
                      "Karyawan",
                      "Kelola staf",
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
    );
  }

  // Helper Widget untuk Menu Grid
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
