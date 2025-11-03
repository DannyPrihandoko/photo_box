import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/main.dart'; // Import untuk warna
import 'package:photo_box/printing_services.dart'; // Import service printer

enum PhotostripLayout {
  vertical3,
  vertical4,
  fourSquare,
  onePlusTwo,
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

class DragData {
  final String imagePath;
  final int fromIndex;
  DragData({required this.imagePath, required this.fromIndex});
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  PhotostripLayout _selectedLayout = PhotostripLayout.vertical3;
  List<String?> _currentLayoutImages = [];
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  // State untuk printing
  final PrintingService _printingService = PrintingService();
  String? _generatedPhotostripPath;
  bool _isSaving = false;
  bool _isPrinting = false;

  @override
  void initState() {
    super.initState();
    _updateLayoutImages(_selectedLayout);
  }

  void _updateLayoutImages(PhotostripLayout layout) {
    int numberOfSlots;
    switch (layout) {
      case PhotostripLayout.vertical3:
      case PhotostripLayout.onePlusTwo:
        numberOfSlots = 3;
        break;
      case PhotostripLayout.vertical4:
      case PhotostripLayout.fourSquare:
        numberOfSlots = 4;
        break;
    }
    setState(() {
      _selectedLayout = layout;
      _generatedPhotostripPath = null; // Reset jika layout diganti
      _currentLayoutImages = List.filled(numberOfSlots, null);
      for (int i = 0;
          i < numberOfSlots && i < widget.sessionImages.length;
          i++) {
        _currentLayoutImages[i] = widget.sessionImages[i].path;
      }
    });
  }

  // Fungsi untuk Generate dan Save
  Future<void> _generateAndSavePhotostrip() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      await Future.delayed(
          const Duration(milliseconds: 100)); // Delay untuk render
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
      
      // Simpan path untuk tombol Print/Selesai
      setState(() {
        _generatedPhotostripPath = outputPath;
        _isSaving = false;
      });

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat photostrip: $e')));
      setState(() => _isSaving = false);
    }
  }

  // Fungsi untuk Cetak
  Future<void> _printPhotostrip() async {
    if (_generatedPhotostripPath == null) return;
    if (_isPrinting) return;

    setState(() => _isPrinting = true);
    
    try {
      // 1. Hubungkan ke printer
      await _printingService.connectToPrinter('PRJ-80BT');

      // 2. Cetak gambar dari path
      await _printingService.printImage(_generatedPhotostripPath!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Berhasil dicetak!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  // Fungsi untuk Selesai
  void _finishSession() {
    // Kembali ke layar Welcome (paling awal)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark, // Background abu-abu
      appBar: AppBar(
        title: const Text('Buat Photostrip Anda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Jika sudah digenerate, konfirmasi kembali
          onPressed: () {
            if (_generatedPhotostripPath != null) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Keluar?'),
                  content: const Text('Photostrip sudah disimpan. Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Tutup dialog
                        Navigator.of(context).pop(); // Kembali ke SessionComplete
                      },
                      child: const Text('Ya, Keluar'),
                    ),
                  ],
                ),
              );
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 10.0),
              child: Center(child: _buildPhotostripTemplate()),
            ),
          ),
          const VerticalDivider(width: 1, color: accentGrey),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(20),
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
                  // Hanya tampilkan layout options jika strip BELUM digenerate
                  if (_generatedPhotostripPath == null) _buildLayoutOptions(),
                  const SizedBox(height: 25),
                  // Tampilkan tombol berdasarkan state
                  _buildBottomActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Bagian ini menampilkan tombol Generate ATAU tombol Print/Selesai
  Widget _buildBottomActionButtons() {
    if (_generatedPhotostripPath == null) {
      // State Awal: Tombol Generate
      return ElevatedButton.icon(
        icon: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: textDark))
            : const Icon(Icons.download_outlined, size: 24),
        label: Text(_isSaving ? 'MENYIMPAN...' : 'GENERATE & SAVE'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 55),
        ),
        onPressed: _isSaving ? null : _generateAndSavePhotostrip,
      );
    } else {
      // State Kedua: Tombol Cetak dan Selesai
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            icon: _isPrinting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: textDark))
                : const Icon(Icons.print_outlined, size: 24),
            label: Text(_isPrinting ? 'MENCETAK...' : 'CETAK PHOTOSTRIP'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
              backgroundColor: primaryYellow, // Tombol cetak
            ),
            onPressed: _isPrinting ? null : _printPhotostrip,
          ),
          const SizedBox(height: 15),
          OutlinedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 24),
            label: const Text('SELESAI (SESI BARU)'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 55),
            ),
            onPressed: _finishSession,
          ),
        ],
      );
    }
  }


  Widget _buildPhotostripTemplate() {
    Widget content;
    switch (_selectedLayout) {
      case PhotostripLayout.vertical3:
      case PhotostripLayout.vertical4:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_currentLayoutImages.length, (index) {
            return _buildDraggableOrDroppableSlot(index);
          }),
        );
        break;
      case PhotostripLayout.fourSquare:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _buildDraggableOrDroppableSlot(0)),
                const SizedBox(width: 6),
                Expanded(child: _buildDraggableOrDroppableSlot(1)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildDraggableOrDroppableSlot(2)),
                const SizedBox(width: 6),
                Expanded(child: _buildDraggableOrDroppableSlot(3)),
              ],
            ),
          ],
        );
        break;
      case PhotostripLayout.onePlusTwo:
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDraggableOrDroppableSlot(0),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildDraggableOrDroppableSlot(1)),
                const SizedBox(width: 6),
                Expanded(child: _buildDraggableOrDroppableSlot(2)),
              ],
            ),
          ],
        );
        break;
    }

    // Selalu bungkus dengan RepaintBoundary
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: Container(
        width: 200, // Lebar photostrip
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
            content, // Konten layout
            const SizedBox(height: 5), // Spacer footer
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableOrDroppableSlot(int index) {
    final imagePath =
        (index < _currentLayoutImages.length) ? _currentLayoutImages[index] : null;

    // Jika path ada, buat Draggable
    if (imagePath != null) {
      return Draggable<DragData>(
        // Data yang dibawa saat drag
        data: DragData(imagePath: imagePath, fromIndex: index),
        // Tampilan saat di-drag
        feedback: Opacity(
          opacity: 0.8,
          child: _buildSlotContent(imagePath, isFeedback: true),
        ),
        // Tampilan slot asli saat di-drag
        childWhenDragging: _buildSlotContent(imagePath, isDragging: true),
        // Tampilan slot normal (sebagai target drop juga)
        child: _buildDropTargetSlot(index, imagePath),
      );
    }
    // Jika path null, buat slot kosong (hanya target drop)
    return _buildDropTargetSlot(index, null);
  }

  Widget _buildDropTargetSlot(int index, String? imagePath) {
    if (index >= _currentLayoutImages.length) {
      return const SizedBox.shrink(); // Safety check
    }

    bool isTargetLocked = _generatedPhotostripPath != null; // Kunci jika sudah digenerate

    return DragTarget<Object>(
      builder: (context, candidateData, rejectedData) {
        bool isHighlighted = false;
        if (!isTargetLocked && candidateData.isNotEmpty) {
          isHighlighted = true;
          if (candidateData.first is DragData) {
            if ((candidateData.first as DragData).fromIndex == index) {
              isHighlighted = false;
            }
          }
        }
        return _buildSlotContent(imagePath, isHighlighted: isHighlighted);
      },
      // Hanya terima data jika target tidak dikunci
      onWillAcceptWithDetails: (details) => !isTargetLocked,
      onAcceptWithDetails: (details) {
        final data = details.data;
        setState(() {
          if (data is String) {
            // Drag dari grid kanan
            final existingIndex = _currentLayoutImages.indexOf(data);
            if (existingIndex != -1 && existingIndex != index) {
              // Jika gambar sudah ada di slot lain, kosongkan slot lama
              _currentLayoutImages[existingIndex] = null;
            }
            _currentLayoutImages[index] = data;
          } else if (data is DragData) {
            // Drag dari slot lain (swap)
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
    bool isGridLocked = _generatedPhotostripPath != null; // Kunci jika sudah digenerate

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final imagePath = widget.sessionImages[index].path;
        
        // Buat item yang bisa di-drag
        Widget draggableItem = Draggable<String>(
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

        // Jika grid dikunci, bungkus dengan Opacity agar terlihat non-interaktif
        if (isGridLocked) {
          return Opacity(
            opacity: 0.4,
            child: draggableItem,
          );
        }
        
        return draggableItem;
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
        // Anda bisa tambahkan layout lain di sini jika mau
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
