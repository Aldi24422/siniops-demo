import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/product_model.dart';
import '../../core/services/product_controller.dart';
import '../../core/services/mock_product_controller.dart';
import '../../core/services/preview_mode_controller.dart';
import '../../core/widgets/preview_mode_banner.dart';
import '../transaction/payment_dialog.dart';
import '../auth/login_page.dart';
import '../settings/printer_settings_page.dart';

class CrewDashboard extends StatefulWidget {
  const CrewDashboard({super.key});

  @override
  State<CrewDashboard> createState() => _CrewDashboardState();
}

class _CrewDashboardState extends State<CrewDashboard> {
  final ProductController _productController = ProductController();
  final MockProductController _mockProductController = MockProductController();
  final List<Product> _localProducts = [];

  // User data
  String _displayName = 'Crew';
  String _userEmail = '';

  bool get _isPreviewMode => PreviewModeController.instance.isPreviewMode;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Load user data from Firestore (skip in preview mode)
  Future<void> _loadUserData() async {
    if (_isPreviewMode) {
      setState(() {
        _displayName = 'Demo Kasir';
        _userEmail = 'demo@siniops.id';
      });
      return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _displayName = doc.data()?['displayName'] ?? 'Crew';
            _userEmail = doc.data()?['email'] ?? user.email ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('[CrewDashboard] Error loading user data: $e');
    }
  }

  /// Format name: First 2 names full, rest as initials
  /// Example: "Rafli Aditya Pramana Putra Wiyoko" -> "Rafli Aditya P. P. W."
  String _formatDisplayName(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length <= 2) {
      return fullName;
    }

    // First 2 names
    final firstTwo = parts.take(2).join(' ');

    // Rest as initials
    final initials = parts
        .skip(2)
        .map((name) => '${name[0].toUpperCase()}.')
        .join(' ');

    return '$firstTwo $initials';
  }

  double get _totalPrice =>
      _localProducts.fold(0, (total, item) => total + (item.price * item.qty));

  int get _totalItems =>
      _localProducts.fold(0, (total, item) => total + item.qty);

  String formatRupiah(double value) {
    return value
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  void _resetCart() {
    setState(() {
      for (var p in _localProducts) {
        p.qty = 0;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Pesanan di-reset",
          style: GoogleFonts.lexendDeca(fontSize: 14),
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
          const PreviewModeBanner(),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sapaan with formatted name
                    Text(
                      "Halo, ${_formatDisplayName(_displayName)}!",
                      style: GoogleFonts.dongle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Siap mencatat transaksi hari ini?",
                      style: GoogleFonts.lexendDeca(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header Menu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Menu Kopi",
                          style: GoogleFonts.lexendDeca(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        // Reset cart button
                        if (_totalItems > 0)
                          TextButton.icon(
                            onPressed: _resetCart,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text("Reset"),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Product List with StreamBuilder
                    StreamBuilder<List<Product>>(
                      stream: _isPreviewMode
                          ? _mockProductController.getProducts()
                          : _productController.getProducts(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                "Error: ${snapshot.error}",
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            ),
                          );
                        }

                        final products = snapshot.data!;
                        if (products.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.coffee_outlined,
                                    size: 64,
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Belum ada menu",
                                    style: GoogleFonts.lexendDeca(
                                      color: AppColors.textSecondary,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // Sync local state
                        for (var product in products) {
                          final existing = _localProducts.where(
                            (p) => p.id == product.id,
                          );
                          if (existing.isEmpty) {
                            _localProducts.add(product);
                          }
                        }

                        // Remove products that no longer exist
                        _localProducts.removeWhere(
                          (local) => !products.any((p) => p.id == local.id),
                        );

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _localProducts.length,
                          itemBuilder: (context, index) {
                            final product = _localProducts[index];
                            return _buildProductCard(product);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Product image placeholder
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(
                  Icons.coffee_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Rp ${formatRupiah(product.price)}",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            // Quantity control - Circular stepper (minus only shows when qty > 0)
            product.qty == 0
                ? // Show only + button in circle when qty is 0
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        product.qty++;
                      });
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  )
                : // Show full stepper when qty > 0
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minus button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (product.qty > 0) product.qty--;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.remove,
                              color: AppColors.secondary,
                              size: 18,
                            ),
                          ),
                        ),
                        // Quantity
                        SizedBox(
                          width: 32,
                          child: Text(
                            product.qty.toString(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lexendDeca(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        // Plus button
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              product.qty++;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 60,
      backgroundColor: AppColors.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 20,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/images/logo.png',
            height: 36,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 10),
          Text(
            "SiniOps",
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          offset: const Offset(0, 50),
          tooltip: 'Profil',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: AppColors.surface,
          icon: const Icon(
            Icons.person_outline_rounded,
            color: AppColors.textSecondary,
            size: 22,
          ),
          onSelected: (val) {
            if (val == 'settings') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsPage()),
              );
            } else if (val == 'logout') {
              if (_isPreviewMode) {
                PreviewModeController.instance.exitPreviewMode();
              } else {
                FirebaseAuth.instance.signOut();
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDisplayName(_displayName),
                    style: GoogleFonts.lexendDeca(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    _userEmail.isNotEmpty ? _userEmail : "Shift Pagi",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Pengaturan Printer",
                    style: GoogleFonts.lexendDeca(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
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
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: AppColors.accent, height: 1.0),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Total
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Total ($_totalItems item)",
                    style: GoogleFonts.lexendDeca(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    "Rp ${formatRupiah(_totalPrice)}",
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            // Checkout button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _totalItems > 0
                    ? () {
                        final itemsToCheckout = _localProducts
                            .where((p) => p.qty > 0)
                            .toList();
                        showDialog(
                          context: context,
                          builder: (context) => PaymentDialog(
                            amount: _totalPrice,
                            cartItems: itemsToCheckout,
                            staffUid: FirebaseAuth.instance.currentUser?.uid,
                            staffName: _formatDisplayName(_displayName),
                          ),
                        ).then((result) {
                          // Reset cart if transaction was successful
                          if (result == true) {
                            _resetCart();
                          }
                        });
                      }
                    : null,
                icon: const Icon(Icons.payments_outlined),
                label: const Text("Bayar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(
                    alpha: 0.3,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.lexendDeca(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
