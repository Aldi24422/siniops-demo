import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/mock_auth_controller.dart';
import '../../core/services/preview_mode_controller.dart';

class ManageStaffPage extends StatefulWidget {
  const ManageStaffPage({super.key});

  @override
  State<ManageStaffPage> createState() => _ManageStaffPageState();
}

class _ManageStaffPageState extends State<ManageStaffPage> {
  final MockAuthController _authController = MockAuthController.instance;

  // Form controllers for add dialog
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isAdding = false;
  String? _deletingUid;
  String _currentUserRole = 'owner';

  @override
  void initState() {
    super.initState();
    _currentUserRole = PreviewModeController.instance.previewRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  /// Show dialog to add new staff
  void _showAddStaffDialog() {
    _nameController.clear();
    _emailController.clear();
    _passwordController.clear();

    bool isPasswordObscure = true;
    String selectedRole = 'crew';

    final bool isOwner = _currentUserRole == 'owner';
    final List<Map<String, String>> roleOptions = [
      {'value': 'crew', 'label': 'Crew'},
      if (isOwner) {'value': 'outlet_manager', 'label': 'Outlet Manager'},
      if (isOwner) {'value': 'owner', 'label': 'Owner'},
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_add,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Tambah Tim',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (roleOptions.length > 1) ...[
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Role',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedRole,
                          isExpanded: true,
                          isDense: true,
                          dropdownColor: AppColors.surface,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          items: roleOptions.map((role) {
                            return DropdownMenuItem(
                              value: role['value'],
                              child: Text(
                                role['label']!,
                                style: GoogleFonts.lexendDeca(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setDialogState(() => selectedRole = val!);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passwordController,
                    obscureText: isPasswordObscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordObscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          setDialogState(() {
                            isPasswordObscure = !isPasswordObscure;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: _isAdding ? null : () => Navigator.pop(context),
                child: Text(
                  'Batal',
                  style: GoogleFonts.lexendDeca(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: _isAdding
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        final email = _emailController.text.trim();
                        final password = _passwordController.text;

                        if (name.isEmpty || email.isEmpty || password.isEmpty) {
                          _showSnackBar(
                            'Semua field harus diisi',
                            isError: true,
                          );
                          return;
                        }

                        if (password.length < 6) {
                          _showSnackBar(
                            'Password minimal 6 karakter',
                            isError: true,
                          );
                          return;
                        }

                        final navigator = Navigator.of(context);

                        setDialogState(() => _isAdding = true);
                        setState(() => _isAdding = true);

                        final result = await _authController.addStaff(
                          email: email,
                          password: password,
                          name: name,
                          role: selectedRole,
                        );

                        setDialogState(() => _isAdding = false);
                        setState(() => _isAdding = false);

                        if (result.success) {
                          navigator.pop();
                          _showSnackBar('✅ Karyawan berhasil ditambahkan');
                        } else {
                          _showSnackBar(
                            result.error ?? 'Gagal menambahkan',
                            isError: true,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isAdding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Simpan',
                        style: GoogleFonts.lexendDeca(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Show confirmation dialog before deleting
  void _confirmDelete(StaffData staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Hapus Akun?",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          "Anda yakin ingin menghapus akun ${staff.displayName}?\n\nIni adalah demo, data akan direset saat reload.",
          style: GoogleFonts.lexendDeca(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _deleteStaff(staff);
            },
            child: Text(
              "Hapus",
              style: GoogleFonts.lexendDeca(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStaff(StaffData staff) async {
    setState(() => _deletingUid = staff.uid);

    final success = await _authController.deleteStaff(staff.uid);

    if (mounted) {
      setState(() => _deletingUid = null);
      if (success) {
        _showSnackBar('Akun berhasil dihapus');
      } else {
        _showSnackBar('Gagal memproses permintaan', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Manajemen Tim",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 1.0,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text(
          "Tambah Tim",
          style: GoogleFonts.lexendDeca(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: StreamBuilder<List<StaffData>>(
        stream: _authController.getStaff(_currentUserRole),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Terjadi kesalahan',
                    style: GoogleFonts.lexendDeca(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final staffList = snapshot.data ?? [];

          if (staffList.isEmpty) {
            return _buildEmptyState();
          }

          final sortedList = List<StaffData>.from(staffList);
          sortedList.sort((a, b) {
            int getRank(String role) {
              if (role == 'owner') return 0;
              if (role == 'outlet_manager') return 1;
              return 2;
            }
            return getRank(a.role).compareTo(getRank(b.role));
          });

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: sortedList.length,
            itemBuilder: (context, index) => _buildStaffCard(sortedList[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum ada tim',
            style: GoogleFonts.lexendDeca(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tambahkan tim baru dengan tombol\ndi bawah',
            textAlign: TextAlign.center,
            style: GoogleFonts.lexendDeca(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(StaffData staff) {
    final isDeleting = _deletingUid == staff.uid;
    final currentUserUid = _authController.currentUserUid;

    Color roleColor;
    String roleLabel;

    switch (staff.role) {
      case 'owner':
        roleColor = Colors.purple;
        roleLabel = 'Owner';
        break;
      case 'outlet_manager':
        roleColor = Colors.orange;
        roleLabel = 'Manager';
        break;
      case 'crew':
      case 'cashier':
        roleColor = Colors.blue;
        roleLabel = 'Crew';
        break;
      default:
        roleColor = Colors.grey;
        roleLabel = staff.role;
        break;
    }

    bool canDelete = false;
    if (_currentUserRole == 'owner') {
      canDelete = staff.uid != currentUserUid;
    } else if (_currentUserRole == 'outlet_manager') {
      canDelete = staff.role == 'crew' || staff.role == 'cashier';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1), width: 1),
      ),
      elevation: 0,
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _getInitials(staff.displayName),
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          staff.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: GoogleFonts.lexendDeca(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    staff.email,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            if (canDelete)
              IconButton(
                onPressed: isDeleting ? null : () => _confirmDelete(staff),
                icon: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                tooltip: "Hapus Akun",
              ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }
}
