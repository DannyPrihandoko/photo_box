import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_box/main.dart';
import 'package:photo_box/printing_services.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<File> _files = [];
  bool _isLoading = true;
  final PrinterServices _printingServices = PrinterServices();

  @override
  void initState() {
    super.initState();
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final Directory appDir = await getApplicationDocumentsDirectory();
    List<File> foundFiles = [];

    try {
      final List<FileSystemEntity> entities = appDir.listSync(recursive: true);
      for (var entity in entities) {
        if (entity is File) {
          final ext = entity.path.toLowerCase();
          if (ext.endsWith('.png') ||
              ext.endsWith('.jpg') ||
              ext.endsWith('.pdf') ||
              ext.endsWith('.gif')) {
            if (!entity.path.contains('flipbook_frames_')) {
              foundFiles.add(entity);
            }
          }
        }
      }
      // Urutkan dari yang paling baru
      foundFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (e) {
      debugPrint("Error loading gallery: $e");
    }

    setState(() {
      _files = foundFiles;
      _isLoading = false;
    });
  }

  void _printFile(File file) async {
    try {
      final ext = file.path.toLowerCase();
      if (ext.endsWith('.gif')) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  "Stiker GIF ini hanya untuk dikirim ke WA, bukan dicetak."),
              backgroundColor: Colors.orange));
        return;
      }

      // Tampilkan notifikasi loading cetak
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Menyiapkan dokumen untuk printer...")));

      if (ext.endsWith('.pdf')) {
        await _printingServices.printPdfFile(file);
      } else {
        final bytes = await file.readAsBytes();
        await _printingServices.printBytesToEpson(bytes, isStrukMode: false);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error mencetak: $e"), backgroundColor: Colors.red));
    }
  }

  void _shareFile(File file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Hasil dari Photo Box Senyum! 📸');
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Gagal membagikan: $e"),
            backgroundColor: Colors.red));
    }
  }

  void _deleteFile(File file) async {
    // Dialog konfirmasi hapus
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text("Hapus File?"),
              content: const Text(
                  "File ini akan dihapus secara permanen dari perangkat."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    onPressed: () async {
                      Navigator.pop(context);
                      await file.delete();
                      _loadFiles();
                    },
                    child: const Text("Ya, Hapus",
                        style: TextStyle(color: Colors.white))),
              ],
            ));
  }

  // --- LOGIKA PEMBUATAN LIST BERDASARKAN TANGGAL ---
  List<Widget> _buildGalleryList() {
    List<Widget> listItems = [];
    String lastDateStr = "";

    for (var file in _files) {
      final dt = file.lastModifiedSync();
      // Format Tanggal: DD/MM/YYYY
      final dateStr =
          "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}";

      // Jika tanggal berbeda dari item sebelumnya, buat Header Tanggal baru
      if (dateStr != lastDateStr) {
        listItems.add(Padding(
          padding: const EdgeInsets.only(left: 15, top: 25, bottom: 10),
          child: Text("Sesi Tanggal: $dateStr",
              style: const TextStyle(
                  color: primaryYellow,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ));
        lastDateStr = dateStr;
      }

      // Tambahkan item file
      listItems.add(_buildFileListItem(file, dt));
    }

    return listItems;
  }

  // --- WIDGET UNTUK TIAP BARIS FILE ---
  Widget _buildFileListItem(File file, DateTime dt) {
    final isPdf = file.path.toLowerCase().endsWith('.pdf');
    final isGif = file.path.toLowerCase().endsWith('.gif');

    // Format Jam: HH:MM
    final timeStr =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB";

    String fileType = "Foto (PNG/JPG)";
    if (isPdf) fileType = "Buku Flipbook (PDF)";
    if (isGif) fileType = "Stiker Animasi (GIF)";

    return Card(
      color: Colors.white.withOpacity(0.08),
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        // --- 1. PREVIEW KECIL (Kiri) ---
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 55,
            height: 55,
            child: isPdf
                ? Container(
                    color: Colors.redAccent.withOpacity(0.2),
                    child: const Center(
                        child: Icon(Icons.picture_as_pdf,
                            color: Colors.redAccent, size: 30)),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(file, fit: BoxFit.cover),
                      if (isGif)
                        Container(
                          color: Colors.black45,
                          child: const Center(
                              child: Text("GIF",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold))),
                        )
                    ],
                  ),
          ),
        ),
        // --- 2. INFORMASI WAKTU & TIPE (Tengah) ---
        title: Text(timeStr,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(fileType,
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ),
        // --- 3. TOMBOL AKSI (Kanan) ---
        // Menggunakan Row dengan mainAxisSize: MainAxisSize.min untuk MENCEGAH OVERFLOW
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tombol Cetak
            IconButton(
              icon: Icon(isGif ? Icons.print_disabled : Icons.print,
                  color: isGif ? Colors.white30 : Colors.blueAccent),
              tooltip:
                  isGif ? 'Format GIF tidak bisa dicetak' : 'Cetak ke Epson',
              onPressed: () => _printFile(file),
            ),
            // Tombol Share (WA)
            IconButton(
              icon: const Icon(Icons.share, color: Colors.greenAccent),
              tooltip: 'Bagikan',
              onPressed: () => _shareFile(file),
            ),
            // Tombol Hapus
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Hapus',
              onPressed: () => _deleteFile(file),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: const Text("Galeri Tersimpan",
            style: TextStyle(color: textDark, fontSize: 18)),
        backgroundColor: primaryYellow,
        iconTheme: const IconThemeData(color: textDark),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Galeri',
              onPressed: _loadFiles),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryYellow))
          : _files.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined,
                          size: 80, color: Colors.white24),
                      SizedBox(height: 15),
                      Text("Belum ada sesi/foto yang tersimpan.",
                          style: TextStyle(color: accentGrey, fontSize: 16)),
                    ],
                  ),
                )
              // Menggunakan ListView.builder untuk mencegah Overflow layar
              : ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 30),
                  children: _buildGalleryList(),
                ),
    );
  }
}
