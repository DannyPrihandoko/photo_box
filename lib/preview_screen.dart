import 'dart:io';
import 'package:flutter/material.dart';

enum PreviewAction { retake, continuePhoto }

class PreviewScreen extends StatefulWidget {
  final File imageFile;
  const PreviewScreen({super.key, required this.imageFile});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..forward();
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop(PreviewAction.continuePhoto);
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _animationController.value,
              backgroundColor: const Color(0xFF9F86C0),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF56CFE1)),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(widget.imageFile,
                              fit: BoxFit.contain)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("LOOKING GOOD!",
                            style: TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 50),
                        _buildActionButton(
                            context, Icons.replay, 'RETAKE', () {
                          Navigator.of(context).pop(PreviewAction.retake);
                        }),
                        const SizedBox(height: 30),
                        _buildActionButton(
                            context, Icons.check_circle, 'CONTINUE', () {
                          Navigator.of(context).pop(PreviewAction.continuePhoto);
                        }),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(label, style: const TextStyle(fontSize: 20)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(250, 60),
        backgroundColor: const Color(0xFF9F86C0),
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
    );
  }
}