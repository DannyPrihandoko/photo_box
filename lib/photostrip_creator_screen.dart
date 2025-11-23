import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

// Import file project Anda
import 'package:photo_box/main.dart'; 
import 'package:photo_box/printing_services.dart'; 
import 'package:photo_box/printer_settings_screen.dart'; 

// Enum Layout
enum PhotostripLayout { strip2, strip1 }

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
  // Default layout: 2 Strip
  PhotostripLayout _selectedLayout = PhotostripLayout.strip2;
  
  // List untuk menyimpan path gambar (Maksimal 2 slot)
  List<String?> _currentLayoutImages = List.filled(2, null);
  
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final PrinterServices _printingServices = PrinterServices();
  bool _isProcessing = false;

  // Matriks Filter Hitam Putih (High Contrast B&W)
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
      // Isi slot awal dengan 2 gambar pertama dari sesi
      for (int i = 0; i < 2 && i < widget.sessionImages.length; i++) {
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

  // --- HELPER: Tanggal Format Indonesia ---
  String _getIndonesianDate() {
    final now = DateTime.now();
    const List<String> months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    // Contoh Output: 22 November 2025
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  ///
  /// FUNGSI UTAMA: SAVE FILE & PRINT KE BLUETOOTH
  ///
  Future<void> _saveAndPrintPhotostrip() async {
    if (_isProcessing) return;
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

      final String fileName = 'strip_${DateTime.now().millisecondsSinceEpoch}.png';
      final String outputPath = '$outputDirPath/$fileName';
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
        if (mounted) {
          _showPrinterErrorDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Sukses mencetak!'), backgroundColor: Colors.green)
          );
          
          // --- LOGIKA BARU: PINDAH KE HALAMAN AWAL ---
          // Delay sejenak agar user bisa membaca pesan sukses
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
             // Pop sampai route pertama (Menu Awal / Welcome Screen)
             Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      }

    } catch (e) {
      debugPrint("Error saving/printing: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _showPrinterErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundDark,
        title: const Text("Printer Tidak Siap", style: TextStyle(color: textDark)),
        content: const Text(
          "Gagal terhubung ke printer. Pastikan printer nyala atau atur koneksi di menu Settings.",
          style: TextStyle(color: Colors.grey)
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
              Navigator.pop(context);
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

  // --- DIALOG KONFIRMASI KELUAR ---
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Selesai Sesi?"),
        content: const Text("Pastikan Anda sudah mencetak foto sebelum keluar.\n\nFoto yang belum tersimpan akan hilang."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
            onPressed: () {
              Navigator.pop(context);
              // KEMBALI KE WELCOME SCREEN (Route Pertama)
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("Ya, Ke Menu Awal", style: TextStyle(color: textDark)),
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
        title: const Text('Buat Photostrip Anda', style: TextStyle(fontSize: 18)),
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Tombol Home di AppBar
          IconButton(
            icon: const Icon(Icons.home_rounded, color: textDark, size: 30),
            onPressed: _showExitDialog, // Panggil fungsi dialog
          ),
        ],
      ),
      // OrientationBuilder untuk support Portrait/Landscape
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          
          return Flex(
            direction: isPortrait ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- AREA PREVIEW ---
              Expanded(
                flex: 2, 
                child: Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _buildPhotostripTemplate(),
                      ),
                    ),
                  ),
                ),
              ),
              
              if (isPortrait) 
                const Divider(height: 1, color: accentGrey)
              else 
                const VerticalDivider(width: 1, color: accentGrey),
              
              // --- AREA EDITOR (KANAN/BAWAH) ---
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        isPortrait ? "DRAG FOTO KE ATAS" : "DRAG FOTO KE KIRI",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textDark),
                      ),
                      const SizedBox(height: 10),
                      
                      // Galeri Foto
                      Expanded(child: _buildDraggableImageGrid()),
                      
                      const SizedBox(height: 15),
                      
                      // Pilihan Layout
                      const Text("PILIH LAYOUT", style: TextStyle(color: accentGrey, fontSize: 12)),
                      const SizedBox(height: 8),
                      _buildLayoutOptions(),
                      
                      const SizedBox(height: 20),
                      
                      // Tombol Print
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _isProcessing 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: textDark, strokeWidth: 2))
                              : const Icon(Icons.print),
                          label: Text(_isProcessing ? 'MEMPROSES...' : 'CETAK & SIMPAN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryYellow,
                            foregroundColor: textDark,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isProcessing ? null : _saveAndPrintPhotostrip,
                        ),
                      ),

                      const SizedBox(height: 15),

                      // --- TOMBOL KEMBALI KE WELCOME ---
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('KEMBALI KE MENU AWAL'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textDark,
                            side: const BorderSide(color: textDark, width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _showExitDialog, // Panggil fungsi dialog
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Widget Template Photostrip (Preview) ---
  Widget _buildPhotostripTemplate() {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Container(
          width: 200, 
          decoration: BoxDecoration(
              color: Colors.white, 
              boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10)]
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- HEADER BARU: SENYUM & TANGGAL ---
              const Text(
                'SENYUM', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)
              ),
              const SizedBox(height: 4),
              Text(
                _getIndonesianDate(), // Menggunakan helper tanggal Indo
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)
              ),
              const SizedBox(height: 12),
              // -------------------------------------
              
              if (_selectedLayout == PhotostripLayout.strip2)
                _build2StripSlots()
              else
                _build1StripSlot(),
              
              // Footer tanggal lama dihapus agar tidak duplikat
            ],
          ),
        ),
      ),
    );
  }

  Widget _build2StripSlots() {
    return Column(
      children: List.generate(2, (index) => _buildDragTargetWrapper(index, _currentLayoutImages[index], height: 140)),
    );
  }

  Widget _build1StripSlot() {
    return _buildDragTargetWrapper(0, _currentLayoutImages[0], height: 300);
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
             int oldIndex = _currentLayoutImages.indexOf(data);
             if (oldIndex != -1) _currentLayoutImages[oldIndex] = null;
             _currentLayoutImages[index] = data;
           } else if (data is DragData) {
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

  Widget _buildSlotContent(int index, String? imagePath, {bool isHighlighted = false, required double height}) {
    return Container(
      height: height,
      width: 200,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300], 
        border: Border.all(color: isHighlighted ? primaryYellow : Colors.transparent, width: 3),
      ),
      child: imagePath != null 
        ? Draggable<DragData>(
            data: DragData(imagePath: imagePath, fromIndex: index), 
            feedback: Material(
              color: Colors.transparent,
              child: Opacity(
                opacity: 0.7, 
                child: Image.file(File(imagePath), height: height, width: 200, fit: BoxFit.cover)
              ),
            ),
            childWhenDragging: Container(color: Colors.grey[200]),
            child: Image.file(File(imagePath), fit: BoxFit.cover),
          )
        : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 30)),
    );
  }

  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, 
        crossAxisSpacing: 8, 
        mainAxisSpacing: 8
      ),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final path = widget.sessionImages[index].path;
        return Draggable<String>(
          data: path, 
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(path), 
                width: 80, 
                height: 80, 
                fit: BoxFit.cover,
                cacheWidth: 150, 
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path), 
              fit: BoxFit.cover,
              cacheWidth: 150,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayoutOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLayoutButton(PhotostripLayout.strip2, Icons.view_agenda, "2 KOTAK"),
        const SizedBox(width: 20),
        _buildLayoutButton(PhotostripLayout.strip1, Icons.crop_portrait, "1 KOTAK"),
      ],
    );
  }

  Widget _buildLayoutButton(PhotostripLayout layout, IconData icon, String label) {
    bool isSelected = _selectedLayout == layout;
    return InkWell(
      onTap: () => _updateLayout(layout),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primaryYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryYellow : accentGrey),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? textDark : accentGrey, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isSelected ? textDark : accentGrey, fontWeight: FontWeight.bold, fontSize: 12))
          ],
        ),
      ),
    );
  }
}