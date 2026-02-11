import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- IMPORT KHUSUS EPSON (PDF & PRINTING) ---
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PrinterServices {
  static const String _kMacAddressKey = 'selected_printer_mac';

  // ==========================================
  // BAGIAN 1: PRINTER THERMAL (BLUETOOTH)
  // ==========================================

  Future<bool> get isConnected async =>
      await PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedMac = prefs.getString(_kMacAddressKey);
    if (savedMac == null) return false;
    if (await isConnected) return true;
    return await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
  }

  Future<bool> connectAndSave(String macAddress) async {
    final bool success =
        await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMacAddressKey, macAddress);
    }
    return success;
  }

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  Future<void> testPrintThermal() async {
    if (!await isConnected) return;
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text('TEST PRINT THERMAL',
        styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(2);
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // --- LOGIKA PRINT GAMBAR THERMAL (HITAM PUTIH) ---
  Future<bool> printImageFromFile(File file) async {
    if (!await isConnected) {
      bool reconnected = await autoConnect();
      if (!reconnected) return false;
    }
    try {
      final Uint8List bytes = await file.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return false;
      return await _processAndPrintImage(originalImage);
    } catch (e) {
      print("Error Print File: $e");
      return false;
    }
  }

  Future<bool> printPhotoStrip(ui.Image photoStripImage) async {
    if (!await isConnected) {
      bool reconnected = await autoConnect();
      if (!reconnected) return false;
    }
    try {
      final ByteData? byteData =
          await photoStripImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      img.Image? originalImage = img.decodePng(pngBytes);
      if (originalImage == null) return false;
      return await _processAndPrintImage(originalImage);
    } catch (e) {
      print("Error Print Widget: $e");
      return false;
    }
  }

  Future<bool> _processAndPrintImage(img.Image originalImage) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final int printerMode = prefs.getInt('printer_mode_type') ?? 2;
      final int imageFilter = prefs.getInt('printer_image_filter') ?? 1;
      final double brightness = prefs.getDouble('printer_brightness') ?? 1.2;
      final double contrast = prefs.getDouble('printer_contrast') ?? 1.5;

      final profile = await CapabilityProfile.load();

      Generator generator;
      int targetWidth;

      switch (printerMode) {
        case 1:
          generator = Generator(PaperSize.mm58, profile);
          targetWidth = 384;
          break;
        case 3:
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 384;
          break;
        case 7:
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 350;
          break;
        case 4:
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 288;
          break;
        case 2:
        default:
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 576;
          break;
      }

      img.Image resizedImage =
          img.copyResize(originalImage, width: targetWidth);
      img.Image grayscaleImage = img.grayscale(resizedImage);
      img.Image adjustedImage = img.adjustColor(grayscaleImage,
          brightness: brightness, contrast: contrast);

      if (imageFilter == 2) {
        _applyThreshold(adjustedImage);
      } else {
        _applyFloydSteinbergDither(adjustedImage);
      }

      List<int> bytes = [];
      bytes += generator.reset();
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.image(adjustedImage, align: PosAlign.center);
      bytes += generator.feed(3);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      print("Error Processing/Printing Image: $e");
      return false;
    }
  }

  void _applyThreshold(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        final double lum = pixel.r.toDouble();
        pixel.r = pixel.g = pixel.b = (lum < 128 ? 0 : 255);
      }
    }
  }

  void _applyFloydSteinbergDither(img.Image image) {
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        final double oldPixel = pixel.r.toDouble();
        final double newPixel = oldPixel < 128 ? 0 : 255;
        pixel.r = pixel.g = pixel.b = newPixel;
        final double quantError = oldPixel - newPixel;
        _distributeError(image, x + 1, y, quantError * 7 / 16);
        _distributeError(image, x - 1, y + 1, quantError * 3 / 16);
        _distributeError(image, x, y + 1, quantError * 5 / 16);
        _distributeError(image, x + 1, y + 1, quantError * 1 / 16);
      }
    }
  }

  void _distributeError(img.Image image, int x, int y, double error) {
    if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
      img.Pixel p = image.getPixel(x, y);
      double newValue = (p.r + error).clamp(0, 255);
      p.r = p.g = p.b = newValue;
    }
  }

  // ==========================================
  // BAGIAN 2: PRINTER EPSON (USB / OTG)
  // ==========================================

  /// Entry point utama untuk mencetak ke Epson.
  /// [isStrukMode] = true (Tampilan Struk/Strip), false (Tampilan Foto Penuh)
  Future<void> printBytesToEpson(Uint8List imageBytes,
      {bool isStrukMode = false}) async {
    await _printPdfLayout(imageBytes, isStrukMode);
  }

  /// Logika pembuatan layout PDF
  Future<void> _printPdfLayout(Uint8List imageBytes, bool isStrukMode) async {
    final pdfImage = pw.MemoryImage(imageBytes);
    final doc = pw.Document();

    // Menggunakan kertas A4 sebagai base (bisa diganti A6/4R jika perlu)
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        // Jika mode struk, beri margin. Jika foto full, margin 0.
        margin: isStrukMode ? const pw.EdgeInsets.all(20) : pw.EdgeInsets.zero,
        build: (pw.Context context) {
          if (isStrukMode) {
            return _buildStrukLayout(pdfImage);
          } else {
            return _buildFullPhotoLayout(pdfImage);
          }
        },
      ),
    );

    // Membuka dialog print native Android
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: isStrukMode
          ? 'Epson_Struk_${DateTime.now().millisecondsSinceEpoch}'
          : 'Epson_Foto_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// Layout Foto Full (Fit to Page)
  pw.Widget _buildFullPhotoLayout(pw.MemoryImage image) {
    return pw.Center(
      child: pw.Image(
        image,
        fit: pw.BoxFit.contain,
      ),
    );
  }

  /// Layout Struk (Header Text + Foto Kecil)
  pw.Widget _buildStrukLayout(pw.MemoryImage image) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text("PHOTO BOX",
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text("Date: ${DateTime.now().toString().substring(0, 16)}"),
        pw.Divider(),
        pw.SizedBox(height: 10),

        // Batasi ukuran gambar agar terlihat seperti di kertas struk
        pw.Container(
          width: 300,
          // height: 400, // Optional, biarkan auto height
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.black, width: 1),
          ),
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),

        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.Text("Terima Kasih!",
            style: pw.TextStyle(fontSize: 16, fontStyle: pw.FontStyle.italic)),
      ],
    );
  }
}
