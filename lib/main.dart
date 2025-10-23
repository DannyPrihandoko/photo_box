import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // Hapus atau komentari jika tidak ingin kunci orientasi
import 'package:photo_box/welcome_screen.dart';

// Definisikan warna tema
const Color primaryYellow = Color(0xFFFFD700);
const Color backgroundLight = Color(0xFFFFFFFF);
const Color backgroundDark = Color(0xFFF5F5F5);
const Color textDark = Color(0xFF333333);
const Color accentGrey = Color(0xFFBDBDBD);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // // Hapus atau komentari bagian ini jika ingin orientasi fleksibel
  // await SystemChrome.setPreferredOrientations([
  //   DeviceOrientation.landscapeLeft,
  //   DeviceOrientation.landscapeRight,
  // ]);

  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
    (camera) => camera.lensDirection == CameraLensDirection.front,
    orElse: () => cameras.first,
  );
  runApp(MyApp(camera: frontCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhotoBox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        primaryColor: primaryYellow,
        scaffoldBackgroundColor: backgroundLight, // Latar belakang utama putih
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryYellow,
          primary: primaryYellow,
          secondary: primaryYellow, // Bisa diganti jika perlu aksen kedua
          background: backgroundLight,
          onBackground: textDark,
          surface: backgroundDark, // Untuk Card atau elemen di atas background
          onSurface: textDark,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryYellow, // App bar kuning
          elevation: 1, // Sedikit bayangan
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textDark, // Teks gelap di app bar
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
          iconTheme: IconThemeData(color: textDark), // Ikon gelap
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryYellow, // Tombol utama kuning
            foregroundColor: textDark, // Teks tombol gelap
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
          foregroundColor: textDark, // Teks tombol outline gelap
          side: const BorderSide(color: accentGrey, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        )),
        iconTheme: const IconThemeData(color: textDark), // Ikon default gelap
        textTheme: const TextTheme(
          // Sesuaikan warna teks default
          bodyLarge: TextStyle(color: textDark),
          bodyMedium: TextStyle(color: textDark),
          titleLarge: TextStyle(color: textDark, fontWeight: FontWeight.bold),
          // Tambahkan style lain jika perlu
        ),
        // Tambahan styling lain jika diperlukan
      ),
      home: WelcomeScreen(camera: camera),
    );
  }
}
