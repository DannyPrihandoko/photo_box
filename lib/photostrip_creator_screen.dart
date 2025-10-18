import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';

enum PhotostripLayout { vertical3, vertical4 }

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
  PhotostripLayout _selectedLayout = PhotostripLayout.vertical3;
  List<String?> _currentLayoutImages = [];
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _updateLayoutImages(PhotostripLayout.vertical3);
  }

  void _updateLayoutImages(PhotostripLayout layout) {
    int numberOfSlots = layout == PhotostripLayout.vertical3 ? 3 : 4;
    setState(() {
      _selectedLayout = layout;
      _currentLayoutImages = List.filled(numberOfSlots, null);
      for (int i = 0; i < numberOfSlots && i < widget.sessionImages.length; i++) {
        _currentLayoutImages[i] = widget.sessionImages[i].path;
      }
    });
  }

  Future<void> _generateAndSavePhotostrip() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal membuat photostrip: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Photostrip Anda')),
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
                child: Center(child: _buildPhotostripTemplate()),
              ),
            ),
          ),
          const VerticalDivider(width: 2, color: Color(0xFF9F86C0)),
          Expanded(
            flex: 3,
            // --- PERBAIKAN: Bungkus dengan SingleChildScrollView ---
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - (kToolbarHeight + 40),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          const Text("DRAG FOTO KE SLOT KIRI",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 250, // Beri tinggi yang cukup untuk grid
                            child: _buildDraggableImageGrid(),
                          ),
                          const SizedBox(height: 20),
                          _buildLayoutOptions(),
                        ],
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.file_download, size: 28),
                        label: const Text('GENERATE & SAVE'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 60),
                          backgroundColor: const Color(0xFF56CFE1),
                          foregroundColor: const Color(0xFF2C2A4A),
                        ),
                        onPressed: _generateAndSavePhotostrip,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotostripTemplate() {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 30,
              color: const Color(0xFF9F86C0),
              margin: const EdgeInsets.only(bottom: 8),
              alignment: Alignment.center,
              child: const Text('PHOTOSTRIP',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            ...List.generate(_currentLayoutImages.length, (index) {
              final imagePath = _currentLayoutImages[index];

              if (imagePath != null) {
                return Draggable<DragData>(
                  data: DragData(imagePath: imagePath, fromIndex: index),
                  feedback: Opacity(
                    opacity: 0.8,
                    child: _buildSlotContent(imagePath),
                  ),
                  childWhenDragging:
                      _buildSlotContent(imagePath, isDragging: true),
                  child: _buildDropTargetSlot(index, imagePath),
                );
              }
              return _buildDropTargetSlot(index, null);
            }),
            Container(
              height: 25,
              color: const Color(0xFF9F86C0),
              margin: const EdgeInsets.only(top: 8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropTargetSlot(int index, String? imagePath) {
    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        return _buildSlotContent(imagePath,
            isHighlighted: candidateData.isNotEmpty);
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          if (data is String) {
            _currentLayoutImages[index] = data;
          } else if (data is DragData) {
            final fromIndex = data.fromIndex;
            final pathFrom = data.imagePath;
            final pathTo = _currentLayoutImages[index];
            _currentLayoutImages[index] = pathFrom;
            _currentLayoutImages[fromIndex] = pathTo;
          }
        });
      },
    );
  }

  Widget _buildSlotContent(String? imagePath,
      {bool isHighlighted = false, bool isDragging = false}) {
    return Opacity(
      opacity: isDragging ? 0.3 : 1.0,
      child: Container(
        height: _selectedLayout == PhotostripLayout.vertical3 ? 150 : 110,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isHighlighted
                ? const Color(0xFF56CFE1)
                : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(File(imagePath), fit: BoxFit.cover))
            : const Center(
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: Colors.grey, size: 40)),
      ),
    );
  }

  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final imagePath = widget.sessionImages[index].path;
        return Draggable<String>(
          data: imagePath,
          feedback: Opacity(
            opacity: 0.8,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(File(imagePath),
                  width: 120, height: 120, fit: BoxFit.cover),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLayoutOption(PhotostripLayout.vertical3, Icons.looks_3, '3 Foto'),
        _buildLayoutOption(PhotostripLayout.vertical4, Icons.looks_4, '4 Foto'),
      ],
    );
  }

  Widget _buildLayoutOption(
      PhotostripLayout layout, IconData icon, String label) {
    bool isSelected = _selectedLayout == layout;
    return GestureDetector(
      onTap: () => _updateLayoutImages(layout),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFF56CFE1) : const Color(0xFF9F86C0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 2),
            ),
            child: Icon(icon,
                color: isSelected ? const Color(0xFF2C2A4A) : Colors.white,
                size: 40),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: isSelected ? const Color(0xFF56CFE1) : Colors.white,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}