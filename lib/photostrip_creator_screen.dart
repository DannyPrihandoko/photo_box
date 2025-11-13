import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/main.dart'; // Pastikan path ini sesuai

enum PhotostripLayout { vertical, grid }

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

class DragData {
  final String imagePath;
  final int fromIndex;
  DragData({required this.imagePath, required this.fromIndex});
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  // Default layout: Vertical
  PhotostripLayout _selectedLayout = PhotostripLayout.vertical;
  
  // 4 Slot untuk kedua layout
  List<String?> _currentLayoutImages = List.filled(4, null);
  
  final GlobalKey _repaintBoundaryKey = GlobalKey();

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

  Future<void> _generateAndSavePhotostrip() async {
    try {
      if (_repaintBoundaryKey.currentContext == null) return;
      
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      await Future.delayed(const Duration(milliseconds: 100));
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
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
          const SnackBar(content: Text('Photostrip berhasil disimpan!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat photostrip: $e')));
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
          // --- BAGIAN KIRI: PREVIEW TEMPLATE ---
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
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
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download_outlined, size: 24),
                    label: const Text('GENERATE & SAVE'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 55),
                    ),
                    onPressed: _generateAndSavePhotostrip,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotostripTemplate() {
    double containerWidth = _selectedLayout == PhotostripLayout.grid ? 300 : 200;

    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Container(
        width: containerWidth,
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ]),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: const Text('PHOTOBOX',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900)),
            ),
            
            if (_selectedLayout == PhotostripLayout.vertical)
              _buildVerticalSlots()
            else
              _buildGridSlots(),

            const SizedBox(height: 12),
             Text(
              DateTime.now().toString().substring(0, 10),
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalSlots() {
    return Column(
      children: List.generate(4, (index) {
        final imagePath = _currentLayoutImages[index];
        return _buildDragTargetWrapper(index, imagePath, isGrid: false);
      }),
    );
  }

  Widget _buildGridSlots() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(4, (index) {
        final imagePath = _currentLayoutImages[index];
        return _buildDragTargetWrapper(index, imagePath, isGrid: true);
      }),
    );
  }

  /// Fungsi Wrapper Utama untuk Slot (Target Drop + Sumber Drag)
  Widget _buildDragTargetWrapper(int index, String? imagePath, {required bool isGrid}) {
    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        bool isHighlighted = candidateData.isNotEmpty;
        if (candidateData.isNotEmpty && candidateData.first is DragData) {
          if ((candidateData.first as DragData).fromIndex == index) {
            isHighlighted = false;
          }
        }
        
        // Tampilan Slot Normal
        Widget slotContent = _buildSlotContent(
          imagePath, 
          isHighlighted: isHighlighted, 
          isGrid: isGrid
        );

        // Jika slot ada isinya, bungkus dengan Draggable agar bisa dipindahkan
        if (imagePath != null) {
          return Draggable<DragData>(
            data: DragData(imagePath: imagePath, fromIndex: index),
            feedback: Material(
              color: Colors.transparent,
              child: _buildSlotContent(imagePath, isGrid: isGrid, isFeedback: true),
            ),
            childWhenDragging: _buildSlotContent(imagePath, isGrid: isGrid, isDragging: true),
            child: slotContent,
          );
        }
        
        // Jika slot kosong, hanya tampilkan sebagai target drop
        return slotContent;
      },
      onAcceptWithDetails: (details) => _handleDrop(index, details.data),
    );
  }

  void _handleDrop(int index, Object data) {
    setState(() {
      if (data is String) { // Dari Galeri
        int oldIndex = _currentLayoutImages.indexOf(data);
        if (oldIndex != -1) _currentLayoutImages[oldIndex] = null;
        _currentLayoutImages[index] = data;
      } else if (data is DragData) { // Swap Slot
        if (data.fromIndex != index) {
          final temp = _currentLayoutImages[index];
          _currentLayoutImages[index] = data.imagePath;
          _currentLayoutImages[data.fromIndex] = temp;
        }
      }
    });
  }

  /// Tampilan Visual Slot (Kotak Gambar)
  Widget _buildSlotContent(String? imagePath,
      {bool isHighlighted = false,
      bool isDragging = false,
      bool isFeedback = false,
      required bool isGrid}) {
    
    // Tentukan dimensi
    double? width = isGrid ? 134 : null; 
    double height = isGrid ? 134 : 120; 
    
    if (isFeedback) {
      width = (width ?? 200) * 0.9;
      height = height * 0.9;
    }

    Widget content = Container(
      height: height,
      width: width,
      margin: isGrid ? null : const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEEEE), 
        border: Border.all(
          color: isHighlighted ? primaryYellow : Colors.transparent,
          width: isHighlighted ? 3 : 0,
        ),
      ),
      child: imagePath != null
          ? Image.file(File(imagePath), fit: BoxFit.cover)
          : const Center(
              child: Icon(Icons.add, color: Colors.grey),
            ),
    );

    return Opacity(
        opacity: isDragging ? 0.3 : 1.0,
        child: content
    );
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
                child: Image.file(File(imagePath), width: 80, height: 80, fit: BoxFit.cover),
              ),
            ),
          ),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(imagePath), fit: BoxFit.cover)),
        );
      },
    );
  }

  Widget _buildLayoutOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLayoutOptionButton(
            PhotostripLayout.vertical, Icons.view_stream, 'Vertical Strip'),
        const SizedBox(width: 20),
        _buildLayoutOptionButton(
            PhotostripLayout.grid, Icons.grid_view, 'Grid Box'),
      ],
    );
  }

  Widget _buildLayoutOptionButton(
      PhotostripLayout layout, IconData icon, String label) {
    bool isSelected = _selectedLayout == layout;
    return InkWell(
      onTap: () => _updateLayout(layout),
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