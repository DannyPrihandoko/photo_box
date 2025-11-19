import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_box/main.dart'; // Import untuk warna tema

// Enum aksi: Ulangi atau Lanjut
enum PreviewAction { retake, next }

class PreviewScreen extends StatefulWidget {
  final File imageFile;
  final bool allowRetake;
  final int retakesRemaining;

  const PreviewScreen({
    super.key,
    required this.imageFile,
    this.allowRetake = true,
    this.retakesRemaining = 0,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // --- SETTING DURASI 10 DETIK ---
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..forward(); // Mulai hitung mundur

    _animationController.addStatusListener((status) {
      // Jika waktu habis (10 detik), otomatis lanjut
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop(PreviewAction.next);
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
      backgroundColor: backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar indikator waktu (10 detik)
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: 1.0 -
                      _animationController.value, // Mundur dari penuh ke kosong
                  backgroundColor: accentGrey.withAlpha(50),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(primaryYellow),
                  minHeight: 6,
                );
              },
            ),

            Expanded(
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

  // Layout Potret (HP)
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 20.0),
          child: Text("BAGUS!",
              style: TextStyle(
                  fontSize: 28, color: textDark, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(widget.imageFile, fit: BoxFit.contain)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Tombol Ulangi (Hanya muncul jika kuota retake masih ada)
              if (widget.allowRetake) Expanded(child: _buildRetakeButton()),

              if (widget.allowRetake) const SizedBox(width: 15),

              // Tombol Lanjut
              Expanded(child: _buildContinueButton()),
            ],
          ),
        )
      ],
    );
  }

  // Layout Lanskap (Tablet)
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
            padding: const EdgeInsets.only(right: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("BAGUS!",
                    style: TextStyle(
                        fontSize: 32,
                        color: textDark,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 50),

                // Tombol Ulangi (Kondisional)
                if (widget.allowRetake) ...[
                  _buildRetakeButton(isLandscape: true),
                  const SizedBox(height: 30),
                ],

                _buildContinueButton(isLandscape: true),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildRetakeButton({bool isLandscape = false}) {
    return OutlinedButton.icon(
      icon: Icon(Icons.refresh, size: isLandscape ? 28 : 24),
      label:
          Text('ULANGI (${widget.retakesRemaining})', // Menampilkan sisa kuota
              style: TextStyle(fontSize: isLandscape ? 20 : 18)),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, isLandscape ? 60 : 55),
        foregroundColor: textDark,
        side: const BorderSide(color: accentGrey, width: 1.5),
      ),
      onPressed: () {
        Navigator.of(context).pop(PreviewAction.retake);
      },
    );
  }

  Widget _buildContinueButton({bool isLandscape = false}) {
    return ElevatedButton.icon(
      icon: Icon(Icons.check_circle_outline, size: isLandscape ? 28 : 24),
      label: Text('LANJUT', style: TextStyle(fontSize: isLandscape ? 20 : 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryYellow,
        foregroundColor: textDark,
        minimumSize: Size(0, isLandscape ? 60 : 55),
      ),
      onPressed: () {
        Navigator.of(context).pop(PreviewAction.next);
      },
    );
  }
}
