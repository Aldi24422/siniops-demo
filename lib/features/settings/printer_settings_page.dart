import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/printer_service.dart';

class PrinterSettingsPage extends StatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  State<PrinterSettingsPage> createState() => _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends State<PrinterSettingsPage> {
  final PrinterService _printerService = PrinterService.instance;

  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isPrinting = false;
  bool _isSavingWifi = false;
  bool _isSavingAddress = false;
  String? _errorMessage;

  // Wi-Fi footer settings controllers
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isLoadingSettings = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _checkBluetoothAndScan();
    }
    _loadSettings();
  }

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Load existing settings from SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoadingSettings = true);
    try {
      final wifiSettings = await _printerService.getWifiSettings();
      final storeSettings = await _printerService.getStoreSettings();
      _ssidController.text = wifiSettings.ssid;
      _passwordController.text = wifiSettings.password;
      _addressController.text = storeSettings.address;
    } catch (e) {
      debugPrint('[PrinterSettings] Error loading settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  /// Save Wi-Fi settings to SharedPreferences
  Future<void> _saveWifiSettings() async {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text.trim();

    if (ssid.isEmpty) {
      _showSnackBar("Nama Wi-Fi tidak boleh kosong", isError: true);
      return;
    }

    setState(() => _isSavingWifi = true);

    try {
      final success = await _printerService.saveWifiSettings(ssid, password);
      if (success) {
        _showSnackBar("✅ Pengaturan Wi-Fi berhasil disimpan", isError: false);
      } else {
        _showSnackBar("Gagal menyimpan pengaturan", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSavingWifi = false);
      }
    }
  }

  /// Save shop address to SharedPreferences
  Future<void> _saveShopAddress() async {
    final address = _addressController.text.trim();

    if (address.isEmpty) {
      _showSnackBar("Alamat toko tidak boleh kosong", isError: true);
      return;
    }

    setState(() => _isSavingAddress = true);

    try {
      final success = await _printerService.saveShopAddress(address);
      if (success) {
        _showSnackBar("✅ Alamat toko berhasil disimpan", isError: false);
      } else {
        _showSnackBar("Gagal menyimpan alamat", isError: true);
      }
    } catch (e) {
      _showSnackBar("Error: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSavingAddress = false);
      }
    }
  }

  Future<void> _checkBluetoothAndScan() async {
    final isAvailable = await _printerService.isBluetoothAvailable();
    if (!isAvailable) {
      setState(() {
        _errorMessage = "Bluetooth tidak tersedia di perangkat ini";
      });
      return;
    }

    final isOn = await _printerService.isBluetoothOn();
    if (!isOn) {
      setState(() {
        _errorMessage = "Bluetooth tidak aktif. Silakan aktifkan Bluetooth.";
      });
      return;
    }

    await _scanDevices();
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final devices = await _printerService.scanDevices();
      setState(() {
        _devices = devices;
        _isScanning = false;
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = "Gagal memindai perangkat: $e";
      });
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final success = await _printerService.connect(device);
      setState(() {
        _isConnecting = false;
      });

      if (success) {
        _showSnackBar("Terhubung ke ${device.name}", isError: false);
      } else {
        _showSnackBar("Gagal terhubung ke ${device.name}", isError: true);
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      _showSnackBar("Error: $e", isError: true);
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    setState(() {});
    _showSnackBar("Printer terputus", isError: false);
  }

  Future<void> _testPrint() async {
    if (!_printerService.isConnected) {
      _showSnackBar("Printer tidak terhubung", isError: true);
      return;
    }

    setState(() {
      _isPrinting = true;
    });

    try {
      final success = await _printerService.printTestReceipt();
      setState(() {
        _isPrinting = false;
      });

      if (success) {
        _showSnackBar("✅ Test print berhasil!", isError: false);
      } else {
        _showSnackBar("Test print gagal", isError: true);
      }
    } catch (e) {
      setState(() {
        _isPrinting = false;
      });
      _showSnackBar("Error: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
          "Pengaturan Printer",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: _isScanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, color: AppColors.primary),
              onPressed: _isScanning ? null : _scanDevices,
              tooltip: "Pindai Ulang",
            ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.withValues(alpha: 0.2),
            height: 1.0,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- WEB WARNING ---
                if (kIsWeb) _buildWebWarning(),

                // --- SECTION 1: CONNECTION STATUS ---
                if (!kIsWeb) _buildStatusBar(),

                // --- ERROR MESSAGE ---
                if (_errorMessage != null && !kIsWeb) _buildErrorBanner(),

                // --- SECTION HEADER: Koneksi Printer ---
                if (!kIsWeb) ...[
                  _buildSectionHeader(
                    icon: Icons.bluetooth,
                    title: "Koneksi Printer",
                    subtitle: "Pilih printer thermal untuk dihubungkan",
                  ),

                  // --- DEVICE LIST ---
                  _devices.isEmpty ? _buildEmptyState() : _buildDeviceList(),

                  const SizedBox(height: 16),
                ],

                // --- SECTION 2: Store Address Settings ---
                _buildSectionHeader(
                  icon: Icons.store,
                  title: "Pengaturan Toko",
                  subtitle: "Alamat yang akan dicetak di struk",
                ),
                _buildAddressSettingsSection(),

                const SizedBox(height: 16),

                // --- SECTION 3: Wi-Fi Footer Settings ---
                _buildSectionHeader(
                  icon: Icons.wifi,
                  title: "Pengaturan Footer Struk",
                  subtitle: "Info Wi-Fi yang akan dicetak di struk",
                ),
                _buildWifiSettingsSection(),

                const SizedBox(height: 16),

                // --- SECTION 4: Test Print ---
                if (_printerService.isConnected && !kIsWeb) ...[
                  _buildSectionHeader(
                    icon: Icons.print,
                    title: "Test Print",
                    subtitle:
                        "Cetak struk percobaan dengan pengaturan saat ini",
                  ),
                  _buildTestPrintSection(),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build web platform warning banner
  Widget _buildWebWarning() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Mode Browser Terdeteksi",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Fitur Bluetooth Printer hanya berjalan di Android/iOS Fisik, bukan di Browser. Anda masih dapat mengatur alamat toko dan Wi-Fi untuk struk.",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 12,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
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
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final isConnected = _printerService.isConnected;
    final deviceName = _printerService.connectedDevice?.name ?? "Unknown";

    // Use RED for disconnected, GREEN for connected
    final statusColor = isConnected ? AppColors.success : AppColors.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: statusColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? "Terhubung" : "Tidak Terhubung",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (isConnected)
                  Text(
                    deviceName,
                    style: GoogleFonts.lexendDeca(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (isConnected)
            TextButton.icon(
              onPressed: _disconnect,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text("Putuskan"),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.error.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.print_disabled,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _isScanning
                  ? "Memindai perangkat..."
                  : "Tidak ada perangkat ditemukan",
              style: GoogleFonts.lexendDeca(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Pastikan printer sudah di-pair via Bluetooth",
              style: GoogleFonts.lexendDeca(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!_isScanning)
              ElevatedButton.icon(
                onPressed: _scanDevices,
                icon: const Icon(Icons.refresh),
                label: const Text("Pindai Ulang"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: _devices.map((device) {
          final isConnected =
              _printerService.connectedDevice?.address == device.address;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isConnected
                    ? AppColors.success.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: isConnected
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                child: Icon(
                  Icons.print,
                  color: isConnected ? AppColors.success : AppColors.primary,
                ),
              ),
              title: Text(
                device.name ?? "Unknown Device",
                style: GoogleFonts.lexendDeca(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                device.address ?? "",
                style: GoogleFonts.lexendDeca(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: isConnected
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Terhubung",
                        style: GoogleFonts.lexendDeca(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    )
                  : _isConnecting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
              onTap: _isConnecting
                  ? null
                  : () {
                      if (isConnected) {
                        _disconnect();
                      } else {
                        _connectToDevice(device);
                      }
                    },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build address settings section
  Widget _buildAddressSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingSettings
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Address TextField
                Text(
                  "Alamat Toko",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: "Contoh: Jl. Contoh No. 123, Surabaya",
                    hintStyle: GoogleFonts.lexendDeca(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(
                      Icons.location_on_outlined,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingAddress ? null : _saveShopAddress,
                    icon: _isSavingAddress
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSavingAddress ? "Menyimpan..." : "Simpan Alamat",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Build Wi-Fi settings section with form inputs
  Widget _buildWifiSettingsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _isLoadingSettings
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SSID TextField
                Text(
                  "Nama Wi-Fi (SSID)",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ssidController,
                  decoration: InputDecoration(
                    hintText: "Contoh: SiniNgopi",
                    hintStyle: GoogleFonts.lexendDeca(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.wifi, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Password TextField
                Text(
                  "Password Wi-Fi",
                  style: GoogleFonts.lexendDeca(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    hintText: "Masukkan password",
                    hintStyle: GoogleFonts.lexendDeca(
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  style: GoogleFonts.lexendDeca(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingWifi ? null : _saveWifiSettings,
                    icon: _isSavingWifi
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSavingWifi
                          ? "Menyimpan..."
                          : "Simpan Pengaturan Wi-Fi",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Info text
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Info ini akan dicetak di bagian bawah struk",
                        style: GoogleFonts.lexendDeca(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  /// Build test print section
  Widget _buildTestPrintSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 48,
            color: AppColors.secondary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          Text(
            "Cetak struk percobaan untuk memastikan\nprinter dan pengaturan berfungsi dengan benar",
            textAlign: TextAlign.center,
            style: GoogleFonts.lexendDeca(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPrinting ? null : _testPrint,
              icon: _isPrinting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print),
              label: Text(_isPrinting ? "Mencetak..." : "🖨️ Test Print"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
