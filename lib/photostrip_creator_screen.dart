// lib/photostrip_creator_screen.dart

import 'dart:ui' as ui;
// import 'dart:typed_data'; // <-- DIHAPUS (menyebabkan error 'unused_import')
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:photo_box/printing_services.dart'; // Pastikan path ini benar
// Import 'session_complete_screen.dart' DIHAPUS (menyebabkan error 'missing_required_argument')

class PhotostripCreatorScreen extends StatefulWidget {
  // Saya asumsikan Anda menerima daftar gambar dari layar sebelumnya
  final List<ui.Image> photos;

  /// --- PERBAIKAN LINT (use_super_parameters) ---
  const PhotostripCreatorScreen({
    super.key, // <-- Diubah
    required this.photos,
  });
  // --- Akhir Perbaikan ---

  @override
  State<PhotostripCreatorScreen> createState() =>
      _PhotostripCreatorScreenState();
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  /// Kunci Global untuk menangkap widget sebagai gambar
  final GlobalKey _globalKey = GlobalKey();

  /// State untuk mengontrol mode preview Hitam Putih
  bool _isBwPreview = false;

  /// Instance dari layanan printing
  final PrintingService _printingServices = PrintingService();

  // (Asumsi) Anda memiliki state untuk printer yang dipilih
  BluetoothDevice? _selectedPrinter;
  bool _isPrinting = false;

  /// Matriks standar untuk konversi ke Grayscale (Luminance)
  static const ColorFilter grayscaleFilter = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  /// Fungsi untuk menangkap RepaintBoundary sebagai ui.Image
  Future<ui.Image?> _capturePhotostrip() async {
    if (_globalKey.currentContext == null) return null;

    try {
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // Tangkap dengan pixelRatio yang lebih tinggi untuk kualitas cetak
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      return image;
    } catch (e) {
      // print("Error menangkap gambar: $e"); // <-- Dihapus (error 'avoid_print')
      return null;
    }
  }

  /// Fungsi yang dipanggil saat tombol cetak ditekan
  Future<void> _onPrintButtonPressed() async {
    setState(() {
      _isPrinting = true;
    });

    // 1. Tangkap gambar dari UI
    final ui.Image? capturedImage = await _capturePhotostrip();
    if (capturedImage == null) {
      // print("Gagal menangkap gambar untuk dicetak."); // <-- Dihapus (error 'avoid_print')
      setState(() {
        _isPrinting = false;
      });
      return;
    }

    // (Asumsi) Panggil fungsi cetak.
    if (_selectedPrinter != null) {
      // Cetak ke Printer Thermal
      await _printingServices.printPhotoStripEscPos(
        _selectedPrinter!,
        capturedImage,
        convertToBw: _isBwPreview, // <-- Menggunakan state preview
      );
    } else {
      // Cetak ke Printer Standar (via PDF)
      await _printingServices.printPhotoStripPdf(
        capturedImage,
        convertToBw: _isBwPreview, // <-- Menggunakan state preview
      );
    }

    setState(() {
      _isPrinting = false;
    });

    //
    // --- PERBAIKAN NAVIGASI (Fix 'missing_required_argument') ---
    //
    // Pindah ke layar awal (Sesi Baru)
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    //
    // --- Akhir Perbaikan ---
    //
  }

  // (Placeholder) Fungsi untuk memilih printer
  void _selectPrinter() {
    // Di sini Anda akan menampilkan dialog untuk memindai dan memilih printer Bluetooth
    // Setelah dipilih, set state:
    // setState(() {
    //   _selectedPrinter = device;
    // });
    // print("Logika pemilihan printer belum diimplementasi."); // <-- Dihapus (error 'avoid_print')
    // Untuk testing PDF, biarkan _selectedPrinter = null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buat Photostrip"),
        actions: [
          // (Asumsi) Tombol untuk memilih printer
          IconButton(
            icon: Icon(
              Icons.print_disabled,
              color: _selectedPrinter != null ? Colors.green : Colors.red,
            ),
            onPressed: _selectPrinter,
            tooltip: _selectedPrinter?.platformName ?? "Pilih Printer",
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            //
            // --- UI TOGGLE UNTUK PREVIEW B&W ---
            //
            SwitchListTile(
              title: const Text("Preview Hitam Putih (Monokrom)"),
              subtitle: const Text("Sesuaikan dengan printer hitam putih"),
              value: _isBwPreview,
              onChanged: (bool newValue) {
                setState(() {
                  _isBwPreview = newValue;
                });
              },
            ),

            const Divider(),

            //
            // --- PREVIEW PHOTOSTRIP ---
            //
            ColorFiltered(
              /// Terapkan filter HANYA JIKA _isBwPreview adalah true
              colorFilter: _isBwPreview
                  ? grayscaleFilter // Filter B&W
                  //
                  // --- PERBAIKAN (Fix 'undefined_enum_constant') ---
                  : const ColorFilter.mode(
                      Colors.transparent, BlendMode.srcOver), // Tanpa filter
              // --- Akhir Perbaikan ---
              //
              child: RepaintBoundary(
                key: _globalKey,
                child: Container(
                  color: Colors.white, // Latar belakang photostrip
                  padding: const EdgeInsets.all(8.0), // Padding photostrip
                  width: 320, // Lebar photostrip (sesuaikan)
                  child: Column(
                    // Membuat layout gambar secara vertikal
                    mainAxisSize: MainAxisSize.min,
                    children: widget.photos.map((photo) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: RawImage(
                          image: photo,
                          width: 304, // Lebar gambar (320 - 16 padding)
                          fit: BoxFit.contain,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100), // Spasi agar tidak tertutup FAB
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isPrinting ? null : _onPrintButtonPressed,
        icon: _isPrinting
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.print),
        label: Text(_isPrinting ? "Mencetak..." : "Cetak Sekarang"),
      ),
    );
  }
}