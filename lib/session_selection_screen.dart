import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/home_screen.dart';
import 'package:photo_box/main.dart';

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
        title: Text("Voucher: $voucherCode",
            style: const TextStyle(color: textDark)),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: primaryYellow,
      ),
      body: Center(
        child: SingleChildScrollView(
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
              const SizedBox(height: 30),

              // --- PILIHAN 1: 3 FOTO ---
              _buildSessionOption(
                context,
                label: "3 FOTO STRIP",
                description: "Pakej Kilat & Jimat",
                icon: Icons.filter_3,
                totalTakes: 3,
                isFlipbook: false,
                isCalendar: false,
              ),

              const SizedBox(height: 15),

              // --- PILIHAN 2: FLIPBOOK ---
              _buildSessionOption(
                context,
                label: "FLIPBOOK ANIMASI",
                description: "Cetak 24 Frame Video & Stiker WA",
                icon: Icons.videocam,
                totalTakes: 24,
                isFlipbook: true,
                isCalendar: false,
              ),

              const SizedBox(height: 15),

              // --- PILIHAN 3: KALENDER 2026 ---
              _buildSessionOption(
                context,
                label: "KALENDER 2026",
                description: "3 Foto + Kalender Lengkap Libur Nasional",
                icon: Icons.calendar_month,
                totalTakes: 3, // Ubah menjadi 3 foto
                isFlipbook: false,
                isCalendar: true,
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
    required bool isCalendar,
  }) {
    return Card(
      color: backgroundLight,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                camera: camera,
                totalTakes: totalTakes,
                sessionId: voucherCode,
                voucherCode: voucherCode,
                isFlipbookMode: isFlipbook,
                isCalendarMode: isCalendar,
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: accentGrey,
                        fontSize: 12,
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
