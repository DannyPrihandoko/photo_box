import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/main.dart'; // Impor untuk mengakses warna tema
import 'package:photo_box/printing_services.dart'; // Pastikan file ini ada

// Enum untuk jenis template
enum PhotostripLayout { vertical, grid, emoji_strip, emoji_grid }

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

// Data class untuk membawa info saat drag dari slot ke slot
class DragData {
  final String imagePath;
  final int fromIndex;
  DragData({required this.imagePath, required this.fromIndex});
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  // Default layout: Vertical
  PhotostripLayout _selectedLayout = PhotostripLayout.vertical;

  // 4 Slot untuk semua layout
  List<String?> _currentLayoutImages = List.filled(4, null);

  // Daftar emoji untuk template emoji
  final List<String> _emojis = ['😄', '💖', '✨', '📸', '🥳', '😎', '🤩', '👍'];

  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // Service Printing
  final PrintingService _printingServices = PrintingService();
  bool _isProcessing = false; // Loading state

  // Matriks Hitam Putih (Luminance preserving)
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
      for (int i = 0; i < 4 && i < widget.sessionImages.length; i++) {
        _currentLayoutImages[i] = widget.sessionImages[i].path;
      }
    });
  }

  void _updateLayout(PhotostripLayout layout) {
    setState(() {
      _selectedLayout = layout;
    });
  }

  // Fungsi Gabungan: Save, Print, lalu Reset
  Future<void> _saveAndPrintPhotostrip() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      if (_repaintBoundaryKey.currentContext == null) {
        throw Exception("Repaint boundary context is null");
      }

      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;

      // Delay sedikit untuk memastikan render stabil
      await Future.delayed(const Duration(milliseconds: 100));

      // Tangkap gambar (Sudah Hitam Putih karena ada ColorFiltered)
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);

      // --- 1. SIMPAN KE FILE LOKAL ---
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception("Could not get byte data");

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputDirPath =
          '${appDirectory.path}/${widget.sessionId}/photostrips';
      final Directory outputDir = Directory(outputDirPath);
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }

      final String outputPath =
          '$outputDirPath/photostrip_${DateTime.now().millisecondsSinceEpoch}.png';
      final File outputFile = File(outputPath);
      await outputFile.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disimpan. Membuka dialog print...')));

      // --- 2. PRINT (Membuka Dialog Sistem) ---
      // convertToBw: false, karena gambar sumber 'image' sudah B&W dari capture layar
      await _printingServices.printPhotoStripPdf(image, convertToBw: false);

      // --- 3. RESET KE HALAMAN AWAL ---
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal memproses: $e')));

      // Jika error, matikan loading agar bisa dicoba lagi
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(title: const Text('Buat Photostrip Anda')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- BAGIAN KIRI: PREVIEW TEMPLATE (HASIL AKHIR) ---
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildPhotostripTemplate(),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, color: accentGrey),

          // --- BAGIAN KANAN: GALERI & KONTROL ---
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("DRAG FOTO KE SLOT KIRI",
                      style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Expanded(child: _buildDraggableImageGrid()),
                  const SizedBox(height: 15),

                  const Text("PILIH TEMPLATE",
                      style: TextStyle(color: accentGrey, fontSize: 12)),
                  const SizedBox(height: 10),
                  _buildLayoutOptions(),

                  const SizedBox(height: 25),

                  // Tombol Save & Print
                  ElevatedButton.icon(
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: textDark, strokeWidth: 2))
                        : const Icon(Icons.print, size: 24),
                    label: Text(
                        _isProcessing ? 'MEMPROSES...' : 'SAVE & PRINT (B&W)'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
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

  /// Membangun UI Template Photostrip (yang akan di-capture)
  Widget _buildPhotostripTemplate() {
    double containerWidth = 200;
    if (_selectedLayout == PhotostripLayout.grid ||
        _selectedLayout == PhotostripLayout.emoji_grid) {
      containerWidth = 300;
    }

    Color paperBackgroundColor = Colors.white;
    if (_selectedLayout == PhotostripLayout.emoji_strip ||
        _selectedLayout == PhotostripLayout.emoji_grid) {
      paperBackgroundColor = const Color(0xFFFFFBE0); // Kuning sangat muda
    }

    // RepaintBoundary membungkus ColorFiltered agar hasil capture menjadi B&W
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Container(
          width: containerWidth,
          decoration: BoxDecoration(color: paperBackgroundColor, boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(50),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Logo
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('PHOTOBOX',
                        style: TextStyle(
                            color: Colors.black,
                            fontSize: 24,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w900)),
                    if (_selectedLayout == PhotostripLayout.emoji_strip ||
                        _selectedLayout == PhotostripLayout.emoji_grid)
                      const Text(' ✨', style: TextStyle(fontSize: 24)),
                  ],
                ),
              ),

              // Render Slot sesuai layout
              if (_selectedLayout == PhotostripLayout.vertical)
                _buildVerticalSlots()
              else if (_selectedLayout == PhotostripLayout.grid)
                _buildGridSlots()
              else if (_selectedLayout == PhotostripLayout.emoji_strip)
                _buildEmojiStripSlots()
              else if (_selectedLayout == PhotostripLayout.emoji_grid)
                _buildEmojiGridSlots(),

              const SizedBox(height: 12),
              // Footer Tanggal
              Text(
                DateTime.now().toString().substring(0, 10),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              if (_selectedLayout == PhotostripLayout.emoji_strip ||
                  _selectedLayout == PhotostripLayout.emoji_grid)
                const Text('🤩💖', style: TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Helper Layout ---

  Widget _buildVerticalSlots() {
    return Column(
      children: List.generate(4, (index) {
        final imagePath = _currentLayoutImages[index];
        return _buildDragTargetWrapper(index, imagePath,
            isGrid: false, isEmojiTheme: false);
      }),
    );
  }

  Widget _buildGridSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(4, (index) {
        final imagePath = _currentLayoutImages[index];
        return _buildDragTargetWrapper(index, imagePath,
            isGrid: true, isEmojiTheme: false);
      }),
    );
  }

  Widget _buildEmojiStripSlots() {
    return Column(
      children: List.generate(4, (index) {
        final imagePath = _currentLayoutImages[index];
        return _buildDragTargetWrapper(index, imagePath,
            isGrid: false, isEmojiTheme: true);
      }),
    );
  }

  Widget _buildEmojiGridSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(4, (index) {
        final imagePath = _currentLayoutImages[index];
        return _buildDragTargetWrapper(index, imagePath,
            isGrid: true, isEmojiTheme: true);
      }),
    );
  }

  // --- Logika Drag & Drop ---

  Widget _buildDragTargetWrapper(int index, String? imagePath,
      {required bool isGrid, required bool isEmojiTheme}) {
    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        bool isHighlighted = candidateData.isNotEmpty;
        // Cek apakah sedang drag item yang sama (swap)
        if (candidateData.isNotEmpty && candidateData.first is DragData) {
          if ((candidateData.first as DragData).fromIndex == index) {
            isHighlighted = false;
          }
        }

        // UI Slot Normal
        Widget slotContent = _buildSlotContent(
          imagePath,
          isHighlighted: isHighlighted,
          isGrid: isGrid,
          isEmojiTheme: isEmojiTheme,
          emojiIndex: index,
        );

        // Jika ada gambar, bungkus dengan Draggable agar bisa dipindah
        if (imagePath != null) {
          return Draggable<DragData>(
            data: DragData(imagePath: imagePath, fromIndex: index),
            feedback: Material(
              color: Colors.transparent,
              // Feedback TIDAK perlu dibungkus ColorFiltered agar user melihat foto asli saat drag
              child: _buildSlotContent(imagePath,
                  isGrid: isGrid,
                  isFeedback: true,
                  isEmojiTheme: isEmojiTheme,
                  emojiIndex: index),
            ),
            childWhenDragging: _buildSlotContent(imagePath,
                isGrid: isGrid,
                isDragging: true,
                isEmojiTheme: isEmojiTheme,
                emojiIndex: index),
            child: slotContent,
          );
        }

        return slotContent;
      },
      onAcceptWithDetails: (details) => _handleDrop(index, details.data),
    );
  }

  void _handleDrop(int index, Object data) {
    setState(() {
      if (data is String) {
        // Drop dari Galeri
        int oldIndex = _currentLayoutImages.indexOf(data);
        if (oldIndex != -1)
          _currentLayoutImages[oldIndex] =
              null; // Hapus dari slot lama jika ada
        _currentLayoutImages[index] = data;
      } else if (data is DragData) {
        // Swap antar Slot
        if (data.fromIndex != index) {
          final temp = _currentLayoutImages[index];
          _currentLayoutImages[index] = data.imagePath;
          _currentLayoutImages[data.fromIndex] = temp;
        }
      }
    });
  }

  // --- Visual Slot ---

  Widget _buildSlotContent(String? imagePath,
      {bool isHighlighted = false,
      bool isDragging = false,
      bool isFeedback = false,
      required bool isGrid,
      required bool isEmojiTheme,
      int emojiIndex = 0}) {
    double? width = isGrid ? 134 : null;
    double height = isGrid ? 134 : 120;

    if (isFeedback) {
      width = (width ?? 200) * 0.9;
      height = height * 0.9;
    }

    Border? slotBorder = Border.all(
      color: isHighlighted ? primaryYellow : Colors.transparent,
      width: isHighlighted ? 3 : 0,
    );
    Color slotBackgroundColor = backgroundDark;

    if (isEmojiTheme) {
      slotBackgroundColor = primaryYellow.withOpacity(0.2);
      if (isHighlighted) {
        slotBorder = Border.all(color: primaryYellow, width: 3);
      } else {
        slotBorder =
            Border.all(color: primaryYellow.withOpacity(0.5), width: 2);
      }
    }

    Widget innerContent = imagePath != null
        ? Image.file(File(imagePath), fit: BoxFit.cover)
        : Center(
            child: Icon(
              Icons.add_a_photo,
              color: accentGrey,
              size: 30,
            ),
          );

    // Overlay Emoji jika tema emoji aktif
    if (isEmojiTheme && imagePath != null && !isFeedback) {
      innerContent = Stack(
        children: [
          innerContent,
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Text(
                _emojis[emojiIndex % _emojis.length],
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ],
      );
    } else if (isEmojiTheme && imagePath == null) {
      innerContent = Center(
        child: Text(
          _emojis[emojiIndex % _emojis.length],
          style: const TextStyle(fontSize: 40),
        ),
      );
    }

    Widget content = Container(
      height: height,
      width: width,
      margin: isGrid ? null : const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: slotBackgroundColor,
        border: slotBorder,
        borderRadius:
            isEmojiTheme ? BorderRadius.circular(10) : BorderRadius.zero,
      ),
      child: innerContent,
    );

    return Opacity(opacity: isDragging ? 0.3 : 1.0, child: content);
  }

  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final imagePath = widget.sessionImages[index].path;
        return Draggable<String>(
          data: imagePath,
          feedback: Opacity(
            opacity: 0.8,
            child: Material(
              borderRadius: BorderRadius.circular(8),
              elevation: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(imagePath),
                    width: 80, height: 80, fit: BoxFit.cover),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(imagePath), fit: BoxFit.cover)),
          ),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(imagePath), fit: BoxFit.cover)),
        );
      },
    );
  }

  Widget _buildLayoutOptions() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLayoutOptionButton(
                PhotostripLayout.vertical, Icons.view_stream, 'Vertical Strip'),
            const SizedBox(width: 20),
            _buildLayoutOptionButton(
                PhotostripLayout.grid, Icons.grid_view, 'Grid Box'),
          ],
        ),
        const SizedBox(height: 15),
        const Text("TEMA EMOJI",
            style: TextStyle(color: accentGrey, fontSize: 12)),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLayoutOptionButton(PhotostripLayout.emoji_strip,
                Icons.emoji_emotions, 'Emoji Strip'),
            const SizedBox(width: 20),
            _buildLayoutOptionButton(
                PhotostripLayout.emoji_grid, Icons.apps_outlined, 'Emoji Grid'),
          ],
        ),
      ],
    );
  }

  Widget _buildLayoutOptionButton(
      PhotostripLayout layout, IconData icon, String label) {
    bool isSelected = _selectedLayout == layout;
    return InkWell(
      onTap: () => _updateLayout(layout),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryYellow : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? primaryYellow : accentGrey),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? textDark : accentGrey, size: 28),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: isSelected ? textDark : accentGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
