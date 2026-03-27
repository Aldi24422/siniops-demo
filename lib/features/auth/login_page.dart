import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/preview_mode_controller.dart';
import '../dashboard/owner_dashboard.dart';
import '../dashboard/crew_dashboard.dart';

/// Demo-only Login Page
/// Simplified to a role picker — no Firebase auth needed.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        size: 60,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // App Name
                Text(
                  "SiniOps",
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Demo Mode",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Pilih role untuk mencoba aplikasi",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 48),

                // Owner Role Button
                _buildRoleButton(
                  context: context,
                  icon: Icons.admin_panel_settings_rounded,
                  title: "Owner / Manager",
                  subtitle: "Kelola menu, stok, laporan, dan tim",
                  color: AppColors.primary,
                  onTap: () => _enterDemoMode(context, 'owner'),
                ),

                const SizedBox(height: 16),

                // Crew Role Button
                _buildRoleButton(
                  context: context,
                  icon: Icons.point_of_sale_rounded,
                  title: "Kasir / Crew",
                  subtitle: "Proses transaksi dan pembayaran",
                  color: AppColors.secondary,
                  onTap: () => _enterDemoMode(context, 'crew'),
                ),

                const SizedBox(height: 40),

                // Footer info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Semua data bersifat sementara dan akan reset saat aplikasi di-reload.",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 12,
                            color: AppColors.textSecondary,
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

  Widget _buildRoleButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.lexendDeca(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterDemoMode(BuildContext context, String role) {
    PreviewModeController.instance.enterPreviewMode(role: role);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            role == 'owner' ? const OwnerDashboard() : const CrewDashboard(),
      ),
    );
  }
}
