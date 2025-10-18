import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_box/photostrip_creator_screen.dart';

class SessionCompleteScreen extends StatelessWidget {
  final List<XFile> images;
  final String sessionId;

  const SessionCompleteScreen(
      {super.key, required this.images, required this.sessionId});

  Future<void> _saveAllImages(BuildContext context) async {
    try {
      final Directory appDirectory = await getApplicationDocumentsDirectory();
      final String sessionPath = '${appDirectory.path}/$sessionId';
      final Directory sessionDirectory = Directory(sessionPath);

      if (!await sessionDirectory.exists()) {
        await sessionDirectory.create(recursive: true);
      }

      for (int i = 0; i < images.length; i++) {
        final String newPath = '$sessionPath/photo_${i + 1}.jpg';
        await File(images[i].path).copy(newPath);
      }
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Semua foto disimpan di folder $sessionId')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan foto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("YOUR PHOTOS", style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 16.0,
                        mainAxisSpacing: 16.0,
                      ),
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(images[index].path), fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 2, color: Color(0xFF9F86C0)),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.download, size: 28),
                      label: const Text('SAVE ALL'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        backgroundColor: const Color(0xFF56CFE1),
                        foregroundColor: const Color(0xFF2C2A4A),
                      ),
                      onPressed: () => _saveAllImages(context),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome, size: 28),
                      label: const Text('CREATE PHOTOSTRIP'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        backgroundColor: const Color(0xFF9F86C0),
                        foregroundColor: Colors.white,
                      ),
                       onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PhotostripCreatorScreen(
                              sessionImages: images,
                              sessionId: sessionId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      child: const Text('NEW SESSION'),
                      style: OutlinedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 20),
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        foregroundColor: const Color(0xFFF0F0F0),
                        side: const BorderSide(color: Color(0xFF9F86C0), width: 2),
                      ),
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}