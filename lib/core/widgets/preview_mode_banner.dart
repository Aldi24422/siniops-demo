import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/preview_mode_controller.dart';
import '../../features/auth/login_page.dart';

/// A banner widget that shows when app is in Demo Mode
/// Displays at top of screen to indicate data is in-memory only
class PreviewModeBanner extends StatelessWidget {
  const PreviewModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade600],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.science_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                "DEMO MODE - Data tidak tersimpan permanen",
                style: GoogleFonts.lexendDeca(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _exitToRolePicker(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Ganti Role",
                  style: GoogleFonts.lexendDeca(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exitToRolePicker(BuildContext context) {
    PreviewModeController.instance.resetMockData();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
}
