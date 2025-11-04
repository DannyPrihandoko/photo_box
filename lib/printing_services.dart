import 'dart:io';
// import 'dart:typed_data'; // Tidak perlu, sudah ada di 'services.dart'
import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

class PrintingService {
  bool _connected = false;
  String _macAddress = '';

  Future<void> connectToPrinter(String printerName) async {
    if (_connected) return;

    List<BluetoothInfo> devices = [];
    try {
      devices = await PrintBluetoothThermal.pairedBluetooths;
    } on PlatformException {
      print("Error getting bonded devices.");
      throw Exception(
          "Gagal mendapatkan perangkat Bluetooth. Pastikan Bluetooth aktif.");
    }

    BluetoothInfo? targetDevice;
    try {
      targetDevice = devices.firstWhere((d) => d.name == printerName);

      // --- PERBAIKAN 1: 'macAddress' diubah menjadi 'macAdress' (typo dari package-nya) ---
      _macAddress = targetDevice.macAdress;
    } catch (e) {
      print("Printer $printerName not found.");
      throw Exception(
          "Printer '$printerName' tidak ditemukan. Pastikan printer sudah di-pairing.");
    }

    try {
      // --- PERBAIKAN 2: 'macPrinter' diubah menjadi 'macPrinterAddress' ---
      final result =
          await PrintBluetoothThermal.connect(macPrinterAddress: _macAddress);
      _connected = result;
      if (!_connected) {
        throw Exception("Koneksi gagal terhubung.");
      }
    } catch (e) {
      print("Failed to connect to printer: $e");
      _connected = false;
      throw Exception("Gagal terhubung ke printer.");
    }
  }

  Future<void> printImage(String path) async {
    if (!_connected || _macAddress.isEmpty) {
      throw Exception("Printer tidak terhubung.");
    }

    try {
      final File imageFile = File(path);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception("Gagal memproses gambar.");
      }

      final generator =
          Generator(PaperSize.mm80, await CapabilityProfile.load());
      List<int> ticket = [];
      ticket += generator.image(decodedImage);
      ticket += generator.feed(2);

      await PrintBluetoothThermal.writeBytes(ticket);
    } catch (e) {
      print("Error printing image: $e");
      throw Exception("Gagal mencetak gambar.");
    }
  }

  Future<void> disconnect() async {
    if (_connected) {
      // --- PERBAIKAN 3: 'disconnect()' diubah menjadi 'disconnect' (karena ini getter) ---
      await PrintBluetoothThermal.disconnect;
      _connected = false;
      _macAddress = '';
    }
  }
}
