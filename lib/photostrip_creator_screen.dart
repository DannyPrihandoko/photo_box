import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/main.dart'; // Import untuk warna

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
      for (int i = 0;
          i < numberOfSlots && i < widget.sessionImages.length;
          i++) {
        _currentLayoutImages[i] = widget.sessionImages[i].path;
      }
    });
  }

  Future<void> _generateAndSavePhotostrip() async {
    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      // Tambahkan delay singkat sebelum menangkap gambar untuk memastikan render selesai
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
    // Dapatkan tinggi layar yang tersedia setelah AppBar dan padding
    final availableHeight = MediaQuery.of(context).size.height -
        kToolbarHeight -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        40; // 40 = padding vertikal

    return Scaffold(
      backgroundColor: backgroundDark, // Background abu-abu
      appBar: AppBar(title: const Text('Buat Photostrip Anda')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              // Scroll untuk template jika perlu
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
              child: Center(child: _buildPhotostripTemplate()),
            ),
          ),
          const VerticalDivider(width: 1, color: accentGrey), // Warna divider
          Expanded(
            flex: 3,
            child: Padding(
              // Padding luar untuk sisi kanan
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              // --- PERBAIKAN: Gunakan Column tanpa SingleChildScrollView di sini ---
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("DRAG FOTO KE SLOT KIRI",
                      style: TextStyle(
                          color: textDark, // Warna teks disesuaikan
                          fontSize: 18, // Ukuran disesuaikan
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  // --- PERBAIKAN: Beri tinggi terbatas pada GridView menggunakan Expanded ---
                  Expanded(child: _buildDraggableImageGrid()),
                  const SizedBox(height: 15),
                  _buildLayoutOptions(),
                  const SizedBox(height: 25),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download_outlined,
                        size: 24), // Ukuran ikon disesuaikan
                    label: const Text('GENERATE & SAVE'),
                    style: ElevatedButton.styleFrom(
                      minimumSize:
                          const Size(double.infinity, 55), // Tinggi tombol
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
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Container(
        width: 200,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withAlpha(50),
                  blurRadius: 5,
                  offset: const Offset(0, 2))
            ]),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 25,
              decoration: const BoxDecoration(
                  color: primaryYellow,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(4))),
              margin: const EdgeInsets.only(bottom: 6),
              alignment: Alignment.center,
              child: const Text('PHOTOBOX',
                  style: TextStyle(
                      color: textDark,
                      fontSize: 14,
                      fontWeight: FontWeight.bold)),
            ),
            ...List.generate(_currentLayoutImages.length, (index) {
              final imagePath = _currentLayoutImages[index];

              if (imagePath != null) {
                return Draggable<DragData>(
                  data: DragData(imagePath: imagePath, fromIndex: index),
                  feedback: Opacity(
                    opacity: 0.8,
                    child: _buildSlotContent(imagePath, isFeedback: true),
                  ),
                  childWhenDragging:
                      _buildSlotContent(imagePath, isDragging: true),
                  child: _buildDropTargetSlot(index, imagePath),
                );
              }
              return _buildDropTargetSlot(index, null);
            }),
            const SizedBox(height: 5), // Spacer footer
          ],
        ),
      ),
    );
  }

  Widget _buildDropTargetSlot(int index, String? imagePath) {
    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        bool isHighlighted = candidateData.isNotEmpty;
        if (candidateData.isNotEmpty && candidateData.first is DragData) {
          if ((candidateData.first as DragData).fromIndex == index) {
            isHighlighted = false;
          }
        }
        return _buildSlotContent(imagePath, isHighlighted: isHighlighted);
      },
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          if (data is String) {
            final existingIndex = _currentLayoutImages.indexOf(data);
            if (existingIndex != -1 && existingIndex != index) {
              _currentLayoutImages[existingIndex] = null;
            }
            _currentLayoutImages[index] = data;
          } else if (data is DragData) {
            final fromIndex = data.fromIndex;
            if (fromIndex != index) {
              final pathFrom = data.imagePath;
              final pathTo = _currentLayoutImages[index];
              _currentLayoutImages[index] = pathFrom;
              _currentLayoutImages[fromIndex] = pathTo;
            }
          }
        });
      },
    );
  }

  Widget _buildSlotContent(String? imagePath,
      {bool isHighlighted = false,
      bool isDragging = false,
      bool isFeedback = false}) {
    double slotHeight =
        _selectedLayout == PhotostripLayout.vertical3 ? 120 : 90;
    if (isFeedback) slotHeight = slotHeight * 0.9;

    return Opacity(
      opacity: isDragging ? 0.3 : 1.0,
      child: Container(
        height: slotHeight,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: backgroundDark,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isHighlighted ? primaryYellow : accentGrey.withAlpha(100),
            width: isHighlighted ? 2.5 : 1.5,
          ),
        ),
        child: imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Image.file(File(imagePath), fit: BoxFit.cover))
            : const Center(
                child: Icon(Icons.add_photo_alternate_outlined,
                    color: accentGrey, size: 30)),
      ),
    );
  }

  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      // Tidak perlu shrinkWrap atau physics karena sudah di dalam Expanded
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
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLayoutOption(
            PhotostripLayout.vertical3, Icons.view_stream_rounded, '3 Foto'),
        const SizedBox(width: 25),
        _buildLayoutOption(
            PhotostripLayout.vertical4, Icons.view_day_rounded, '4 Foto'),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? primaryYellow : backgroundDark,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                  color: isSelected ? textDark : accentGrey.withAlpha(100),
                  width: 1.5),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: primaryYellow.withAlpha(100), blurRadius: 8)
                    ]
                  : [],
            ),
            child:
                Icon(icon, color: isSelected ? textDark : accentGrey, size: 35),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: isSelected ? primaryYellow : accentGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ],
      ),
    );
  }
}
