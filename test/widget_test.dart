import 'package:camera/camera.dart'; // PERBAIKAN: Menggunakan ':' bukan '.'
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:photo_box/main.dart' as app;

void main() {
  // Buat data kamera palsu (mock) untuk pengujian
  final mockCamera = CameraDescription(
    name: 'mock_cam',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  testWidgets('Renders HomeScreen and finds main widgets', (WidgetTester tester) async {
    // Bangun aplikasi kita dengan menggunakan data kamera palsu
    await tester.pumpWidget(app.MyApp(camera: mockCamera));

    // Verifikasi bahwa HomeScreen dirender dengan benar
    
    // Harusnya menemukan AppBar dengan title 'Azure Booth'
    expect(find.text('Azure Booth'), findsOneWidget);

    // Harusnya menemukan tombol shutter utama
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);

    // Harusnya menemukan tombol untuk galeri dan ganti kamera
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(find.byIcon(Icons.switch_camera), findsOneWidget);

    // Verifikasi bahwa tidak ada widget dari aplikasi counter lama
    expect(find.text('0'), findsNothing);
    expect(find.byIcon(Icons.add), findsNothing);
  });
}