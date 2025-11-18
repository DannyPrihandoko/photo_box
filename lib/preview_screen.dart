import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_box/main.dart'; // Untuk warna

enum PreviewAction { retake, next }

class PreviewScreen extends StatelessWidget {
  final File imageFile;
  final bool allowRetake; // Parameter baru
  final int retakesRemaining; // Parameter baru (opsional)

  const PreviewScreen({
    super.key,
    required this.imageFile,
    this.allowRetake = true, // Default true
    this.retakesRemaining = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Menampilkan gambar
          Image.file(imageFile, fit: BoxFit.cover),

          // Tombol Kontrol di Bawah
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Tombol Retake (Hanya muncul jika allowRetake == true)
                if (allowRetake)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(PreviewAction.retake);
                    },
                    icon: const Icon(Icons.refresh, color: textDark),
                    label: Text("ULANGI ($retakesRemaining)"), // Info sisa
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: textDark,
                    ),
                  ),

                // Tombol Lanjut
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop(PreviewAction.next);
                  },
                  icon: const Icon(Icons.check, color: textDark),
                  label: const Text("LANJUT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryYellow,
                    foregroundColor: textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
