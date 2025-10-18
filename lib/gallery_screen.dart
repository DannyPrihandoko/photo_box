import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
      images.addAll(photostripDir.listSync().whereType<File>().where((file) => file.path.endsWith('.png')));
    }
    
    images.addAll(sessionDir.listSync().whereType<File>().where((file) => file.path.endsWith('.jpg')));
    
    return images;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Galeri Hasil Foto'),
      ),
      body: FutureBuilder<List<Directory>>(
        future: _sessionFoldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF56CFE1)));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Galeri masih kosong.\nAyo ambil foto pertamamu!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 22),
              ),
            );
          }

          final sessionFolders = snapshot.data!;

          return ListView.builder(
            itemCount: sessionFolders.length,
            itemBuilder: (context, index) {
              final sessionDir = sessionFolders[index];
              final sessionId = sessionDir.path.split(Platform.pathSeparator).last;
              final sessionDate = DateTime.fromMillisecondsSinceEpoch(int.parse(sessionId));

              return FutureBuilder<List<File>>(
                future: _getImagesFromSession(sessionDir),
                builder: (context, imageSnapshot) {
                  if (!imageSnapshot.hasData || imageSnapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final images = imageSnapshot.data!;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B3F72).withAlpha(128),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sesi: ${sessionDate.day}/${sessionDate.month}/${sessionDate.year} - ${sessionDate.hour}:${sessionDate.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: images.length,
                            itemBuilder: (context, imgIndex) {
                              final imageFile = images[imgIndex];
                              bool isPhotostrip = imageFile.path.endsWith('.png');
                              
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PhotoViewerScreen(imageFile: imageFile),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    border: isPhotostrip ? Border.all(color: const Color(0xFF56CFE1), width: 3) : null,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(isPhotostrip ? 9 : 12),
                                    child: Hero(
                                      tag: imageFile.path,
                                      child: Image.file(imageFile, fit: BoxFit.cover, width: isPhotostrip ? 120 : 180),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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