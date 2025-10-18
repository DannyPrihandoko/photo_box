import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/home_screen.dart';

class SessionSelectionScreen extends StatelessWidget {
  final CameraDescription camera;
  const SessionSelectionScreen({super.key, required this.camera});

  void _startSession(BuildContext context, int totalTakes) {
    final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          camera: camera,
          totalTakes: totalTakes,
          sessionId: sessionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHOOSE YOUR SESSION'),
      ),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSessionButton(context, 3, "QUICK SHOT"),
            _buildSessionButton(context, 5, "STANDARD"),
            _buildSessionButton(context, 10, "MEGA SESSION"),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionButton(BuildContext context, int takes, String label) {
    return GestureDetector(
      onTap: () => _startSession(context, takes),
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF9F86C0),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF56CFE1).withAlpha(128),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$takes',
                style: const TextStyle(
                    fontSize: 48,
                    color: Color(0xFF2C2A4A),
                    fontWeight: FontWeight.bold)),
            const Text('PHOTOS',
                style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFFF0F0F0),
                    letterSpacing: 2)),
            const SizedBox(height: 5),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2C2A4A),
                    fontWeight: FontWeight.w300)),
          ],
        ),
      ),
    );
  }
}