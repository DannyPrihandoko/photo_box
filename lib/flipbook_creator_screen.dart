import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:share_plus/share_plus.dart';

import 'package:photo_box/main.dart';
import 'package:photo_box/printing_services.dart';

class FlipbookCreatorScreen extends StatefulWidget {
  final List<File> frames;
  final String voucherCode;

  const FlipbookCreatorScreen({
    super.key,
    required this.frames,
    required this.voucherCode,
  });

  @override
  State<FlipbookCreatorScreen> createState() => _FlipbookCreatorScreenState();
}

class _FlipbookCreatorScreenState extends State<FlipbookCreatorScreen> {
  int _selectedFrameIndex = 0;
  bool _isProcessing = false;
  final PrinterServices _printingServices = PrinterServices();

  Future<void> _processFlipbookAndSticker({required bool shareNow}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Menyimpan Flipbook & Memproses Stiker...')));

      // 1. Simpan Layout PDF Flipbook (Untuk Cetak Epson) ke Storage Aplikasi
      await _printingServices.saveFlipbookPdf(
        widget.frames,
        _selectedFrameIndex,
        widget.voucherCode,
      );

      // 2. Buat Stiker WA (Format Animasi GIF 512x512) dari 24 Frame
      final String framePattern =
          '${widget.frames.first.parent.path}/frame_%03d.jpg';
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputDirPath = '${appDirectory.path}/Flipbooks';
      await Directory(outputDirPath).create(recursive: true);

      final String outputGifPath =
          '$outputDirPath/Stiker_${widget.voucherCode}_${DateTime.now().millisecondsSinceEpoch}.gif';

      // --- PERUBAHAN UTAMA: Perintah FFmpeg untuk menambahkan Border Polaroid & Teks ---
      // Penjelasan Filter (-vf):
      // - scale=400:400  -> Perkecil video animasi
      // - pad=420:420    -> Tambah bingkai putih (10px di semua sisi) seperti kertas foto polaroid
      // - pad=512:512    -> Tambah background Biru Langit (#87CEFA) dan dorong posisi gambar ke atas (menyisakan ruang di bawah)
      // - drawtext       -> Tulis "PHOTOBOX SENYUM!" warna kuning (#FFD700) dengan bayangan hitam.
      final String command =
          '-framerate 8 -i "$framePattern" -vf "scale=400:400:force_original_aspect_ratio=decrease,pad=420:420:(ow-iw)/2:(oh-ih)/2:color=white,pad=512:512:(ow-iw)/2:20:color=#87CEFA,drawtext=text=\'PHOTOBOX SENYUM!\':fontcolor=#FFD700:shadowcolor=black:shadowx=2:shadowy=2:fontsize=36:x=(w-text_w)/2:y=455" -y "$outputGifPath"';

      await FFmpegKit.execute(command);

      // 3. Simpan stiker GIF ke Galeri Publik HP
      await ImageGallerySaverPlus.saveFile(outputGifPath,
          name: "${widget.voucherCode}_stiker_wa");

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Berhasil Disimpan!'),
            backgroundColor: Colors.green));

      // 4. Bagikan ke WA (Jika tombol Bagikan ditekan)
      if (shareNow) {
        final xFile = XFile(outputGifPath);
        await Share.shareXFiles([xFile],
            text: "Stiker Animasi dari Photo Box Senyum! 📸");
      }

      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        Navigator.of(context)
            .popUntil((route) => route.isFirst); // Kembali ke Home
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: Text("Desain Flipbook - ${widget.voucherCode}",
            style: const TextStyle(color: textDark, fontSize: 16)),
        backgroundColor: primaryYellow,
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("PREVIEW FRAME",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2)),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: Container(
                  width: 250,
                  height: 330,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                        color: _selectedFrameIndex == 1
                            ? Colors.pink
                            : (_selectedFrameIndex == 2
                                ? Colors.black87
                                : Colors.grey),
                        width: _selectedFrameIndex == 0 ? 1 : 8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(widget.frames.first, fit: BoxFit.cover),
                      if (_selectedFrameIndex == 1)
                        Container(
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white, width: 4))),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text("PILIH TEMA FRAME",
                style: TextStyle(color: accentGrey, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFrameOption(0, "Polos", Colors.white),
                _buildFrameOption(1, "Cute", Colors.pink[100]!),
                _buildFrameOption(2, "Cool", Colors.grey[400]!),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("SIMPAN"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: _isProcessing
                          ? null
                          : () => _processFlipbookAndSticker(shareNow: false),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: textDark, strokeWidth: 2))
                          : const Icon(Icons.share),
                      label:
                          Text(_isProcessing ? "MEMPROSES..." : "BAGIKAN (WA)"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow,
                          foregroundColor: textDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: _isProcessing
                          ? null
                          : () => _processFlipbookAndSticker(shareNow: true),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrameOption(int index, String label, Color color) {
    bool isSelected = _selectedFrameIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFrameIndex = index),
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: color,
            border: isSelected
                ? Border.all(color: primaryYellow, width: 4)
                : Border.all(color: Colors.grey[800]!),
            borderRadius: BorderRadius.circular(12)),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black87))),
      ),
    );
  }
}
