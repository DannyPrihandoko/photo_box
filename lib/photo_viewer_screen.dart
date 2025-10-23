import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:photo_box/main.dart'; // <-- HAPUS BARIS INI

class PhotoViewerScreen extends StatelessWidget {
  final File imageFile;

  const PhotoViewerScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Background hitam untuk fokus
      appBar: AppBar(
        backgroundColor: Colors.black, // AppBar hitam
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close,
              color: Colors.white), // Tombol close putih
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: Hero(
          tag: imageFile.path, // Pastikan tag Hero sama dengan di galeri
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0, // Batas zoom
            child: Image.file(imageFile),
          ),
        ),
      ),
    );
  }
}
