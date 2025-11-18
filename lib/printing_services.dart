import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PrintingService {
  // Saya asumsikan Anda memiliki logika untuk menemukan dan terhubung ke printer
  // ... (Kode Anda yang sudah ada, mis: _findPrinter, connectToPrinter, dll) ...

  ///
  /// FUNGSI BARU UNTUK KONVERSI HITAM PUTIH
  ///
  /// Mengubah gambar [img.Image] menjadi versi hitam putih (grayscale).
  ///
  /// @param image Gambar asli yang akan dikonversi.
  /// @return Gambar baru dalam format hitam putih.
  img.Image convertToBlackAndWhite(img.Image image) {
    // Menggunakan fungsi grayscale dari package image
    return img.grayscale(image);
  }

  ///
  /// FUNGSI CETAK ESC/POS (THERMAL) YANG DIMODIFIKASI
  ///
  /// Menambahkan parameter [convertToBw]
  ///
  Future<void> printPhotoStripEscPos(
    BluetoothDevice device,
    ui.Image photoStripImage, {
    bool convertToBw = false, // Parameter baru!
  }) async {
    try {
      // 1. (Asumsi) Hubungkan ke printer
      // await device.connect();
      // ... temukan service dan characteristic ...
      // BluetoothCharacteristic? txCharacteristic = ...;

      // 2. Ubah ui.Image menjadi ByteData
      final ByteData? byteData =
          await photoStripImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Gagal mendapatkan byte data dari gambar.");
      }
      final Uint8List bytes = byteData.buffer.asUint8List();

      // 3. Decode menjadi img.Image
      img.Image? originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        throw Exception("Gagal men-decode gambar.");
      }

      //
      // 4. --- TITIK INTEGRASI ---
      //    Jika convertToBw adalah true, panggil fungsi baru kita
      //
      img.Image imageToPrint;
      if (convertToBw) {
        imageToPrint = convertToBlackAndWhite(originalImage);
      } else {
        imageToPrint = originalImage;
      }
      // Mulai dari sini, gunakan 'imageToPrint'

      // 5. (Opsional) Resize gambar agar sesuai dengan printer thermal
      // Sesuaikan 'width' dengan printer Anda (misal: 384 untuk 58mm, 576 untuk 80mm)
      final img.Image resizedImage = img.copyResize(
        imageToPrint,
        width: 384, // Ganti ini sesuai lebar kertas printer Anda
      );

      // 6. Siapkan data untuk printer
      final profile = await CapabilityProfile.load();
      final generator =
          Generator(PaperSize.mm80, profile); // Sesuaikan PaperSize
      List<int> ticket = [];

      // Cetak gambar menggunakan 'resizedImage' (yang sudah di-B&W jika dipilih)
      ticket.addAll(generator.image(resizedImage));
      ticket.addAll(generator.feed(2)); // Beri sedikit spasi
      ticket.addAll(generator.cut());

      // 7. Kirim data ke printer
      // (Asumsi) Anda punya logika untuk mengirim 'ticket'
      // await txCharacteristic.write(ticket, withoutResponse: true);

      print("Proses cetak ESC/POS selesai.");

      // 8. (Asumsi) Putuskan koneksi
      // await device.disconnect();
    } catch (e) {
      print("Error saat mencetak via ESC/POS: $e");
    }
  }

  ///
  /// FUNGSI CETAK PDF (PRINTER STANDAR) YANG DIMODIFIKASI
  ///
  /// Menambahkan parameter [convertToBw]
  ///
  Future<void> printPhotoStripPdf(
    ui.Image photoStripImage, {
    bool convertToBw = false, // Parameter baru!
  }) async {
    try {
      // 1. Ubah ui.Image menjadi ByteData
      final ByteData? byteData =
          await photoStripImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception("Gagal mendapatkan byte data dari gambar.");
      }
      final Uint8List bytes = byteData.buffer.asUint8List();

      // 2. Decode menjadi img.Image (jika perlu konversi B&W)
      img.Image? imageToProcess;
      Uint8List finalBytes = bytes;

      if (convertToBw) {
        imageToProcess = img.decodeImage(bytes);
        if (imageToProcess != null) {
          final bwImage = convertToBlackAndWhite(imageToProcess);
          // Encode kembali ke PNG
          finalBytes = Uint8List.fromList(img.encodePng(bwImage));
        }
      }

      // 3. Buat PDF
      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(finalBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(pdfImage),
            );
          },
        ),
      );

      // 4. Cetak PDF menggunakan package 'printing'
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );

      print("Proses cetak PDF selesai.");
    } catch (e) {
      print("Error saat mencetak via PDF: $e");
    }
  }
}
