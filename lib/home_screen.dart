import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/main.dart'; // Import untuk warna
import 'package:photo_box/session_complete_screen.dart';
import 'package:photo_box/preview_screen.dart';

class HomeScreen extends StatefulWidget {
  final CameraDescription camera;
  final int totalTakes;
  final String sessionId;

  const HomeScreen({
    super.key,
    required this.camera,
    required this.totalTakes,
    required this.sessionId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  int _currentTake = 1;
  final List<XFile> _takenImages = [];
  String _message = "SIAP-SIAP!";
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _showGetReady = true;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.high,
        imageFormatGroup: ImageFormatGroup.yuv420);
    _initializeControllerFuture = _controller.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _startSession();
      }
    });
  }

  void _startSession() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _showGetReady = false);
        _startCountdown();
      }
    });
  }

  void _startCountdown() {
    setState(() {
      _message = "SENYUM!";
      _countdown = 5;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
        _takePicture();
      }
    });
  }

  void _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      if (!mounted) return;

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreviewScreen(imageFile: File(image.path)),
        ),
      );

      if (result == PreviewAction.retake) {
        setState(() {
          _message = "ULANGI LAGI!";
          _showGetReady = true;
        });
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _showGetReady = false);
            _startCountdown();
          }
        });
      } else {
        _takenImages.add(image);
        if (_currentTake < widget.totalTakes) {
          setState(() {
            _currentTake++;
            _message = "FOTO BERIKUTNYA!";
            _showGetReady = true;
          });
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() => _showGetReady = false);
              _startCountdown();
            }
          });
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SessionCompleteScreen(
                images: _takenImages,
                sessionId: widget.sessionId,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height > screenSize.width;
    final frameWidth =
        isPortrait ? screenSize.width * 0.8 : screenSize.width * 0.5;
    final frameHeight =
        isPortrait ? screenSize.height * 0.5 : screenSize.height * 0.7;

    return Scaffold(
      backgroundColor: backgroundDark,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller.value.isInitialized) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(
                    width: frameWidth,
                    height: frameHeight,
                    decoration: BoxDecoration(
                      color: backgroundLight,
                      borderRadius: BorderRadius.circular(isPortrait ? 30 : 40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isPortrait ? 22 : 32),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: frameWidth - 20,
                            height: frameHeight - 20,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller.value.previewSize!.height,
                                height: _controller.value.previewSize!.width,
                                child: CameraPreview(_controller),
                              ),
                            ),
                          ),
                          Container(
                            color: Colors.black.withAlpha(50),
                            child: Center(
                              child: _showGetReady ||
                                      (_countdown > 0 && _message == "SENYUM!")
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _message,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: isPortrait ? 36 : 48,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            shadows: const [
                                              Shadow(
                                                  blurRadius: 8,
                                                  color: Colors.black54)
                                            ],
                                          ),
                                        ),
                                        if (!_showGetReady && _countdown > 0)
                                          Text(
                                            '$_countdown',
                                            style: TextStyle(
                                              fontSize: isPortrait ? 100 : 150,
                                              color: primaryYellow,
                                              fontWeight: FontWeight.bold,
                                              shadows: const [
                                                Shadow(
                                                    blurRadius: 8,
                                                    color: Colors.black54)
                                              ],
                                            ),
                                          ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: isPortrait ? 40 : 50,
                  left: 0,
                  right: 0,
                  child: const Column(
                    children: [
                      Text(
                        "LIHAT KE KAMERA",
                        style: TextStyle(
                            color: textDark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Icon(Icons.arrow_downward, color: accentGrey, size: 24)
                    ],
                  ),
                ),
                Positioned(
                  bottom: isPortrait ? 30 : 40,
                  left: 0,
                  right: 0,
                  child: Text(
                    "FOTO $_currentTake / ${widget.totalTakes}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: textDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
                child: CircularProgressIndicator(color: primaryYellow));
          }
        },
      ),
    );
  }
}
