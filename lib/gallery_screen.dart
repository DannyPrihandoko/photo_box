import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/main.dart';
import 'package:photo_box/photo_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<Directory>> _sessionFoldersFuture;

  @override
  void initState() {
    super.initState();
    _sessionFoldersFuture = _getSessionFolders();
  }

  Future<List<Directory>> _getSessionFolders() async {
    final appDir = await getApplicationDocumentsDirectory();
    final allItems = appDir.listSync();

    final sessionFolders = allItems.whereType<Directory>().where((dir) {
      return int.tryParse(dir.path.split(Platform.pathSeparator).last) != null;
    }).toList();

    sessionFolders.sort((a, b) => b.path.compareTo(a.path));
    return sessionFolders;
  }

  Future<List<File>> _getImagesFromSession(Directory sessionDir) async {
    List<File> images = [];

    final photostripDir = Directory('${sessionDir.path}/photostrips');
    if (photostripDir.existsSync()) {
      images.addAll(photostripDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.png')));
    }

    images.addAll(sessionDir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.jpg')));

    return images;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark, // Pastikan warna ini ada di main.dart
      appBar: AppBar(
        title: const Text('Galeri'),
      ),
      body: FutureBuilder<List<Directory>>(
        future: _sessionFoldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(
                    color:
                        primaryYellow)); // Pastikan warna ini ada di main.dart
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 80,
                      color: accentGrey), // Pastikan warna ini ada di main.dart
                  SizedBox(height: 20),
                  Text(
                    'Galeri masih kosong.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: textDark,
                        fontSize: 22), // Pastikan warna ini ada di main.dart
                  ),
                  Text(
                    'Hasil fotomu akan muncul di sini!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: accentGrey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final sessionFolders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            itemCount: sessionFolders.length,
            itemBuilder: (context, index) {
              final sessionDir = sessionFolders[index];
              final sessionId =
                  sessionDir.path.split(Platform.pathSeparator).last;
              final sessionDate =
                  DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));

              return FutureBuilder<List<File>>(
                future: _getImagesFromSession(sessionDir),
                builder: (context, imageSnapshot) {
                  if (!imageSnapshot.hasData || imageSnapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final images = imageSnapshot.data!;
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color:
                        backgroundLight, // Pastikan warna ini ada di main.dart
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sesi: ${sessionDate.day}/${sessionDate.month}/${sessionDate.year} - ${sessionDate.hour}:${sessionDate.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: textDark,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 150,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: images.length,
                              itemBuilder: (context, imgIndex) {
                                final imageFile = images[imgIndex];
                                bool isPhotostrip =
                                    imageFile.path.endsWith('.png');

                                return GestureDetector(
                                  onTap: () {
                                    // --- BAGIAN PERBAIKAN ---
                                    // Menggunakan parameter 'imageFile' sesuai definisi PhotoViewerScreen
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PhotoViewerScreen(
                                            imageFile: imageFile),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      border: isPhotostrip
                                          ? Border.all(
                                              color: primaryYellow, width: 2.5)
                                          : null,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withAlpha(30),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1))
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          isPhotostrip ? 8 : 10),
                                      child: Hero(
                                        tag: imageFile.path,
                                        child: Image.file(imageFile,
                                            fit: BoxFit.cover,
                                            width: isPhotostrip ? 100 : 150),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
