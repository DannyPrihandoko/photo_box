import 'dart:io';
import 'package:image/image.dart' as img;

class ImageProcessing {
  // Fungsi untuk memproses gambar agar optimal untuk printer thermal
  static Future<File> prepareImageForThermalPrinter(File inputFile) async {
    // 1. Baca gambar dari File
    final bytes = await inputFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw Exception("Gagal membaca gambar.");
    }

    // 2. Resize gambar agar pas dengan lebar printer (biasanya 384px untuk 58mm)
    // Resize ini penting agar proses selanjutnya lebih ringan dan hasil cetak pas.
    img.Image resizedImage = img.copyResize(originalImage, width: 384);

    // 3. Ubah ke Grayscale (Hitam Putih)
    img.Image grayscaleImage = img.grayscale(resizedImage);

    // 4. Atur Kecerahan & Kontras (Menggunakan adjustColor di v4)
    // brightness: 1.0 = normal, >1.0 = lebih cerah. Kita pakai 1.5 agar tidak terlalu gelap.
    // contrast: 1.0 = normal, >1.0 = lebih kontras. Kita pakai 1.5 agar garis lebih tegas.
    img.Image adjustedImage = img.adjustColor(
      grayscaleImage,
      brightness: 1.2, // Naikkan kecerahan (solusi untuk hasil gelap)
      contrast: 1.5, // Naikkan kontras
    );

    // 5. Terapkan Dithering Manual (Floyd-Steinberg)
    // Ini menggantikan ditherBayer yang hilang. Dithering membuat gradasi foto
    // terlihat seperti titik-titik, sangat cocok untuk printer thermal 1-bit.
    _applyFloydSteinbergDither(adjustedImage);

    // 6. Simpan gambar hasil proses ke file sementara
    final String tempPath =
        '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_thermal_print.png';
    final File tempFile = File(tempPath);

    // Encode ke PNG agar kualitas tetap terjaga saat dikirim ke printer
    await tempFile.writeAsBytes(img.encodePng(adjustedImage));

    return tempFile;
  }

  /// Fungsi helper untuk menerapkan Floyd-Steinberg Dithering secara manual
  /// Mengubah gambar menjadi murni hitam-putih (1-bit) dengan sebaran titik.
  static void _applyFloydSteinbergDither(img.Image image) {
    final int width = image.width;
    final int height = image.height;

    // Loop setiap pixel
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        // Ambil pixel saat ini
        img.Pixel pixel = image.getPixel(x, y);

        // Karena sudah grayscale, channel r, g, b nilainya sama. Ambil luminance (r).
        final double oldPixel = pixel.r.toDouble();

        // Tentukan threshold: jika > 128 jadi putih (255), jika <= 128 jadi hitam (0)
        final double newPixel = oldPixel < 128 ? 0 : 255;

        // Set pixel ke hitam atau putih murni
        pixel.r = newPixel;
        pixel.g = newPixel;
        pixel.b = newPixel;

        // Hitung error (selisih warna asli dengan warna baru)
        final double quantError = oldPixel - newPixel;

        // Sebarkan error ke pixel tetangga (Floyd-Steinberg matrix)
        _distributeError(image, x + 1, y, quantError * 7 / 16);
        _distributeError(image, x - 1, y + 1, quantError * 3 / 16);
        _distributeError(image, x, y + 1, quantError * 5 / 16);
        _distributeError(image, x + 1, y + 1, quantError * 1 / 16);
      }
    }
  }

  static void _distributeError(img.Image image, int x, int y, double error) {
    if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
      img.Pixel p = image.getPixel(x, y);
      // Tambahkan error ke pixel tetangga dan clamp nilai agar tetap 0-255
      double newValue = p.r + error;
      newValue = newValue.clamp(0, 255); // Pastikan tidak overflow

      p.r = newValue;
      p.g = newValue;
      p.b = newValue;
    }
  }
}
