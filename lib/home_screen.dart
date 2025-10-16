import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'preview_screen.dart';

class HomeScreen extends StatefulWidget {
  final CameraDescription camera;

  const HomeScreen({
    super.key,
    required this.camera,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // Inisialisasi controller kamera
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high, // Tentukan resolusi
    );

    // Inisialisasi future controller
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Jangan lupa dispose controller saat widget tidak digunakan
    _controller.dispose();
    super.dispose();
  }
  
  void _takePicture() async {
    try {
      // Pastikan kamera sudah diinisialisasi
      await _initializeControllerFuture;

      // Ambil gambar
      final image = await _controller.takePicture();

      // Hentikan preview jika perlu (opsional)
      // await _controller.pausePreview();

      if (!mounted) return;

      // Navigasi ke PreviewScreen dengan membawa file gambar
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            imageFile: File(image.path),
          ),
        ),
      );
      
      // Lanjutkan preview setelah kembali dari PreviewScreen (opsional)
      // await _controller.resumePreview();

    } catch (e) {
      // Jika terjadi error, log di console
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Azure Booth'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library),
            onPressed: () {
              // Navigasi ke halaman galeri
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              // Gunakan FutureBuilder untuk menampilkan loading saat kamera siap
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    // Jika future selesai, tampilkan preview
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: CameraPreview(_controller),
                    );
                  } else {
                    // Jika masih loading, tampilkan indicator
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 30.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.filter_vintage, color: Theme.of(context).primaryColor, size: 30),
                  onPressed: () {},
                ),
                GestureDetector(
                  onTap: _takePicture, // Panggil fungsi take picture
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).primaryColor, width: 4),
                    ),
                    child: CircleAvatar(
                      radius: 35,
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 35),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.switch_camera, color: Theme.of(context).primaryColor, size: 30),
                  onPressed: () {
                    // Logika untuk ganti kamera (fitur selanjutnya)
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}