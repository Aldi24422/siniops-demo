import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_controller.dart';
import '../dashboard/owner_dashboard.dart';
import '../dashboard/cashier_dashboard.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _authController = AuthController();

  bool _isObscure = true;
  bool _isLoading = false;
  bool _isSeeding = false;

  // Cache text styles
  late final TextStyle _titleStyle;
  late final TextStyle _buttonStyle;

  @override
  void initState() {
    super.initState();
    _titleStyle = GoogleFonts.dongle(
      fontSize: 64,
      fontWeight: FontWeight.bold,
      color: AppColors.primary,
      height: 1.1,
    );
    _buttonStyle = GoogleFonts.lexendDeca(
      fontSize: 17,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
  }

  /// Login with Firebase Auth + Security Check
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar("Email dan password harus diisi", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Sign in with Firebase Auth
      final user = await _authController.signIn(email, password);

      if (user == null) {
        throw Exception("Login gagal");
      }

      // SECURITY CHECK: Get full user data and check isActive
      final userData = await _authController.getUserData(user.uid);

      if (userData == null) {
        // User document not found in Firestore
        await _authController.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar("Akun tidak ditemukan di sistem", isError: true);
        return;
      }

      // Check if account is active
      final isActive =
          userData['isActive'] ??
          true; // Default true for backward compatibility
      if (isActive == false) {
        await _authController.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar("Akun Anda telah dinonaktifkan", isError: true);
        return;
      }

      // Get user role
      final role = userData['role'] as String?;

      if (!mounted) return;

      if (role == 'owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OwnerDashboard()),
        );
      } else if (role == 'cashier') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CashierDashboard()),
        );
      } else {
        _showSnackBar("Role tidak dikenali: $role", isError: true);
        setState(() => _isLoading = false);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      String message = "Login gagal";
      switch (e.code) {
        case 'user-not-found':
          message = "Akun tidak ditemukan";
          break;
        case 'wrong-password':
          message = "Password salah";
          break;
        case 'invalid-email':
          message = "Format email tidak valid";
          break;
        case 'invalid-credential':
          message = "Email atau password salah";
          break;
        default:
          message = e.message ?? "Terjadi kesalahan";
      }
      _showSnackBar(message, isError: true);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar("Error: $e", isError: true);
    }
  }

  /// Seed default demo users
  void _seedDefaultUsers() async {
    setState(() => _isSeeding = true);

    try {
      final result = await _authController.seedDefaultUsers();
      if (!mounted) return;

      _showSnackBar(result.message, isError: result.hasErrors);
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: _buildLoginForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        SizedBox(
          height: 140,
          child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
        ),

        // App Name
        Text("SiniOps", style: _titleStyle),

        const SizedBox(height: 32),

        // Email Field
        _buildTextField(
          controller: _emailController,
          label: "Email",
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),

        const SizedBox(height: 16),

        // Password Field
        _buildPasswordField(),

        const SizedBox(height: 24),

        // Login Button
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white70,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text("Masuk", style: _buttonStyle),
          ),
        ),

        const SizedBox(height: 24),

        // Setup Demo Account Button
        TextButton.icon(
          onPressed: _isSeeding ? null : _seedDefaultUsers,
          icon: _isSeeding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline, size: 18),
          label: Text(
            _isSeeding ? "Membuat akun..." : "Setup Akun Demo",
            style: GoogleFonts.lexendDeca(fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        prefixIcon: Icon(icon, color: AppColors.secondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passController,
      obscureText: _isObscure,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: "Password",
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.secondary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isObscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppColors.textSecondary,
          ),
          onPressed: () => setState(() => _isObscure = !_isObscure),
        ),
      ),
    );
  }
}
