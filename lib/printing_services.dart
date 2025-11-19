import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterServices {
  
  // Key untuk penyimpanan lokal
  static const String _kMacAddressKey = 'selected_printer_mac';

  // Cek apakah Bluetooth HP nyala
  Future<bool> get isBluetoothEnabled async => await PrintBluetoothThermal.bluetoothEnabled;

  // Cek apakah sudah terhubung ke printer
  Future<bool> get isConnected async => await PrintBluetoothThermal.connectionStatus;

  // Ambil daftar perangkat
  Future<List<BluetoothInfo>> getPairedPrinters() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  // --- LOGIKA KONEKSI PINTAR ---

  /// Mencoba connect ke printer yang tersimpan di memori
  Future<bool> autoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedMac = prefs.getString(_kMacAddressKey);

    if (savedMac == null) return false; // Belum pernah setting printer

    // Cek status dulu, kalau sudah connect, return true
    if (await isConnected) return true;

    // Coba connect
    final bool success = await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
    return success;
  }

  /// Connect manual dari halaman Settings & Simpan MAC Address
  Future<bool> connectAndSave(String macAddress) async {
    final bool success = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMacAddressKey, macAddress);
    }
    
    return success;
  }

  /// Putus koneksi
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
  }

  // --- TEST PRINT (Untuk Halaman Setting) ---
  Future<void> testPrint() async {
    if (!await isConnected) return;
    
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text('TEST PRINT SUKSES',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Printer 80mm Siap!',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // --- FUNGSI UTAMA CETAK GAMBAR ---
  Future<bool> printPhotoStrip(ui.Image photoStripImage) async {
    // 1. Pastikan terkoneksi
    if (!await isConnected) {
      bool reconnected = await autoConnect();
      if (!reconnected) return false;
    }

    try {
      // 2. Konversi ui.Image ke PNG Bytes
      final ByteData? byteData = await photoStripImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return false;
      
      final Uint8List pngBytes = byteData.buffer.asUint8List();
      
      // 3. Decode menggunakan library 'image'
      img.Image? originalImage = img.decodePng(pngBytes);
      if (originalImage == null) return false;

      // 4. PROSES GAMBAR (Image Processing Pipeline)
      
      // A. Resize untuk Kertas 80mm
      // Lebar efektif 80mm thermal biasanya 576 dots.
      // Kita set 576 agar FULL WIDTH.
      img.Image resizedImage = img.copyResize(originalImage, width: 576);

      // B. Grayscale (Hitam Putih)
      img.Image grayscaleImage = img.grayscale(resizedImage);

      // C. Adjust Brightness & Contrast
      // brightness: 1.2 (lebih cerah), contrast: 1.5 (lebih tajam)
      img.Image adjustedImage = img.adjustColor(
        grayscaleImage, 
        brightness: 1.2, 
        contrast: 1.5
      );

      // D. Dithering (Floyd-Steinberg)
      _applyFloydSteinbergDither(adjustedImage);

      // 5. Kirim ke Printer
      final profile = await CapabilityProfile.load();
      
      // Pastikan Generator menggunakan PaperSize.mm80
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      
      // PERBAIKAN ALIGNMENT: Set Center sebelum gambar
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      
      // Kirim gambar dengan parameter align center (jika didukung library)
      // dan pastikan ukuran gambar sudah 576px agar otomatis memenuhi kertas
      bytes += generator.image(adjustedImage, align: PosAlign.center); 
      
      bytes += generator.feed(3);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      print("Error Print: $e");
      return false;
    }
  }

  // --- HELPER: Dithering Manual (Floyd-Steinberg) ---
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