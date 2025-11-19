import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

// Import file project Anda (sesuaikan path jika berbeda folder)
import 'package:photo_box/main.dart'; 
import 'package:photo_box/printing_services.dart'; // Pastikan file ini ada (dari langkah sebelumnya) 
import 'package:photo_box/printer_settings_screen.dart'; // Pastikan file ini ada (dari langkah sebelumnya)

// Enum Layout
enum PhotostripLayout { strip3, strip1 }

// Class data untuk Drag & Drop
class DragData {
  final String imagePath;
  final int fromIndex;
  DragData({required this.imagePath, required this.fromIndex});
}

class PhotostripCreatorScreen extends StatefulWidget {
  final List<XFile> sessionImages;
  final String sessionId;

  const PhotostripCreatorScreen({
    super.key,
    required this.sessionImages,
    required this.sessionId,
  });

  @override
  State<PhotostripCreatorScreen> createState() => _PhotostripCreatorScreenState();
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  // Default layout: 3 Strip
  PhotostripLayout _selectedLayout = PhotostripLayout.strip3;
  
  // List untuk menyimpan path gambar (Maksimal 3 slot)
  List<String?> _currentLayoutImages = List.filled(3, null);
  
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final PrinterServices _printingServices = PrinterServices(); // Service Bluetooth Baru
  bool _isProcessing = false;

  // Matriks Filter Hitam Putih
  static const List<double> _greyscaleMatrix = [
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ];

  @override
  void initState() {
    super.initState();
    _initializeImages();
  }

  void _initializeImages() {
    setState(() {
      // Isi slot awal dengan gambar dari sesi (maksimal 3)
      for (int i = 0; i < 3 && i < widget.sessionImages.length; i++) {
        _currentLayoutImages[i] = widget.sessionImages[i].path;
      }
    });
  }

  void _updateLayout(PhotostripLayout layout) {
    setState(() {
      _selectedLayout = layout;
      // Pastikan gambar pertama tetap ada saat pindah ke layout 1 Strip
      if (layout == PhotostripLayout.strip1 && _currentLayoutImages[0] == null) {
         if (widget.sessionImages.isNotEmpty) {
           _currentLayoutImages[0] = widget.sessionImages[0].path;
         }
      }
    });
  }

  ///
  /// FUNGSI UTAMA: SAVE FILE & PRINT KE BLUETOOTH
  ///
  Future<void> _saveAndPrintPhotostrip() async {
    setState(() { _isProcessing = true; });

    try {
      // 1. RENDER GAMBAR DARI LAYAR
      if (_repaintBoundaryKey.currentContext == null) throw Exception("Context null");
      
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      // Delay kecil untuk memastikan render pipeline stabil
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Tangkap gambar dengan resolusi cukup tinggi (pixelRatio 3.0)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      
      // 2. SIMPAN FILE KE LOCAL STORAGE (ARSIP)
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Byte data null");

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputDirPath = '${appDirectory.path}/${widget.sessionId}/photostrips';
      await Directory(outputDirPath).create(recursive: true);

      final String outputPath = '$outputDirPath/photostrip_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(outputPath).writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menyiapkan printer...'))
        );
      }

      // 3. PROSES PRINTING (BLUETOOTH)
      // Fungsi ini otomatis mencoba connect ke printer terakhir yang disimpan
      bool success = await _printingServices.printPhotoStrip(image);

      if (!success) {
        // JIKA GAGAL: Tampilkan Dialog Error & Opsi ke Settings
        if (mounted) {
          _showPrinterErrorDialog();
        }
      } else {
        // JIKA SUKSES
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Sukses mencetak!'), backgroundColor: Colors.green)
          );
          
          // Delay agar user baca notifikasi, lalu kembali ke home
          await Future.delayed(const Duration(seconds: 2));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  /// Dialog jika printer tidak terhubung
  void _showPrinterErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User harus milih
      builder: (context) => AlertDialog(
        backgroundColor: backgroundDark,
        title: const Text("Printer Tidak Siap", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Gagal terhubung ke printer. Pastikan printer nyala atau atur koneksi di menu Settings.",
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
            child: const Text("Buka Settings", style: TextStyle(color: textDark)),
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              // Buka halaman Settings
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => const PrinterSettingsScreen())
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: const Text('Buat Photostrip Anda'),
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Tombol Home (Kembali ke Awal)
          IconButton(
            icon: const Icon(Icons.home_rounded, color: textDark, size: 30),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Selesai Sesi?"),
                  content: const Text("Semua foto yang belum disimpan akan hilang. Yakin ingin kembali?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: const Text("Ya, Keluar", style: TextStyle(color: textDark)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- AREA PREVIEW (KIRI) ---
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildPhotostripTemplate(),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: accentGrey),
          
          // --- AREA EDITOR (KANAN) ---
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("DRAG FOTO KE KIRI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textDark)),
                  const SizedBox(height: 15),
                  // Galeri Foto
                  Expanded(child: _buildDraggableImageGrid()),
                  const SizedBox(height: 15),
                  // Pilihan Layout
                  const Text("PILIH LAYOUT", style: TextStyle(color: accentGrey, fontSize: 12)),
                  const SizedBox(height: 10),
                  _buildLayoutOptions(),
                  const SizedBox(height: 25),
                  // Tombol Save & Print
                  ElevatedButton.icon(
                    icon: _isProcessing 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: textDark, strokeWidth: 2))
                        : const Icon(Icons.print, size: 24),
                    label: Text(_isProcessing ? 'MEMPROSES...' : 'SAVE & PRINT'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                      backgroundColor: primaryYellow,
                      foregroundColor: textDark,
                    ),
                    onPressed: _isProcessing ? null : _saveAndPrintPhotostrip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Widget Template Photostrip ---
  Widget _buildPhotostripTemplate() {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      // Filter Warna: Mengubah seluruh tampilan anak menjadi Hitam Putih
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Container(
          width: 200, // Lebar tetap untuk konsistensi kertas 80mm
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10)]),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text('PHOTOBOX', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
              const SizedBox(height: 12),
              
              // Slot Foto
              if (_selectedLayout == PhotostripLayout.strip3)
                _build3StripSlots()
              else
                _build1StripSlot(),
              
              const SizedBox(height: 12),
              // Footer
               Text(DateTime.now().toString().substring(0, 10), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3StripSlots() {
    return Column(
      children: List.generate(3, (index) => _buildDragTargetWrapper(index, _currentLayoutImages[index], height: 120)),
    );
  }

  Widget _build1StripSlot() {
    // Hanya menggunakan gambar di slot pertama (index 0)
    return _buildDragTargetWrapper(0, _currentLayoutImages[0], height: 380);
  }

  Widget _buildDragTargetWrapper(int index, String? imagePath, {required double height}) {
    return DragTarget<Object>(
      builder: (context, candidate, rejected) {
        return _buildSlotContent(index, imagePath, isHighlighted: candidate.isNotEmpty, height: height);
      },
      onAcceptWithDetails: (details) {
        setState(() {
           final data = details.data;
           
           if (data is String) {
             // Case 1: Drop gambar baru dari Galeri (String path)
             int old = _currentLayoutImages.indexOf(data);
             if (old != -1) _currentLayoutImages[old] = null; // Hapus duplikat jika ada
             _currentLayoutImages[index] = data;
             
           } else if (data is DragData) {
             // Case 2: Swap gambar antar slot (DragData object)
             if (data.fromIndex != index) {
               final temp = _currentLayoutImages[index];
               _currentLayoutImages[index] = data.imagePath;
               _currentLayoutImages[data.fromIndex] = temp;
             }
           }
        });
      },
    );
  }

  // Helper untuk membuat kotak slot foto
  Widget _buildSlotContent(int index, String? imagePath, {bool isHighlighted = false, required double height}) {
    return Container(
      height: height,
      width: 200,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: backgroundDark,
        border: Border.all(color: isHighlighted ? primaryYellow : Colors.transparent, width: 3),
      ),
      child: imagePath != null 
        ? Draggable<DragData>(
            // MENGIRIM DragData AGAR TAHU ASALNYA DARI INDEX MANA
            data: DragData(imagePath: imagePath, fromIndex: index), 
            feedback: Opacity(opacity: 0.5, child: Image.file(File(imagePath), height: height, width: 200, fit: BoxFit.cover)),
            childWhenDragging: Container(color: Colors.grey),
            child: Image.file(File(imagePath), fit: BoxFit.cover),
          )
        : const Center(child: Icon(Icons.add_a_photo, color: accentGrey, size: 30)),
    );
  }

  // Helper untuk Grid Galeri di Kanan
  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final path = widget.sessionImages[index].path;
        return Draggable<String>(
          data: path, // Data yang dikirim hanya String path
          feedback: Opacity(opacity: 0.8, child: Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover)),
          child: Image.file(File(path), fit: BoxFit.cover),
        );
      },
    );
  }

  Widget _buildLayoutOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLayoutButton(PhotostripLayout.strip3, Icons.view_stream, "3 STRIP"),
        const SizedBox(width: 20),
        _buildLayoutButton(PhotostripLayout.strip1, Icons.crop_portrait, "1 STRIP"),
      ],
    );
  }

  Widget _buildLayoutButton(PhotostripLayout layout, IconData icon, String label) {
    bool isSelected = _selectedLayout == layout;
    return InkWell(
      onTap: () => _updateLayout(layout),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryYellow : accentGrey),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? textDark : accentGrey, size: 30),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: isSelected ? textDark : accentGrey, fontWeight: FontWeight.bold, fontSize: 12))
          ],
        ),
      ),
    );
  }
}