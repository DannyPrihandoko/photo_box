import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/home_screen.dart';
import 'package:photo_box/main.dart'; // Import untuk warna tema

class SessionSelectionScreen extends StatelessWidget {
  final CameraDescription camera;
  final String voucherCode; // <--- Variabel baru ditambahkan

  // Update Constructor untuk menerima voucherCode
  const SessionSelectionScreen({
    super.key, 
    required this.camera,
    required this.voucherCode, // <--- Wajib diisi
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark, // Menggunakan warna dari main.dart
      appBar: AppBar(
        // Menampilkan Kode Voucher di Judul
        title: Text("Voucher: $voucherCode", style: const TextStyle(color: textDark)),
        automaticallyImplyLeading: false, // Menghilangkan tombol back otomatis
        centerTitle: true,
        backgroundColor: primaryYellow,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "PILIH JUMLAH FOTO",
                style: TextStyle(
                  color: textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),

              // --- OPSI TUNGGAL: 3 FOTO ---
              _buildSessionOption(
                context,
                label: "3 FOTO",
                description: "Paket Kilat & Hemat",
                icon: Icons.filter_3,
                totalTakes: 3,
              ),

              // Opsi 5 dan 10 foto telah dihapus.
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionOption(
    BuildContext context, {
    required String label,
    required String description,
    required IconData icon,
    required int totalTakes,
  }) {
    return Card(
      color: backgroundLight,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          // Kita gunakan Kode Voucher sebagai Session ID agar folder rapi
          final String sessionId = voucherCode;

          // Navigasi ke HomeScreen dengan membawa voucherCode
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                camera: camera,
                totalTakes: totalTakes,
                sessionId: sessionId,
                voucherCode: voucherCode, // <--- Teruskan kode ke Home
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          child: Row(
            children: [
              // Ikon di sebelah kiri
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: primaryYellow,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: textDark, size: 30),
              ),
              const SizedBox(width: 20),

              // Teks Label dan Deskripsi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: accentGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Panah navigasi di kanan
              const Icon(Icons.arrow_forward_ios, color: accentGrey),
            ],
          ),
        ),
      ),
    );
  }
}