import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/home_screen.dart';
import 'package:photo_box/main.dart'; // Import untuk warna tema

class SessionSelectionScreen extends StatelessWidget {
  final CameraDescription camera;
  const SessionSelectionScreen({super.key, required this.camera});

  void _startSession(BuildContext context, int totalTakes) {
    final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          camera: camera,
          totalTakes: totalTakes,
          sessionId: sessionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PILIH SESI FOTO'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Breakpoint untuk tata letak, misal 600
          bool useHorizontalLayout = constraints.maxWidth > 600;
          // Padding berdasarkan lebar layar
          double horizontalPadding = constraints.maxWidth * 0.05;

          if (useHorizontalLayout) {
            // Layout Row untuk layar lebar (Tablet Lanskap)
            return Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gunakan Expanded agar tombol mengisi ruang
                    Expanded(
                        child: _buildSessionButton(context, 3, "QUICK SHOT")),
                    const SizedBox(width: 20),
                    Expanded(
                        child: _buildSessionButton(context, 5, "STANDARD")),
                    const SizedBox(width: 20),
                    Expanded(child: _buildSessionButton(context, 10, "MEGA")),
                  ],
                ),
              ),
            );
          } else {
            // Layout Column untuk layar sempit (HP Potret/Lanskap Kecil)
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding * 2,
                      vertical: 30), // Padding lebih besar
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSessionButton(context, 3, "QUICK SHOT"),
                      const SizedBox(height: 25),
                      _buildSessionButton(context, 5, "STANDARD"),
                      const SizedBox(height: 25),
                      _buildSessionButton(context, 10, "MEGA SESSION"),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSessionButton(BuildContext context, int takes, String label) {
    return InkWell(
      // Gunakan InkWell untuk efek sentuhan
      onTap: () => _startSession(context, takes),
      borderRadius: BorderRadius.circular(25), // Sesuaikan dengan border radius
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
        decoration: BoxDecoration(
            color: backgroundDark, // Background abu-abu muda
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
                color: accentGrey.withAlpha(100), width: 1), // Border halus
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(50),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$takes',
                style: const TextStyle(
                    fontSize: 48,
                    color: primaryYellow, // Angka kuning
                    fontWeight: FontWeight.bold)),
            const Text('FOTO',
                style: TextStyle(
                    fontSize: 18,
                    color: textDark, // Teks gelap
                    letterSpacing: 2)),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: accentGrey, // Label abu-abu
                    fontWeight: FontWeight.w300)),
          ],
        ),
      ),
    );
  }
}
