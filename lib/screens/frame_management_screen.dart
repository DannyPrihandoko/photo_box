import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FrameManagementScreen extends StatefulWidget {
  const FrameManagementScreen({super.key});

  @override
  State<FrameManagementScreen> createState() => _FrameManagementScreenState();
}

class _FrameManagementScreenState extends State<FrameManagementScreen> {
  List<File> _customFrames = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCustomFrames();
  }

  // --- LOGIKA LOAD & SAVE FRAME ---
  Future<void> _loadCustomFrames() async {
    final appDir = await getApplicationDocumentsDirectory();
    final frameDir = Directory('${appDir.path}/frames');
    
    if (!frameDir.existsSync()) {
      frameDir.createSync(recursive: true);
    }

    setState(() {
      _customFrames = frameDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png'))
          .toList();
    });
  }

  Future<void> _addFrame() async {
    // 1. Pilih Gambar dari Galeri
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // 2. Simpan ke Folder Aplikasi
    final appDir = await getApplicationDocumentsDirectory();
    final frameDir = Directory('${appDir.path}/frames');
    if (!frameDir.existsSync()) frameDir.createSync(recursive: true);

    final String fileName = 'frame_${DateTime.now().millisecondsSinceEpoch}.png';
    final File newImage = await File(image.path).copy('${frameDir.path}/$fileName');

    setState(() {
      _customFrames.add(newImage);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Frame berhasil ditambahkan!"), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _deleteFrame(File file) async {
    await file.delete();
    _loadCustomFrames();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manajemen Frame")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // --- INFORMASI SPESIFIKASI FRAME ---
          const Card(
            color: Colors.blueAccent,
            child: Padding(
              padding: EdgeInsets.all(15.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(" Panduan Upload Frame", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 10),
                  Text("• Format Wajib: PNG (Background Transparan)", style: TextStyle(color: Colors.white)),
                  Text("• Resolusi Lebar: 600px (Sesuai lebar kertas)", style: TextStyle(color: Colors.white)),
                  Text("• Resolusi Tinggi: 1200px - 1800px (Menyesuaikan panjang strip)", style: TextStyle(color: Colors.white)),
                  Text("• Area Tengah: HARUS TRANSPARAN agar foto terlihat.", style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _addFrame,
            icon: const Icon(Icons.upload_file),
            label: const Text("UPLOAD FRAME BARU DARI GALERI"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          
          const Text("Daftar Frame Custom:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          if (_customFrames.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("Belum ada frame custom.", style: TextStyle(color: Colors.grey)),
            ))
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _customFrames.length,
              itemBuilder: (context, index) {
                final file = _customFrames[index];
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        color: Colors.grey[200], // Checkerboard simulation
                      ),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0, right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFrame(file),
                      ),
                    )
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}