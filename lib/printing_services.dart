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
  Future<bool> get isBluetoothEnabled async =>
      await PrintBluetoothThermal.bluetoothEnabled;

  // Cek apakah sudah terhubung ke printer
  Future<bool> get isConnected async =>
      await PrintBluetoothThermal.connectionStatus;

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
    final bool success =
        await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
    return success;
  }

  /// Connect manual dari halaman Settings & Simpan MAC Address
  Future<bool> connectAndSave(String macAddress) async {
    final bool success =
        await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMacAddressKey, macAddress);
    }

    return success;
  }

  /// Putus koneksi
  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    // Opsional: Hapus simpanan jika ingin user memilih ulang
    // final prefs = await SharedPreferences.getInstance();
    // await prefs.remove(_kMacAddressKey);
  }

  // --- TEST PRINT (Untuk Halaman Setting) ---
  Future<void> testPrint() async {
    if (!await isConnected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    bytes += generator.reset();
    bytes += generator.text('TEST PRINT SUKSES',
        styles: const PosStyles(
            align: PosAlign.center, bold: true, height: PosTextSize.size2));
    bytes += generator.text('Printer Panda PRJ-80BT Siap!',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    // bytes += generator.cut(); // Uncomment jika printer punya auto cutter

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  // --- FUNGSI UTAMA CETAK GAMBAR (Sama seperti sebelumnya) ---
  Future<bool> printPhotoStrip(ui.Image photoStripImage) async {
    // Logika sama seperti sebelumnya, tapi pastikan panggil autoConnect() di awal jika putus
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

      // Resize dan Grayscale
      img.Image resizedImage = img.copyResize(originalImage, width: 550);
      img.Image bwImage = img.grayscale(resizedImage);

      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.image(bwImage);
      bytes += generator.feed(3);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      print("Error Print: $e");
      return false;
    }
  }
}
