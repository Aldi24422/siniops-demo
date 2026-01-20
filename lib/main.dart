import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants/app_colors.dart';
import 'core/services/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/dashboard/owner_dashboard.dart';
import 'features/dashboard/crew_dashboard.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Indonesian locale for intl package
  await initializeDateFormatting('id_ID', null);

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
      title: 'SiniOps Enterprise',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const AuthGate(),
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

/// Auth Gate - Listens to auth state changes
/// Prevents logout/crash when permission changes restart the app
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text(
                    "Memuat...",
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<String?>(
            future: AuthController().getUserRole(snapshot.data!.uid),
            builder: (context, roleSnapshot) {
              // Still loading role
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              final role = roleSnapshot.data;

              if (role == 'owner' || role == 'outlet_manager') {
                return const OwnerDashboard();
              } else if (role == 'crew') {
                return const CrewDashboard();
              } else {
                // Unknown role or error - go to login
                return const LoginPage();
              }
            },
          );
        }

        // User not logged in
        return const LoginPage();
      },
    );
  }
}
