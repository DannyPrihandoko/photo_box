import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';

class PrintingService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? _device;
  bool _connected = false;

  Future<void> connectToPrinter(String printerName) async {
    // Jika sudah terhubung, tidak perlu konek ulang
    if (_connected && _device != null) return;

    List<BluetoothDevice> devices = [];
    try {
      devices = await bluetooth.getBondedDevices();
    } on PlatformException {
      print("Error getting bonded devices.");
      throw Exception("Gagal mendapatkan perangkat Bluetooth. Pastikan Bluetooth aktif.");
    }

    try {
      // Cari printer berdasarkan nama yang diberikan
      _device = devices.firstWhere((d) => d.name == printerName);
    } catch (e) {
      print("Printer $printerName not found.");
      throw Exception("Printer '$printerName' tidak ditemukan. Pastikan printer sudah di-pairing.");
    }

    if (_device != null) {
      try {
        await bluetooth.connect(_device!);
        _connected = true;
      } catch (e) {
        print("Failed to connect to printer: $e");
        _connected = false;
        throw Exception("Gagal terhubung ke printer.");
      }
    }
  }

  Future<void> printImage(String path) async {
    if (!_connected || _device == null) {
      throw Exception("Printer tidak terhubung.");
    }

    try {
      // Menggunakan printImage untuk mencetak file dari path
      await bluetooth.printImage(path);
      // Anda bisa menambahkan printNewLine() jika perlu spasi setelah gambar
      await bluetooth.printNewLine();
      await bluetooth.printNewLine();
    } catch (e) {
      print("Error printing image: $e");
      throw Exception("Gagal mencetak gambar.");
    }
  }

  Future<void> disconnect() async {
    if (_connected) {
      await bluetooth.disconnect();
      _connected = false;
    }
  }
}