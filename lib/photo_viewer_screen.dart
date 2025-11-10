import 'dart:io';
import 'dart:typed_data'; // <-- Tambahan
import 'dart:ui' as ui; // <-- Tambahan
import 'package:flutter/material.dart';
import 'package:photo_box/printing_services.dart'; // Import service kita

class PhotoViewerScreen extends StatefulWidget {
  final String imagePath;

  const PhotoViewerScreen({Key? key, required this.imagePath}) : super(key: key);

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  final PrintingService _printingService = PrintingService();
  bool _isPrinting = false;

  Future<void> _printPhoto() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      // --- LOGIKA BARU UNTUK MEMANGGIL FUNGSI YANG ADA ---

      // 1. Muat file gambar dari path
      final Uint8List fileBytes = await File(widget.imagePath).readAsBytes();

      // 2. Decode gambar menjadi format ui.Image
      final codec = await ui.instantiateImageCodec(fileBytes);
      final frame = await codec.getNextFrame();
      final ui.Image imageToPrint = frame.image;

      // 3. Panggil fungsi printPhotoStripPdf (yang ada di service Anda)
      // Kita bisa atur mau dikonversi jadi B&W atau tidak di sini
      await _printingService.printPhotoStripPdf(
        imageToPrint,
        convertToBw: false, // Ubah ke true jika ingin hitam putih
      );

      // 4. Tampilkan pesan sukses
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mempersiapkan cetak PDF...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Tampilkan pesan error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Set state selesai printing
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lihat Foto'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Tombol Print
          if (_isPrinting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                  width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: _printPhoto,
              tooltip: 'Cetak Foto',
            ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Hero(
          tag: widget.imagePath,
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}