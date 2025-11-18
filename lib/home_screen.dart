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
  // Counter untuk jumlah retake yang sudah digunakan
  int _retakesUsed = 0;
  // Batas maksimal retake per sesi
  final int _maxRetakes = 2;

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
      _countdown = 3;
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

      // Cek apakah kuota retake masih ada
      bool canRetake = _retakesUsed < _maxRetakes;

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            imageFile: File(image.path),
            allowRetake: canRetake, // Kirim status ke PreviewScreen
            retakesRemaining:
                _maxRetakes - _retakesUsed, // Opsional: untuk info UI
          ),
        ),
      );

      if (result == PreviewAction.retake && canRetake) {
        // Jika user memilih retake DAN kuota masih ada
        setState(() {
          _retakesUsed++; // Kurangi kuota (tambah counter)
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
        // Jika user memilih lanjut (atau dipaksa lanjut karena retake habis)
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

    return Scaffold(
      backgroundColor: backgroundDark,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller.value.isInitialized) {
            final frameWidth =
                isPortrait ? screenSize.width * 0.8 : screenSize.width * 0.5;

            final double cameraAspectRatio = _controller.value.aspectRatio;
            final double visualAspectRatio;

            if (isPortrait) {
              visualAspectRatio = 1 / cameraAspectRatio;
            } else {
              visualAspectRatio = cameraAspectRatio;
            }

            final frameHeight = frameWidth / visualAspectRatio;

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
                          CameraPreview(_controller),
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
                // ... Bagian UI bawah tetap sama
                Positioned(
                  bottom: isPortrait ? 30 : 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        "FOTO $_currentTake / ${widget.totalTakes}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 5),
                      // Indikator sisa retake (Opsional)
                      Text(
                        "Sisa Retake: ${_maxRetakes - _retakesUsed}",
                        style: const TextStyle(color: accentGrey, fontSize: 12),
                      ),
                    ],
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
