import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';

import 'package:photo_box/main.dart'; 
import 'package:photo_box/printing_services.dart'; 
import 'package:photo_box/printer_settings_screen.dart'; 

// Enum Layout
enum PhotostripLayout { strip2, strip1 }

// Class untuk menyimpan data setiap slot foto
class PhotostripItem {
  String? imagePath;
  Alignment alignment;
  PhotostripItem({this.imagePath, this.alignment = Alignment.center});
}

// Class data untuk Drag & Drop
class DragData {
  final PhotostripItem item;
  final int fromIndex;
  DragData({required this.item, required this.fromIndex});
}

class PhotostripCreatorScreen extends StatefulWidget {
  final List<XFile> sessionImages;
  final String sessionId;
  final String voucherCode;

  const PhotostripCreatorScreen({
    super.key,
    required this.sessionImages,
    required this.sessionId,
    required this.voucherCode,
  });

  @override
  State<PhotostripCreatorScreen> createState() => _PhotostripCreatorScreenState();
}

class _PhotostripCreatorScreenState extends State<PhotostripCreatorScreen> {
  PhotostripLayout _selectedLayout = PhotostripLayout.strip2;
  
  List<PhotostripItem> _currentLayoutItems = List.generate(
    2, (index) => PhotostripItem(imagePath: null)
  );
  
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  final PrinterServices _printingServices = PrinterServices();
  bool _isProcessing = false;

  // --- FRAME VARIABLES ---
  int _selectedFrameIndex = 0; 
  List<File> _customFrames = []; 

  // --- Filter Hitam Putih ---
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
    _loadCustomFrames();
  }

  void _initializeImages() {
    setState(() {
      for (int i = 0; i < 2 && i < widget.sessionImages.length; i++) {
        _currentLayoutItems[i].imagePath = widget.sessionImages[i].path;
      }
    });
  }

  Future<void> _loadCustomFrames() async {
    final appDir = await getApplicationDocumentsDirectory();
    final frameDir = Directory('${appDir.path}/frames');
    if (frameDir.existsSync()) {
      setState(() {
        _customFrames = frameDir.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList();
      });
    }
  }

  void _updateLayout(PhotostripLayout layout) {
    setState(() {
      _selectedLayout = layout;
      if (layout == PhotostripLayout.strip1 && _currentLayoutItems[0].imagePath == null) {
         if (widget.sessionImages.isNotEmpty) {
           _currentLayoutItems[0].imagePath = widget.sessionImages[0].path;
         }
      }
    });
  }

  String _getIndonesianDate() {
    final now = DateTime.now();
    const List<String> months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  // --- FRAME DESIGN ---
  Widget _buildEmojiFrame1() {
    return Stack(
      children: [
        Container(decoration: BoxDecoration(border: Border.all(color: Colors.pinkAccent, width: 5))),
        const Positioned(top: 10, left: 10, child: Text("💖", style: TextStyle(fontSize: 24))),
        const Positioned(top: 10, right: 10, child: Text("✨", style: TextStyle(fontSize: 24))),
        const Positioned(bottom: 10, left: 10, child: Text("🌸", style: TextStyle(fontSize: 24))),
        const Positioned(bottom: 10, right: 10, child: Text("🥰", style: TextStyle(fontSize: 24))),
      ],
    );
  }

  Widget _buildEmojiFrame2() {
    return Stack(
      children: [
        Container(decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 6))),
        const Positioned(top: 5, left: 5, child: Text("😎", style: TextStyle(fontSize: 24))),
        const Positioned(top: 5, right: 5, child: Text("🔥", style: TextStyle(fontSize: 24))),
        const Positioned(bottom: 5, left: 5, child: Text("📸", style: TextStyle(fontSize: 24))),
        const Positioned(bottom: 5, right: 5, child: Text("⚡", style: TextStyle(fontSize: 24))),
      ],
    );
  }

  Future<void> _saveAndPrintPhotostrip() async {
    if (_isProcessing) return;
    setState(() { _isProcessing = true; });

    try {
      if (_repaintBoundaryKey.currentContext == null) throw Exception("Context null");
      
      RenderRepaintBoundary boundary = _repaintBoundaryKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String outputDirPath = '${appDirectory.path}/${widget.voucherCode}';
      await Directory(outputDirPath).create(recursive: true);

      final String fileName = 'strip_${DateTime.now().millisecondsSinceEpoch}.png';
      final String outputPath = '$outputDirPath/$fileName';
      await File(outputPath).writeAsBytes(pngBytes);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyimpan ke Galeri...')));
      
      await ImageGallerySaverPlus.saveImage(
        pngBytes,
        quality: 100,
        name: "${widget.voucherCode}_photostrip"
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyiapkan printer...')));

      bool success = await _printingServices.printPhotoStrip(image);

      if (!success) {
        if (mounted) _showPrinterErrorDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sukses!'), backgroundColor: Colors.green));
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    } finally {
      if (mounted) setState(() { _isProcessing = false; });
    }
  }

  void _showPrinterErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Printer Error"),
        content: const Text("Gagal terhubung ke printer."),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup"))],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Keluar?"),
        content: const Text("Pastikan sudah cetak/simpan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("Ya, Keluar"),
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
        title: Text('Voucher: ${widget.voucherCode}', style: const TextStyle(fontSize: 16, color: textDark)),
        backgroundColor: backgroundDark,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: textDark), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.home_rounded, color: textDark, size: 30), onPressed: _showExitDialog)],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isPortrait = orientation == Orientation.portrait;
          return Flex(
            direction: isPortrait ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2, 
                child: Container(
                  color: Colors.grey[200],
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: FittedBox(fit: BoxFit.scaleDown, child: _buildPhotostripTemplate()),
                    ),
                  ),
                ),
              ),
              if (isPortrait) const Divider(height: 1) else const VerticalDivider(width: 1),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3))
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app, size: 20, color: Colors.blue),
                            SizedBox(width: 10),
                            Expanded(child: Text("GESER FOTO di preview untuk atur posisi.\nTAHAN & DRAG untuk tukar posisi.", style: TextStyle(fontSize: 11, color: textDark))),
                          ],
                        ),
                      ),
                      
                      const Align(alignment: Alignment.centerLeft, child: Text("FOTO (Drag ke Preview)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      const SizedBox(height: 5),
                      Expanded(child: _buildDraggableImageGrid()),
                      const SizedBox(height: 15),
                      
                      // FRAME SELECTOR
                      const Align(alignment: Alignment.centerLeft, child: Text("PILIH FRAME", style: TextStyle(color: accentGrey, fontSize: 12))),
                      const SizedBox(height: 5),
                      SizedBox(
                        height: 60,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildFrameOption(0, "Polos", Colors.white),
                            _buildFrameOption(1, "Cute", Colors.pink[100]!),
                            _buildFrameOption(2, "Cool", Colors.grey[400]!),
                            ...List.generate(_customFrames.length, (index) => _buildCustomFrameOption(index + 3, _customFrames[index])),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      const Text("LAYOUT", style: TextStyle(color: accentGrey, fontSize: 12)),
                      _buildLayoutOptions(),
                      
                      const SizedBox(height: 20),
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

  Widget _buildFrameOption(int index, String label, Color color) {
    bool isSelected = _selectedFrameIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFrameIndex = index),
      child: Container(
        width: 60, margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color,
          border: isSelected ? Border.all(color: primaryYellow, width: 3) : Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
      ),
    );
  }

  Widget _buildCustomFrameOption(int index, File file) {
    bool isSelected = _selectedFrameIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFrameIndex = index),
      child: Container(
        width: 60, margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          border: isSelected ? Border.all(color: primaryYellow, width: 3) : Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.file(file, fit: BoxFit.cover)),
      ),
    );
  }

  Widget _buildPhotostripTemplate() {
    return RepaintBoundary(
      key: _repaintBoundaryKey,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_greyscaleMatrix),
        child: Container(
          width: 200, 
          decoration: BoxDecoration(
            color: Colors.white, 
            border: Border.all(color: Colors.black, width: 2.0), // Border Hitam
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)]
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('SENYUM', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black)),
                    Text(_getIndonesianDate(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 12),
                    if (_selectedLayout == PhotostripLayout.strip2) _build2StripSlots() else _build1StripSlot(),
                  ],
                ),
              ),
              if (_selectedFrameIndex == 1) Positioned.fill(child: _buildEmojiFrame1())
              else if (_selectedFrameIndex == 2) Positioned.fill(child: _buildEmojiFrame2())
              else if (_selectedFrameIndex >= 3) Positioned.fill(child: Image.file(_customFrames[_selectedFrameIndex - 3], fit: BoxFit.fill))
            ],
          ),
        ),
      ),
    );
  }

  Widget _build2StripSlots() => Column(children: List.generate(2, (i) => _buildDragTargetWrapper(i, _currentLayoutItems[i], height: 140)));
  Widget _build1StripSlot() => _buildDragTargetWrapper(0, _currentLayoutItems[0], height: 300);

  Widget _buildDragTargetWrapper(int index, PhotostripItem item, {required double height}) {
    return DragTarget<Object>(
      builder: (ctx, cand, rej) => _buildSlotContent(index, item, isHighlighted: cand.isNotEmpty, height: height),
      onAcceptWithDetails: (details) {
        setState(() {
           final data = details.data;
           if (data is String) {
             for (var i = 0; i < _currentLayoutItems.length; i++) {
               if (_currentLayoutItems[i].imagePath == data) _currentLayoutItems[i].imagePath = null;
             }
             _currentLayoutItems[index].imagePath = data;
             _currentLayoutItems[index].alignment = Alignment.center;
           } else if (data is DragData) {
             if (data.fromIndex != index) {
               final tempPath = _currentLayoutItems[index].imagePath;
               final tempAlign = _currentLayoutItems[index].alignment;
               _currentLayoutItems[index].imagePath = data.item.imagePath;
               _currentLayoutItems[index].alignment = data.item.alignment;
               _currentLayoutItems[data.fromIndex].imagePath = tempPath;
               _currentLayoutItems[data.fromIndex].alignment = tempAlign;
             }
           }
        });
      },
    );
  }

  Widget _buildSlotContent(int index, PhotostripItem item, {bool isHighlighted = false, required double height}) {
    return Container(
      height: height, width: 200, margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.grey[300], border: Border.all(color: isHighlighted ? primaryYellow : Colors.transparent, width: 3)),
      child: item.imagePath != null 
        ? LongPressDraggable<DragData>(
            data: DragData(item: item, fromIndex: index), delay: const Duration(milliseconds: 300),
            feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.7, child: Image.file(File(item.imagePath!), height: height, width: 200, fit: BoxFit.cover))),
            childWhenDragging: Container(color: Colors.grey[200]),
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  double sensitivity = 2.5; 
                  // Inverted Axis fix
                  item.alignment = item.alignment - Alignment((details.delta.dx / 200) * sensitivity, (details.delta.dy / height) * sensitivity);
                });
              },
              child: ClipRect(child: Image.file(File(item.imagePath!), fit: BoxFit.cover, alignment: item.alignment, width: 200, height: height)),
            ),
          )
        : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 30)),
    );
  }

  Widget _buildDraggableImageGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: widget.sessionImages.length,
      itemBuilder: (context, index) {
        final path = widget.sessionImages[index].path;
        return Draggable<String>(
          data: path, 
          feedback: Material(elevation: 4, borderRadius: BorderRadius.circular(8), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), width: 80, height: 80, fit: BoxFit.cover))),
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(path), fit: BoxFit.cover)),
        );
      },
    );
  }

  Widget _buildLayoutOptions() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _buildLayoutButton(PhotostripLayout.strip2, Icons.view_agenda, "2 KOTAK"),
      const SizedBox(width: 20),
      _buildLayoutButton(PhotostripLayout.strip1, Icons.crop_portrait, "1 KOTAK"),
    ]);
  }

  Widget _buildLayoutButton(PhotostripLayout layout, IconData icon, String label) {
    bool isSelected = _selectedLayout == layout;
    return InkWell(
      onTap: () => _updateLayout(layout),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: isSelected ? primaryYellow : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? primaryYellow : accentGrey)),
        child: Row(children: [Icon(icon, color: isSelected ? textDark : accentGrey, size: 20), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? textDark : accentGrey, fontWeight: FontWeight.bold, fontSize: 12))]),
      ),
    );
  }
}