import 'dart:io'; // Tambahkan import dart:io
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterServices {
  
  static const String _kMacAddressKey = 'selected_printer_mac';

  Future<bool> get isBluetoothEnabled async => await PrintBluetoothThermal.bluetoothEnabled;
  Future<bool> get isConnected async => await PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // --- LOGIKA KONEKSI ---
  Future<bool> autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedMac = prefs.getString(_kMacAddressKey);
    if (savedMac == null) return false;
    if (await isConnected) return true;
    return await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
  }

  Future<bool> connectAndSave(String macAddress) async {
    final bool success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMacAddressKey, macAddress);
    }
    return success;
  }

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  Future<void> testPrint() async {
    if (!await isConnected) return;
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    bytes += generator.reset();
    bytes += generator.text('TEST PRINT SUKSES', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Printer Siap!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // --- BARU: PRINT DARI FILE (UNTUK GALERI) ---
  Future<bool> printImageFromFile(File file) async {
    if (!await isConnected) {
      bool reconnected = await autoConnect();
      if (!reconnected) return false;
    }

    try {
      // 1. Baca file gambar
      final Uint8List bytes = await file.readAsBytes();
      
      // 2. Decode gambar (bisa JPG atau PNG)
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) return false;

      // 3. Proses Gambar (Resize -> BW -> Dither)
      // Menggunakan lebar 576 untuk kertas 80mm
      img.Image resizedImage = img.copyResize(originalImage, width: 576);
      img.Image grayscaleImage = img.grayscale(resizedImage);
      
      // Adjust agar hasil cetak lebih jelas
      img.Image adjustedImage = img.adjustColor(
        grayscaleImage, 
        brightness: 1.2, 
        contrast: 1.5
      );

      // Dithering
      _applyFloydSteinbergDither(adjustedImage);

      // 4. Kirim ke Printer
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> printBytes = [];

      printBytes += generator.reset();
      printBytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      printBytes += generator.image(adjustedImage, align: PosAlign.center);
      printBytes += generator.feed(3);
      printBytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(printBytes);
    } catch (e) {
      print("Error Print File: $e");
      return false;
    }
  }

  // --- PRINT DARI WIDGET (UNTUK PHOTOSTRIP CREATOR) ---
  Future<bool> printPhotoStrip(ui.Image photoStripImage) async {
    if (!await isConnected) {
      bool reconnected = await autoConnect();
      if (!reconnected) return false;
    }

    try {
      final ByteData? byteData = await photoStripImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      img.Image? originalImage = img.decodePng(pngBytes);
      if (originalImage == null) return false;

      img.Image resizedImage = img.copyResize(originalImage, width: 576);
      img.Image grayscaleImage = img.grayscale(resizedImage);
      img.Image adjustedImage = img.adjustColor(grayscaleImage, brightness: 1.2, contrast: 1.5);
      _applyFloydSteinbergDither(adjustedImage);

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      bytes += generator.image(adjustedImage, align: PosAlign.center);
      bytes += generator.feed(3);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      print("Error Print Widget: $e");
      return false;
    }
  }

  // --- HELPER: Dithering ---
  void _applyFloydSteinbergDither(img.Image image) {
    final int width = image.width;
    final int height = image.height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        final double oldPixel = pixel.r.toDouble();
        final double newPixel = oldPixel < 128 ? 0 : 255;
        
        pixel.r = newPixel;
        pixel.g = newPixel;
        pixel.b = newPixel;

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
      double newValue = p.r + error;
      newValue = newValue.clamp(0, 255);
      p.r = newValue;
      p.g = newValue;
      p.b = newValue;
    }
  }
}