import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/gallery_screen.dart';
import 'package:photo_box/main.dart'; // Import tema
import 'package:photo_box/printer_settings_screen.dart'; // Import Screen Printer
import 'package:photo_box/screens/admin_setup_screen.dart'; // Import Setup Admin
import 'package:photo_box/services/voucher_service.dart'; // Import Service Voucher
import 'package:photo_box/session_selection_screen.dart'; // Screen Pemilihan Mode

class WelcomeScreen extends StatefulWidget {
  final CameraDescription camera;
  const WelcomeScreen({super.key, required this.camera});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final VoucherService _voucherService = VoucherService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  // --- KODE RAHASIA ADMIN ---
  static const String _adminBypassCode = "se1nyu2m3";

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  // --- LOGIKA VOUCHER ---
  Future<void> _submitVoucher() async {
    String rawInput = _codeController.text.trim();
    if (rawInput.isEmpty) return;

    // 1. CEK KODE ADMIN (BYPASS)
    if (rawInput == _adminBypassCode) {
      if (mounted) {
        Navigator.pop(context); // Tutup Dialog
        _codeController.clear();

        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SessionSelectionScreen(
                    camera: widget.camera,
                    voucherCode: "ADMIN",
                  )),
        );

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Login Admin Berhasil!"),
            backgroundColor: Colors.blueAccent));
      }
      return;
    }

    // 2. LOGIKA VOUCHER USER
    String code = rawInput.toUpperCase();

    // Cek apakah IP Admin sudah disetting
    bool isConfigured = await _voucherService.isAdminConfigured();
    if (!isConfigured) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Admin belum disetting! Hubungi petugas."),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    setState(() => _isLoading = true);

    // Verifikasi ke Server
    final result = await _voucherService.verifyVoucher(code);

    setState(() => _isLoading = false);

    if (mounted) {
      if (result['valid'] == true) {
        Navigator.pop(context); // Tutup Dialog
        _codeController.clear();

        // Pindah ke Halaman Pemilihan Sesi (Mode Struk/Normal)
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SessionSelectionScreen(
                    camera: widget.camera,
                    voucherCode: code,
                  )),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['message'] ?? "Kode Salah / Kadaluarsa"),
            backgroundColor: Colors.red));
      }
    }
  }

  void _showVoucherDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          "Masukkan Kode Voucher",
          style: TextStyle(color: textDark, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              autofocus: true,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.none,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5,
                  color: textDark),
              decoration: const InputDecoration(
                hintText: "Kode",
                hintStyle: TextStyle(color: Colors.grey, letterSpacing: 2),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: backgroundDark,
                contentPadding: EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Dapatkan kode dari kasir.",
              style: TextStyle(color: accentGrey, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: accentGrey)),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitVoucher,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryYellow,
              foregroundColor: textDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: textDark, strokeWidth: 2))
                : const Text("MULAI FOTO",
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmileyIcon({double size = 150}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: primaryYellow,
            shape: BoxShape.circle,
          ),
        ),
        Positioned(
          top: size * 0.3,
          child: Row(
            children: [
              Container(
                  width: size * 0.1,
                  height: size * 0.15,
                  color: textDark,
                  margin: EdgeInsets.symmetric(horizontal: size * 0.1)),
              Container(
                  width: size * 0.1,
                  height: size * 0.15,
                  color: textDark,
                  margin: EdgeInsets.symmetric(horizontal: size * 0.1)),
            ],
          ),
        ),
        Positioned(
          bottom: size * 0.25,
          child: Container(
            width: size * 0.5,
            height: size * 0.25,
            decoration: BoxDecoration(
              color: textDark,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(size * 0.25)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        bool isPortrait = orientation == Orientation.portrait;

        return Scaffold(
          backgroundColor: backgroundLight,
          body: Stack(
            children: [
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 40),
                    child: isPortrait
                        ? _buildPortraitLayout(context)
                        : _buildLandscapeLayout(context),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: 20,
                child: IconButton(
                  icon: const Icon(Icons.settings_remote,
                      color: accentGrey, size: 30),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AdminSetupScreen())),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.print, color: accentGrey, size: 30),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  const PrinterSettingsScreen())),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.photo_library_outlined,
                          color: accentGrey, size: 35),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const GalleryScreen())),
                    ),
                  ],
                ),
              ),
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Text('Created by danny © 2025',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accentGrey, fontSize: 14)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSmileyIcon(size: 180),
        const SizedBox(height: 40),
        const Text('Selamat Datang di',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 24, color: textDark, fontWeight: FontWeight.w300)),
        const Text('PHOTOBOX SENYUM!',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 42,
                color: primaryYellow,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 60),
        ElevatedButton(
          onPressed: _showVoucherDialog,
          style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 20),
              textStyle:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          child: const Text('MULAI'),
        ),
        const SizedBox(height: 15),
        const Text('Sentuh tombol untuk memulai',
            style: TextStyle(color: accentGrey, fontSize: 16)),
      ],
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(flex: 2, child: _buildSmileyIcon(size: 250)),
        const SizedBox(width: 40),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Selamat Datang di',
                  style: TextStyle(
                      fontSize: 32,
                      color: textDark,
                      fontWeight: FontWeight.w300)),
              const Text('PHOTOBOX SENYUM!',
                  style: TextStyle(
                      fontSize: 64,
                      color: primaryYellow,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3)),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: _showVoucherDialog,
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 70, vertical: 25),
                    textStyle: const TextStyle(
                        fontSize: 28, fontWeight: FontWeight.bold)),
                child: const Text('MULAI'),
              ),
              const SizedBox(height: 15),
              const Text('Sentuh tombol untuk memulai',
                  style: TextStyle(color: accentGrey, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
}
