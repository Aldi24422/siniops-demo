import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/auth_controller.dart';
import '../../core/services/preview_mode_controller.dart';
import '../dashboard/owner_dashboard.dart';
import '../dashboard/crew_dashboard.dart';

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
      // Check if user exists in Firestore (role checks also validation existence)
      String? role = await _authController.getUserRole(user.uid);

      if (role == null) {
        if (mounted) {
          _showSnackBar(
            'Akun tidak ditemukan atau telah dihapus.',
            isError: true,
          );
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Now that we know the user exists and has a role, fetch full user data
      final userData = await _authController.getUserData(user.uid);

      if (userData == null) {
        // User document not found in Firestore (should not happen if role was found)
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

      // Get user role (use explicit name to avoid shadowing)
      final userRole = userData['role'] as String?;

      if (!mounted) return;

      if (userRole == 'owner' || userRole == 'outlet_manager') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OwnerDashboard()),
        );
      } else if (role == 'crew') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CrewDashboard()),
        ); // Continue else if needed
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

  /// Show dialog to reset password
  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Lupa Password',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan email Anda untuk menerima link reset password.',
              style: GoogleFonts.lexendDeca(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: GoogleFonts.lexendDeca(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                _showSnackBar('Email harus diisi', isError: true);
                return;
              }

              Navigator.pop(context);
              _showSnackBar('Mengirim email reset password...');

              try {
                await _authController.sendPasswordResetEmail(email);
                _showSnackBar(
                  '✅ Link reset password telah dikirim ke email Anda',
                );
              } catch (e) {
                _showSnackBar('Gagal mengirim email: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Kirim',
              style: GoogleFonts.lexendDeca(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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

        // Lupa Password Button
        TextButton(
          onPressed: _showForgotPasswordDialog,
          child: Text(
            "Lupa Password?",
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Divider with text
        Row(
          children: [
            Expanded(child: Container(height: 1, color: AppColors.accent)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "atau",
                style: GoogleFonts.lexendDeca(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Expanded(child: Container(height: 1, color: AppColors.accent)),
          ],
        ),

        const SizedBox(height: 24),

        // Preview Mode Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _showPreviewRoleDialog,
            icon: const Icon(Icons.visibility_rounded, size: 20),
            label: Text(
              "Preview Mode (Demo)",
              style: GoogleFonts.lexendDeca(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.secondary,
              side: const BorderSide(color: AppColors.secondary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          "Jelajahi aplikasi tanpa login",
          style: GoogleFonts.lexendDeca(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Show dialog to select preview role
  void _showPreviewRoleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.visibility_rounded,
                color: AppColors.secondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Preview Mode",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Pilih role untuk menjelajahi aplikasi:",
              style: GoogleFonts.lexendDeca(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Owner Option
            _buildRoleOption(
              icon: Icons.admin_panel_settings_rounded,
              title: "Owner",
              subtitle: "Akses penuh: Laporan, Menu, Stok, Staff",
              color: AppColors.primary,
              onTap: () => _enterPreviewMode('owner'),
            ),

            const SizedBox(height: 12),

            // Crew Option
            _buildRoleOption(
              icon: Icons.point_of_sale_rounded,
              title: "Kasir / Crew",
              subtitle: "Akses kasir: Transaksi, Lihat Menu",
              color: AppColors.secondary,
              onTap: () => _enterPreviewMode('crew'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Batal",
              style: GoogleFonts.lexendDeca(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent, width: 1.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lexendDeca(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _enterPreviewMode(String role) {
    Navigator.pop(context); // Close dialog

    // Enter preview mode
    PreviewModeController.instance.enterPreviewMode(role: role);

    // Navigate to appropriate dashboard
    if (role == 'owner') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OwnerDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CrewDashboard()),
      );
    }
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
