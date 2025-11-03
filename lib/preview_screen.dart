import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_box/main.dart'; // Import untuk warna tema
import 'package:photo_box/main.dart'; // Import untuk warna tema

enum PreviewAction { retake, continuePhoto }

class PreviewScreen extends StatefulWidget {
  final File imageFile;
  const PreviewScreen({super.key, required this.imageFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..forward(); // Animasi progress bar dimulai
    _animationController.addStatusListener((status) {
      // Otomatis lanjut jika waktu habis
      // Otomatis lanjut jika waktu habis
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop(PreviewAction.continuePhoto);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight, // Latar belakang putih
      backgroundColor: backgroundLight, // Latar belakang putih
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar di atas
            // Progress bar di atas
            LinearProgressIndicator(
              value: _animationController.value,
              backgroundColor: accentGrey.withAlpha(100), // Abu-abu transparan
              valueColor:
                  const AlwaysStoppedAnimation<Color>(primaryYellow), // Kuning
            ),
            Expanded(
              // Pilih layout berdasarkan orientasi
              child: OrientationBuilder(
                builder: (context, orientation) {
                  return orientation == Orientation.portrait
                      ? _buildPortraitLayout()
                      : _buildLandscapeLayout();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Layout untuk Potret (HP)
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Text("BAGUS!",
              style: TextStyle(
                  fontSize: 28, // Ukuran font disesuaikan
                  color: textDark,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0), // Padding disesuaikan
            child: ClipRRect(
                borderRadius: BorderRadius.circular(15), // Sudut lebih bulat
                child: Image.file(widget.imageFile, fit: BoxFit.contain)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Tombol Ulangi (Outline)
              Expanded(child: _buildRetakeButton()),
              const SizedBox(width: 15),
              // Tombol Lanjut (Elevated)
              Expanded(child: _buildContinueButton()),
            ],
          ),
        )
      ],
    );
  }

  // Layout untuk Lanskap (Tablet)
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(widget.imageFile, fit: BoxFit.contain)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 30), // Padding kanan
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("BAGUS!",
                    style: TextStyle(
                        fontSize: 32,
                        color: textDark,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 50),
                _buildRetakeButton(isLandscape: true), // Tombol lebih besar
                const SizedBox(height: 30),
                _buildContinueButton(isLandscape: true), // Tombol lebih besar
              ],
            ),
          ),
        )
      ],
    );
  }

  // Widget untuk tombol Ulangi
  Widget _buildRetakeButton({bool isLandscape = false}) {
    return OutlinedButton.icon(
      icon: Icon(Icons.replay, size: isLandscape ? 28 : 24),
      label: Text('ULANGI', style: TextStyle(fontSize: isLandscape ? 20 : 18)),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, isLandscape ? 60 : 55), // Tinggi berbeda
        foregroundColor: textDark,
        side: const BorderSide(color: accentGrey, width: 1.5),
      ),
      onPressed: () {
        Navigator.of(context).pop(PreviewAction.retake);
      },
    );
  }

  // Widget untuk tombol Lanjut
  Widget _buildContinueButton({bool isLandscape = false}) {
    return ElevatedButton.icon(
      icon: Icon(Icons.check_circle_outline, size: isLandscape ? 28 : 24),
      label: Text('LANJUT', style: TextStyle(fontSize: isLandscape ? 20 : 18)),
      style: ElevatedButton.styleFrom(
        minimumSize: Size(0, isLandscape ? 60 : 55), // Tinggi berbeda
      ),
      onPressed: () {
        Navigator.of(context).pop(PreviewAction.continuePhoto);
      },
    );
  }
}
