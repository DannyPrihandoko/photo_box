// lib/printing_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;

class PrintingService {
  final String targetDeviceName = "PRJ-80BT";
  final BuildContext context;
  bool _isPrinting = false;

  PrintingService(this.context);

  void _showStatus(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  Future<void> printImage(File imageFile) async {
    if (_isPrinting) {
      _showStatus("Pencetakan sedang berlangsung...", isError: true);
      return;
    }
    _isPrinting = true;
    _showStatus("Mencari printer $targetDeviceName...");

    try {
      // 1. Mulai Scan Bluetooth
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

      BluetoothDevice? targetDevice;
      
      // Dengarkan hasil scan
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.platformName == targetDeviceName) {
            targetDevice = r.device;
            FlutterBluePlus.stopScan();
            break;
          }
        }
      });
      
      await Future.delayed(const Duration(seconds: 5)); // Tunggu scan selesai

      if (targetDevice == null) {
        _showStatus("Printer $targetDeviceName tidak ditemukan.", isError: true);
        _isPrinting = false;
        return;
      }

      // 2. Hubungkan ke Printer
      _showStatus("Menghubungkan ke ${targetDevice!.platformName}...");
      await targetDevice!.connect(autoConnect: false);

      // 3. Temukan Layanan (Service) dan Karakteristik (Characteristic)
      List<BluetoothService> services = await targetDevice!.discoverServices();
      BluetoothCharacteristic? writeCharacteristic;

      // Printer thermal biasanya menggunakan Serial Port Profile (SPP)
      // Service UUID yang umum adalah '00001101-0000-1000-8000-00805f9b34fb'
      // Kita perlu menemukan karakteristik yang bisa 'write'
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            writeCharacteristic = char;
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic == null) {
        _showStatus("Tidak dapat menemukan karakteristik untuk mencetak.", isError: true);
        await targetDevice!.disconnect();
        _isPrinting = false;
        return;
      }

      // 4. Siapkan Gambar dan Perintah ESC/POS
      _showStatus("Mempersiapkan gambar...");
      final generator = Generator(PaperSize.mm80, await CapabilityProfile.load());
      List<int> bytes = [];

      final img.Image? image = img.decodeImage(await imageFile.readAsBytes());
      if (image == null) throw Exception("Gagal memuat gambar");
      
      // Resize gambar agar pas di 80mm (lebar 576 dots)
      final img.Image resizedImage = img.copyResize(image, width: 576);

      // Ubah gambar menjadi perintah ESC/POS
      bytes += generator.image(resizedImage);
      bytes += generator.feed(2); // Beri 2 baris spasi
      bytes += generator.cut();   // Potong kertas

      // 5. Kirim Perintah ke Printer
      _showStatus("Mengirim data ke printer...");
      // Kirim data dalam potongan kecil (MTU size)
      int mtu = await targetDevice!.mtu.first;
      int chunkSize = mtu - 3; // Kurangi 3 byte untuk overhead
      
      for (var i = 0; i < bytes.length; i += chunkSize) {
        await writeCharacteristic.write(
          bytes.sublist(i, i + chunkSize > bytes.length ? bytes.length : i + chunkSize),
          withoutResponse: true // Lebih cepat untuk printer
        );
      }

      _showStatus("Berhasil mencetak!");

    } catch (e) {
      _showStatus("Error: ${e.toString()}", isError: true);
    } finally {
      // 6. Putuskan Koneksi
      await targetDevice?.disconnect();
      _isPrinting = false;
    }
  }
}