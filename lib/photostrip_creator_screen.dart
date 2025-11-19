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
  State<PhotostripCreatorScreen> createState() =>
      _PhotostripCreatorScreenState();
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  // Default layout: 3 Strip
  PhotostripLayout _selectedLayout = PhotostripLayout.strip3;

  // List untuk menyimpan path gambar (Maksimal 3 slot)
  List<String?> _currentLayoutImages = List.filled(3, null);

  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final PrinterServices _printingServices = PrinterServices();
  bool _isProcessing = false;

  // Matriks Filter Hitam Putih (High Contrast B&W)
  static const List<double> _greyscaleMatrix = [
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  @override
  void initState() {
    super.initState();
    _initializeImages();
  }

  void _initializeImages() {
    setState(() {
      // Isi slot awal dengan 3 gambar pertama dari sesi
      for (int i = 0; i < 3 && i < widget.sessionImages.length; i++) {
        _currentLayoutImages[i] = widget.sessionImages[i].path;
      }
    });
  }

  void _updateLayout(PhotostripLayout layout) {
    setState(() {
      _selectedLayout = layout;
      // Pastikan gambar pertama tetap ada saat pindah ke layout 1 Strip
      if (layout == PhotostripLayout.strip1 &&
          _currentLayoutImages[0] == null) {
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
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. RENDER GAMBAR DARI LAYAR
      if (_repaintBoundaryKey.currentContext == null)
        throw Exception("Context null");

      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Delay kecil untuk memastikan render pipeline stabil
      await Future.delayed(const Duration(milliseconds: 100));

      // Tangkap gambar dengan resolusi cukup tinggi (pixelRatio 3.0)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // 2. SIMPAN FILE KE LOCAL STORAGE (ARSIP)
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Byte data null");

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputDirPath =
          '${appDirectory.path}/${widget.sessionId}/photostrips';
      await Directory(outputDirPath).create(recursive: true);

      final String fileName =
          'strip_${DateTime.now().millisecondsSinceEpoch}.png';
      final String outputPath = '$outputDirPath/$fileName';
      await File(outputPath).writeAsBytes(byteData.buffer.asUint8List());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Menyiapkan printer...')));
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Sukses mencetak!'),
              backgroundColor: Colors.green));

          await Future.delayed(const Duration(seconds: 2));
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint("Error saving/printing: $e");
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted)
        setState(() {
          _isProcessing = false;
        });
    }
  }

  void _showPrinterErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: backgroundDark,
        title:
            const Text("Printer Tidak Siap", style: TextStyle(color: textDark)),
        content: const Text(
            "Gagal terhubung ke printer. Pastikan printer nyala atau atur koneksi di menu Settings.",
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            child: const Text("Batal"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryYellow),
            child:
                const Text("Buka Settings", style: TextStyle(color: textDark)),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const PrinterSettingsScreen()));
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
        title:
            const Text('Buat Photostrip Anda', style: TextStyle(fontSize: 18)),
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_rounded, color: textDark, size: 30),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Selesai Sesi?"),
                  content:
                      const Text("Semua foto yang belum disimpan akan hilang."),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Batal")),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: primaryYellow),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: const Text("Ya, Keluar",
                          style: TextStyle(color: textDark)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      // --- PERBAIKAN: OrientationBuilder untuk support Portrait/Landscape ---
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;

          // Layout Wrapper: Column untuk Portrait, Row untuk Landscape
          return Flex(
            direction: isPortrait ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- AREA PREVIEW ---
              Expanded(
                flex: 2, // Preview lebih kecil proporsinya
                child: Container(
                  color: Colors.grey[200], // Sedikit background untuk kontras
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

              // Garis pemisah
              if (isPortrait)
                const Divider(height: 1, color: accentGrey)
              else
                const VerticalDivider(width: 1, color: accentGrey),

              // --- AREA EDITOR (GALERI & TOMBOL) ---
              Expanded(
                flex: 3, // Area kontrol lebih besar
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        isPortrait ? "DRAG FOTO KE ATAS" : "DRAG FOTO KE KIRI",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textDark),
                      ),
                      const SizedBox(height: 10),

                      // Galeri Foto
                      Expanded(child: _buildDraggableImageGrid()),

                      const SizedBox(height: 15),

                      // Pilihan Layout
                      const Text("PILIH LAYOUT",
                          style: TextStyle(color: accentGrey, fontSize: 12)),
                      const SizedBox(height: 8),
                      _buildLayoutOptions(),

                      const SizedBox(height: 20),

                      // Tombol Print
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: textDark, strokeWidth: 2))
                              : const Icon(Icons.print),
                          label: Text(_isProcessing
                              ? 'MEMPROSES...'
                              : 'CETAK & SIMPAN'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryYellow,
                            foregroundColor: textDark,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed:
                              _isProcessing ? null : _saveAndPrintPhotostrip,
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
      // Filter Hitam Putih untuk Preview & Print
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Container(
          width: 200, // Ukuran Logis untuk lebar kertas thermal
          decoration: BoxDecoration(
              color: Colors.white, // Background Putih Wajib untuk Thermal
              boxShadow: [
                BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 10)
              ]),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              const Text('PHOTOBOX',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.black)),
              const Text('SENYUM',
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 2, color: Colors.black)),
              const SizedBox(height: 12),

              // Slot Foto berdasarkan Layout
              if (_selectedLayout == PhotostripLayout.strip3)
                _build3StripSlots()
              else
                _build1StripSlot(),

              const SizedBox(height: 12),
              // Footer
              Text(DateTime.now().toString().substring(0, 16),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build3StripSlots() {
    return Column(
      children: List.generate(
          3,
          (index) => _buildDragTargetWrapper(index, _currentLayoutImages[index],
              height: 120)),
    );
  }

  Widget _build1StripSlot() {
    // Hanya slot 0 yang dipakai
    return _buildDragTargetWrapper(0, _currentLayoutImages[0], height: 360);
  }

  Widget _buildDragTargetWrapper(int index, String? imagePath,
      {required double height}) {
    return DragTarget<Object>(
      builder: (context, candidate, rejected) {
        return _buildSlotContent(index, imagePath,
            isHighlighted: candidate.isNotEmpty, height: height);
      },
      onAcceptWithDetails: (details) {
        setState(() {
          final data = details.data;

          if (data is String) {
            // Drop gambar baru dari Galeri
            // Hapus jika gambar ini sudah ada di slot lain
            int oldIndex = _currentLayoutImages.indexOf(data);
            if (oldIndex != -1) _currentLayoutImages[oldIndex] = null;

            _currentLayoutImages[index] = data;
          } else if (data is DragData) {
            // Swap gambar antar slot
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

  // Tampilan Slot Foto
  Widget _buildSlotContent(int index, String? imagePath,
      {bool isHighlighted = false, required double height}) {
    return Container(
      height: height,
      width: 200,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[300], // Placeholder color
        border: Border.all(
            color: isHighlighted ? primaryYellow : Colors.transparent,
            width: 3),
      ),
      child: imagePath != null
          ? Draggable<DragData>(
              data: DragData(imagePath: imagePath, fromIndex: index),
              // --- PERBAIKAN: Tambahkan Material agar feedback dragging terlihat benar ---
              feedback: Material(
                color: Colors.transparent,
                child: Opacity(
                    opacity: 0.7,
                    child: Image.file(File(imagePath),
                        height: height, width: 200, fit: BoxFit.cover)),
              ),
              childWhenDragging: Container(color: Colors.grey[200]),
              child: Image.file(File(imagePath), fit: BoxFit.cover),
            )
          : const Center(
              child: Icon(Icons.add_a_photo, color: Colors.grey, size: 30)),
    );
  }

  // Grid Foto Galeri (Source)
  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final path = widget.sessionImages[index].path;
        return Draggable<String>(
          data: path,
          // --- PERBAIKAN: Material wrapper untuk feedback ---
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
                // Optimasi Cache untuk performa drag
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
        _buildLayoutButton(
            PhotostripLayout.strip3, Icons.view_stream, "3 KOTAK"),
        const SizedBox(width: 20),
        _buildLayoutButton(
            PhotostripLayout.strip1, Icons.crop_portrait, "1 KOTAK"),
      ],
    );
  }

  Widget _buildLayoutButton(
      PhotostripLayout layout, IconData icon, String label) {
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
            Text(label,
                style: TextStyle(
                    color: isSelected ? textDark : accentGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12))
          ],
        ),
      ),
    );
  }
}
