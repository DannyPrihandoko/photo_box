import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/gallery_screen.dart';
import 'package:photo_box/main.dart'; // Import untuk warna tema
import 'package:photo_box/session_selection_screen.dart';

class WelcomeScreen extends StatelessWidget {
  final CameraDescription camera;
  const WelcomeScreen({super.key, required this.camera});

  // Widget untuk ikon smiley sederhana
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
        // Mata
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
        // Senyum
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
          // Background putih bersih
          backgroundColor: backgroundLight,
          body: Stack(
            children: [
              // Layout utama (Column untuk potret, Row untuk lanskap)
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

              // Tombol Galeri
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.photo_library_outlined, // Ikon outline
                      color: accentGrey, // Warna abu-abu
                      size: 35),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GalleryScreen()),
                    );
                  },
                ),
              ),

              // Footer
              const Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Text(
                  'Created by danny © 2025',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: accentGrey, // Warna abu-abu
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Layout untuk mode Potret (HP)
  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSmileyIcon(size: 180), // Ukuran ikon disesuaikan
        const SizedBox(height: 40),
        const Text(
          'Selamat Datang di',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            color: textDark,
            fontWeight: FontWeight.w300,
          ),
        ),
        const Text(
          'PHOTOBOX CERIA!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 42, // Ukuran font disesuaikan
            color: primaryYellow,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 60),
        ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SessionSelectionScreen(camera: camera)),
            );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: 60, vertical: 20), // Padding disesuaikan
            textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold), // Ukuran teks tombol
          ),
          child: const Text('MULAI'),
        ),
        const SizedBox(height: 15),
        const Text(
          'Sentuh tombol untuk memulai',
          style: TextStyle(
            color: accentGrey,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  // Layout untuk mode Lanskap (Tablet)
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          flex: 2,
          child: _buildSmileyIcon(size: 250), // Ukuran ikon lebih besar
        ),
        const SizedBox(width: 40),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selamat Datang di',
                style: TextStyle(
                  fontSize: 32, // Ukuran font lebih besar
                  color: textDark,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const Text(
                'PHOTOBOX CERIA!',
                style: TextStyle(
                  fontSize: 64, // Ukuran font lebih besar
                  color: primaryYellow,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 80),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            SessionSelectionScreen(camera: camera)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 70, vertical: 25), // Padding lebih besar
                  textStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold), // Ukuran teks tombol
                ),
                child: const Text('MULAI'),
              ),
              const SizedBox(height: 15),
              const Text(
                'Sentuh tombol untuk memulai',
                style: TextStyle(
                  color: accentGrey,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
