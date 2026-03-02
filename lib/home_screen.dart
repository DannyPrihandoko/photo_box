import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:photo_box/main.dart'; // Import untuk warna
import 'package:photo_box/preview_screen.dart';
import 'package:photo_box/photostrip_creator_screen.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:photo_box/printing_services.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart'; // Menggunakan package baharu
import 'package:path_provider/path_provider.dart';

class HomeScreen extends StatefulWidget {
  final CameraDescription camera;
  final int totalTakes;
  final String sessionId;
  final String voucherCode;
  final bool isFlipbookMode; // PARAMETER BARU

  const HomeScreen({
    super.key,
    required this.camera,
    required this.totalTakes,
    required this.sessionId,
    required this.voucherCode,
    this.isFlipbookMode = false, // Secara default false
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  int _currentTake = 1;
  int _retakesUsed = 0;
  final int _maxRetakes = 2;

  final List<XFile> _takenImages = [];
  String _message = "SIAP-SIAP!";
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _showGetReady = true;

  bool _isRecordingFlipbook = false;

  @override
  void initState() {
    super.initState();
    _isRecordingFlipbook = widget.isFlipbookMode; // Tentukan mod awal

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
      // Ubah mesej bergantung pada mod
      _message = widget.isFlipbookMode ? "SIAP REKAM!" : "SENYUM!";
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
        // Cek mod yang sedang berjalan dan laksanakan aksi yang sesuai
        if (widget.isFlipbookMode) {
          _startFlipbookRecording();
        } else {
          _takePicture();
        }
      }
    });
  }

  // ==========================================
  // LOGIK FOTO NORMAL
  // ==========================================
  void _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      if (!mounted) return;

      bool canRetake = _retakesUsed < _maxRetakes;

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PreviewScreen(
            imageFile: File(image.path),
            allowRetake: canRetake,
            retakesRemaining: _maxRetakes - _retakesUsed,
          ),
        ),
      );

      if (result == PreviewAction.retake && canRetake) {
        setState(() {
          _retakesUsed++;
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
        await ImageGallerySaverPlus.saveFile(image.path,
            name: "${widget.voucherCode}_raw_$_currentTake");

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
              builder: (context) => PhotostripCreatorScreen(
                sessionImages: _takenImages,
                sessionId: widget.sessionId,
                voucherCode: widget.voucherCode,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  // ==========================================
  // LOGIK RAKAMAN FLIPBOOK AUTOMATIK
  // ==========================================
  void _startFlipbookRecording() async {
    try {
      await _initializeControllerFuture;

      setState(() {
        _message = "MEREKAM...";
        _showGetReady = true;
      });

      // Mula rakam video
      await _controller.startVideoRecording();

      // Rakam selama 3 saat
      await Future.delayed(const Duration(seconds: 3));

      // Hentikan rakaman
      final XFile videoFile = await _controller.stopVideoRecording();

      setState(() {
        _message = "MEMPROSES FLIPBOOK...";
      });

      // Ekstrak frame menggunakan FFmpeg
      List<File> extractedFrames =
          await _extractFramesFromVideo(videoFile.path);

      if (extractedFrames.length >= 24) {
        // Ambil 24 frame terbaik
        List<File> finalFrames = extractedFrames.take(24).toList();

        setState(() {
          _message = "SELESAI!";
        });

        // Terus cetak ke EPSON
        final printerServices = PrinterServices();
        await printerServices.printFlipbookLayout(finalFrames);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text("Berhasil membuat & mencetak 24 frame Flipbook!")),
          );

          // Kembali ke skrin utama selepas 2 saat
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted)
              Navigator.of(context).popUntil((route) => route.isFirst);
          });
        }
      } else {
        setState(() {
          _showGetReady = false;
        });
      }
    } catch (e) {
      debugPrint('Error recording flipbook video: $e');
      setState(() {
        _showGetReady = false;
      });
    }
  }

  Future<List<File>> _extractFramesFromVideo(String videoPath) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final outDirPath =
          '${dir.path}/flipbook_frames_${DateTime.now().millisecondsSinceEpoch}';
      await Directory(outDirPath).create(recursive: true);

      final String outPattern = '$outDirPath/frame_%03d.jpg';
      final String command = '-i "$videoPath" -frames:v 24 "$outPattern"';

      await FFmpegKit.execute(command);

      final directory = Directory(outDirPath);
      List<File> frames = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.jpg'))
          .toList();

      frames.sort((a, b) => a.path.compareTo(b.path));

      return frames;
    } catch (e) {
      debugPrint("Gagal mengekstrak frame: $e");
      return [];
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
      // Floating Action Button dibuang kerana mod automatik
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
                                      (_countdown > 0 &&
                                          (_message == "SENYUM!" ||
                                              _message == "SIAP REKAM!"))
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
                                              color: Colors.amber,
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
                  bottom: isPortrait ? 30 : 40,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        widget.isFlipbookMode
                            ? "MOD FLIPBOOK AKTIF"
                            : "FOTO $_currentTake / ${widget.totalTakes}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2),
                      ),
                      const SizedBox(height: 5),
                      if (!widget.isFlipbookMode)
                        Text(
                          "Voucher: ${widget.voucherCode} | Baki Retake: ${_maxRetakes - _retakesUsed}",
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            );
          } else {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }
        },
      ),
    );
  }
}
