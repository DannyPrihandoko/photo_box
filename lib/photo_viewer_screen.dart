import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_box/printing_services.dart'; // Import Service Printer
import 'package:photo_box/main.dart'; // Import warna tema (primaryYellow, textDark)

class PhotoViewerScreen extends StatefulWidget {
  final File imageFile;

  const PhotoViewerScreen({super.key, required this.imageFile});

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  bool _isPrinting = false;

  Future<void> _printImage() async {
    setState(() => _isPrinting = true);

    // Panggil service print dari file
    bool success = await PrinterServices().printImageFromFile(widget.imageFile);

    if (mounted) {
      setState(() => _isPrinting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil mencetak!"), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mencetak. Cek koneksi printer."), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // --- TOMBOL PRINT BARU ---
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _isPrinting 
              ? const Center(
                  child: SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: primaryYellow, strokeWidth: 2)
                  )
                )
              : IconButton(
                  icon: const Icon(Icons.print, color: Colors.white),
                  tooltip: "Cetak Foto",
                  onPressed: _printImage,
                ),
          )
        ],
      ),
      body: Center(
        child: Hero(
          tag: widget.imageFile.path,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: Image.file(widget.imageFile),
          ),
        ),
      ),
    );
  }
}