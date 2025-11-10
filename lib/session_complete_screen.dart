// lib/session_complete_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // <-- Import diperlukan
import 'dart:async'; // <-- Import diperlukan
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/main.dart';
import 'package:photo_box/photostrip_creator_screen.dart';

class SessionCompleteScreen extends StatelessWidget {
  final List<XFile> images;
  final String sessionId;

  const SessionCompleteScreen({
    super.key,
    required this.images,
    required this.sessionId,
  });

  Future<void> _saveAllImages(BuildContext context) async {
    try {
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String sessionPath = '${appDirectory.path}/$sessionId';
      final Directory sessionDirectory = Directory(sessionPath);

      if (!await sessionDirectory.exists()) {
        await sessionDirectory.create(recursive: true);
      }

      for (int i = 0; i < images.length; i++) {
        final String newPath = '$sessionPath/photo_${i + 1}.jpg';
        await File(images[i].path).copy(newPath);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Semua foto disimpan di folder $sessionId')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan foto: $e')),
      );
    }
  }

  ///
  /// --- FUNGSI BARU UNTUK KONVERSI GAMBAR ---
  ///
  /// Mengonversi List<XFile> menjadi List<ui.Image>
  Future<List<ui.Image>> _convertXFilesToUiImages(List<XFile> xFiles) async {
    List<ui.Image> uiImages = [];
    for (XFile xFile in xFiles) {
      final Uint8List bytes = await xFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      uiImages.add(frameInfo.image);
    }
    return uiImages;
  }

  /// --- FUNGSI BARU UNTUK NAVIGASI ---
  Future<void> _navigateToCreator(BuildContext context) async {
    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Lakukan konversi
      final List<ui.Image> uiImages = await _convertXFilesToUiImages(images);

      if (!context.mounted) return;
      Navigator.pop(context); // Tutup loading dialog

      // Navigasi ke PhotostripCreatorScreen dengan data yang benar
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhotostripCreatorScreen(
            photos: uiImages, // <-- Parameter yang benar
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Tutup loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses gambar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundLight,
      appBar: AppBar(
        title: const Text("HASIL FOTO"),
        automaticallyImplyLeading: false, // Sembunyikan tombol back
      ),
      // Kode duplikat (AppBar, backgroundColor) telah dihapus dari sini
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.portrait
                ? _buildPortraitLayout(context)
                : _buildLandscapeLayout(context);
          },
        ),
      ),
    );
  }

  // Layout Potret (HP)
  Widget _buildPortraitLayout(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _buildImageGrid(crossAxisCount: 2), // 2 Kolom
        ),
        _buildActionButtons(context, isPortrait: true), // Tombol di bawah
      ],
    );
  }

  // Layout Lanskap (Tablet)
  Widget _buildLandscapeLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildImageGrid(crossAxisCount: 3), // 3 Kolom
        ),
        const VerticalDivider(width: 1, color: accentGrey),
        Expanded(
          flex: 2,
          child: _buildActionButtons(context,
              isPortrait: false), // Tombol di kanan
        ),
      ],
    );
  }

  // Widget Grid Foto
  Widget _buildImageGrid({required int crossAxisCount}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount, // Jumlah kolom dinamis
        crossAxisSpacing: 12.0, // Jarak antar gambar
        mainAxisSpacing: 12.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(images[index].path), fit: BoxFit.cover),
        );
      },
    );
  }

  // Widget Tombol Aksi
  Widget _buildActionButtons(BuildContext context, {required bool isPortrait}) {
    return Padding(
      padding: EdgeInsets.all(isPortrait ? 25.0 : 30.0), // Padding berbeda
      child: Column(
        mainAxisAlignment:
            isPortrait ? MainAxisAlignment.end : MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.download_outlined, size: 24),
            label: const Text('SIMPAN SEMUA'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isPortrait ? 18 : 20),
            ),
            onPressed: () => _saveAllImages(context),
          ),
          SizedBox(height: isPortrait ? 15 : 20),
          // Tombol buat photostrip dengan gaya outline
          OutlinedButton.icon(
            icon: const Icon(Icons.auto_awesome_outlined, size: 24),
            label: const Text('BUAT PHOTOSTRIP'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isPortrait ? 18 : 20),
            ),
            //
            // --- PANGGILAN FUNGSI DIUBAH ---
            //
            onPressed: () {
              _navigateToCreator(context); // <-- Memanggil fungsi konversi
            },
            //
            // --- ERROR LAMA (sudah diperbaiki) ---
            // onPressed: () {
            //   Navigator.push(
            //     context,
            //     MaterialPageRoute(
            //       builder: (context) => PhotostripCreatorScreen(
            //         sessionImages: images, // Ini salah
            //         sessionId: sessionId, // Ini salah
            //       ),
            //     ),
            //   );
            // },
            //
          ),
          SizedBox(height: isPortrait ? 15 : 20),
          // Tombol sesi baru dengan gaya outline berbeda
          TextButton.icon(
            // Gunakan TextButton untuk gaya berbeda
            icon: const Icon(Icons.add_a_photo_outlined, size: 24),
            label: const Text('SESI BARU'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isPortrait ? 18 : 20),
              foregroundColor: accentGrey, // Warna teks abu-abu
            ),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
  // Kurung kurawal '}' ekstra telah dihapus dari sini
}