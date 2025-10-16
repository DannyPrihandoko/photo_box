import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // Import package camera
import 'home_screen.dart';

// Ubah main menjadi async
Future<void> main() async {
  // Pastikan plugin sudah diinisialisasi
  WidgetsFlutterBinding.ensureInitialized();

  // Dapatkan daftar kamera yang tersedia
  final cameras = await availableCameras();

  // Dapatkan kamera utama (biasanya kamera belakang)
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera; // Tambahkan properti kamera

  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Azure Booth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // ... tema Anda tetap sama ...
         primaryColor: const Color(0xFF006994), // Deep Ocean
        scaffoldBackgroundColor: const Color(0xFFE0F7FA), // Light Seafoam
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF006994),
          secondary: const Color(0xFFFF8A80), // Coral Pink Accent
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF006994),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        fontFamily: 'Poppins',
      ),
      // Kirim data kamera ke HomeScreen
      home: HomeScreen(camera: camera),
    );
  }
}