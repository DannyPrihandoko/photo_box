import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/home_screen.dart';
import 'package:photo_box/main.dart'; // Import untuk warna tema

class SessionSelectionScreen extends StatelessWidget {
  final CameraDescription camera;
  final String voucherCode;

  const SessionSelectionScreen({
    super.key, 
    required this.camera,
    required this.voucherCode, 
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark, 
      appBar: AppBar(
        title: Text("Voucher: $voucherCode", style: const TextStyle(color: textDark)),
        automaticallyImplyLeading: false, 
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
                "PILIH MOD FOTO",
                style: TextStyle(
                  color: textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),

              // --- PILIHAN 1: 3 FOTO ---
              _buildSessionOption(
                context,
                label: "3 FOTO",
                description: "Pakej Kilat & Jimat",
                icon: Icons.filter_3,
                totalTakes: 3,
                isFlipbook: false, // Normal Foto
              ),
              
              const SizedBox(height: 20),

              // --- PILIHAN 2: FLIPBOOK ---
              _buildSessionOption(
                context,
                label: "FLIPBOOK",
                description: "Cetak 24 Frame Video (3 Saat)",
                icon: Icons.videocam,
                totalTakes: 24,
                isFlipbook: true, // Mod Flipbook
              ),
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
    required bool isFlipbook,
  }) {
    return Card(
      color: backgroundLight,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          final String sessionId = voucherCode;

          // Navigasi ke HomeScreen dengan membawa parameter isFlipbookMode
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                camera: camera,
                totalTakes: totalTakes,
                sessionId: sessionId,
                voucherCode: voucherCode,
                isFlipbookMode: isFlipbook, // Parameter untuk mod flipbook automatik
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
              Container(
                padding: const EdgeInsets.all(15),
                decoration: const BoxDecoration(
                  color: primaryYellow,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: textDark, size: 30),
              ),
              const SizedBox(width: 20),
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
              const Icon(Icons.arrow_forward_ios, color: accentGrey),
            ],
          ),
        ),
      ),
    );
  }
}