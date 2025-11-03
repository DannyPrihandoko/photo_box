import 'dart:io';
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
      // 1. Hubungkan ke printer
      await _printingService.connectToPrinter('PRJ-80BT');

      // 2. Cetak gambar dari path
      await _printingService.printImage(widget.imagePath);

      // 3. Tampilkan pesan sukses
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto berhasil dicetak!'),
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
      // 4. Set state selesai printing
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
      // 5. (Opsional) Putuskan koneksi setelah selesai
      // await _printingService.disconnect();
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