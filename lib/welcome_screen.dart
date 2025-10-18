import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/gallery_screen.dart';
import 'package:photo_box/session_selection_screen.dart';

class WelcomeScreen extends StatefulWidget {
  final CameraDescription camera;
  const WelcomeScreen({super.key, required this.camera});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _slideAnimation = Tween<Offset>(
            begin: const Offset(0, -0.05), end: const Offset(0, 0.05))
        .animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2C2A4A), Color(0xFF4B3F72)],
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SessionSelectionScreen(camera: widget.camera)),
                );
              },
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 40.0, horizontal: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            flex: 2,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: const Icon(
                                Icons.camera_roll_rounded,
                                size: 250,
                                color: Color(0xFF56CFE1),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Siap untuk bersenang-senang?',
                                  style: TextStyle(
                                    fontSize: 28,
                                    color: Color(0xFFF0F0F0),
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                const Text(
                                  'PHOTOBOX!',
                                  style: TextStyle(
                                    fontSize: 72,
                                    color: Color(0xFF9F86C0),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const SizedBox(height: 80),
                                ScaleTransition(
                                  scale: _scaleAnimation,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 50, vertical: 25),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(50),
                                      color: const Color(0xFF56CFE1),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF56CFE1)
                                              .withAlpha(102),
                                          blurRadius: 15,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'MULAI!',
                                      style: TextStyle(
                                        fontSize: 32,
                                        color: Color(0xFF2C2A4A),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 40,
            child: IconButton(
              icon: const Icon(Icons.photo_library_rounded,
                  color: Colors.white, size: 40),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const GalleryScreen()),
                );
              },
            ),
          ),
          const Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Text(
              'Created by danny © 2025',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}