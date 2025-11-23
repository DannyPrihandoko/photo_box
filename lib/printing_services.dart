import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterServices {
  
  static const String _kMacAddressKey = 'selected_printer_mac';

  // --- STATUS ---
  Future<bool> get isConnected async => await PrintBluetoothThermal.connectionStatus;

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // --- KONEKSI ---
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
    bytes += generator.text('TEST PRINT SUKSES', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.text('Printer Siap!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // --- PRINT IMAGE ---
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
      final ByteData? byteData = await photoStripImage.toByteData(format: ui.ImageByteFormat.png);
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

  // --- CORE LOGIC ---
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
        case 1: // 58mm
          generator = Generator(PaperSize.mm58, profile);
          targetWidth = 384;
          break;
        case 3: // 80mm Medium
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 384; 
          break;
        case 7: // 80mm Custom (350 dots) - MODE BARU
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 350; 
          break;
        case 4: // 80mm Low
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 288; 
          break;
        case 2: // 80mm High (Default)
        default:
          generator = Generator(PaperSize.mm80, profile);
          targetWidth = 576; 
          break;
      }

      // 1. Resize
      img.Image resizedImage = img.copyResize(originalImage, width: targetWidth);
      
      // 2. Grayscale
      img.Image grayscaleImage = img.grayscale(resizedImage);
      
      // 3. Adjust Color
      img.Image adjustedImage = img.adjustColor(
        grayscaleImage, 
        brightness: brightness, 
        contrast: contrast
      );

      // 4. APPLY FILTER
      if (imageFilter == 2) {
        // Mode Threshold (Cepat & Kontras Tinggi)
        _applyThreshold(adjustedImage);
      } else {
        // Mode Dither (Standard)
        _applyFloydSteinbergDither(adjustedImage);
      }

      // 5. KIRIM SEKALIGUS (Tanpa Chunking)
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

  // --- HELPER: Thresholding ---
  void _applyThreshold(img.Image image) {
    final int width = image.width;
    final int height = image.height;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        img.Pixel pixel = image.getPixel(x, y);
        final double lum = pixel.r.toDouble();
        final double newValue = lum < 128 ? 0 : 255;
        pixel.r = newValue;
        pixel.g = newValue;
        pixel.b = newValue;
      }
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