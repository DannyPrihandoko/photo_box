import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
  String _message = "GET READY!";
  int _countdown = 5;
  Timer? _countdownTimer;

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
      if (mounted) _startCountdown();
    });
  }

  void _startCountdown() {
    setState(() {
      _message = "SMILE!";
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
          _message = "LET'S TRY AGAIN!";
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startCountdown();
        });
      } else {
        _takenImages.add(image);
        if (_currentTake < widget.totalTakes) {
          setState(() {
            _currentTake++;
            _message = "NEXT PHOTO!";
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) _startCountdown();
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
    return Scaffold(
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
                    width: MediaQuery.of(context).size.width * 0.7,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9F86C0),
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(128),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: CameraPreview(_controller),
                          ),
                          Container(
                            color: Colors.black.withAlpha(77),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _message,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(blurRadius: 10)],
                                    ),
                                  ),
                                  if (_countdown > 0 && _message == "SMILE!")
                                    Text(
                                      '$_countdown',
                                      style: const TextStyle(
                                        fontSize: 150,
                                        color: Color(0xFF56CFE1),
                                        fontWeight: FontWeight.bold,
                                        shadows: [Shadow(blurRadius: 10)],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  child: Column(
                    children: [
                      const Text(
                        "LOOK HERE",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        Icons.arrow_downward,
                        color: Colors.white.withAlpha(200),
                        size: 30,
                      )
                    ],
                  ),
                ),
                Positioned(
                  bottom: 40,
                  child: Text(
                    "PHOTO $_currentTake / ${widget.totalTakes}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2),
                  ),
                ),
              ],
            );
          } else {
            return const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF56CFE1)));
          }
        },
      ),
    );
  }
}