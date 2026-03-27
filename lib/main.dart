import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_colors.dart';
import 'core/services/preview_mode_controller.dart';
import 'features/auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Indonesian locale for intl package
  await initializeDateFormatting('id_ID', null);

  // Initialize demo mode
  PreviewModeController.instance.enterPreviewMode(role: 'owner');

  // Preload Google Fonts to prevent font flash
  await GoogleFonts.pendingFonts([
    GoogleFonts.poppins(fontWeight: FontWeight.w700),
    GoogleFonts.lexendDeca(),
    GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
    GoogleFonts.lexendDeca(fontWeight: FontWeight.bold),
    GoogleFonts.dongle(fontWeight: FontWeight.bold),
  ]);

  runApp(const SiniOpsApp());
}

class SiniOpsApp extends StatelessWidget {
  const SiniOpsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiniOps Demo',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const LoginPage(),
    );
  }

  ThemeData _buildTheme() {
    var baseTheme = ThemeData(useMaterial3: true);
    return baseTheme.copyWith(
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
      ),

      textTheme: GoogleFonts.lexendDecaTextTheme().copyWith(
        headlineMedium: GoogleFonts.dongle(
          fontSize: 42,
          fontWeight: FontWeight.bold,
          height: 1.0,
          color: AppColors.primary,
        ),
        headlineSmall: GoogleFonts.lexendDeca(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
        titleMedium: GoogleFonts.lexendDeca(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: GoogleFonts.lexendDeca(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 24,
        iconTheme: const IconThemeData(color: AppColors.primary),
        titleTextStyle: GoogleFonts.dongle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          height: 0.8,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          elevation: 0,
        ),
      ),
    );
  }
}
