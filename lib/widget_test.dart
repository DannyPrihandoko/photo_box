import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';

// Pastikan import ini mengarah ke file welcome_screen.dart Anda
import 'package:photo_box/welcome_screen.dart';

void main() {
  // 1. Membuat Mock (Tiruan) Kamera untuk kebutuhan testing
  final mockCamera = const CameraDescription(
    name: '0',
    lensDirection: CameraLensDirection.back,
    sensorOrientation: 90,
  );

  group('PhotoBox WelcomeScreen & Flow Tests', () {
    testWidgets(
        '1. Memastikan elemen UI utama (Judul & Tombol) tampil di layar',
        (WidgetTester tester) async {
      // Build widget aplikasi langsung ke WelcomeScreen
      await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(camera: mockCamera),
      ));

      // Verifikasi teks sambutan ada di layar
      expect(find.text('Selamat Datang di'), findsWidgets);
      expect(find.text('PHOTOBOX SENYUM!'), findsWidgets);

      // Verifikasi tombol MULAI ada di layar
      expect(find.widgetWithText(ElevatedButton, 'MULAI'), findsWidgets);
    });

    testWidgets(
        '2. Memastikan Dialog Input Voucher muncul saat tombol MULAI ditekan',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(camera: mockCamera),
      ));

      // Cari dan tap tombol MULAI
      final mulaiButton = find.widgetWithText(ElevatedButton, 'MULAI').first;
      await tester.tap(mulaiButton);

      // Tunggu animasi dialog selesai dirender
      await tester.pumpAndSettle();

      // Verifikasi bahwa dialog voucher muncul
      expect(find.text('Masukkan Kode Voucher'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('3. Memastikan Dialog Mode Admin (Gembok) dapat diakses',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(camera: mockCamera),
      ));

      // Cari tombol icon gembok (lock)
      final lockIcon = find.byIcon(Icons.lock);
      expect(lockIcon, findsOneWidget);

      // Tap icon gembok
      await tester.tap(lockIcon);
      await tester.pumpAndSettle();

      // Verifikasi dialog konfirmasi mode admin muncul
      expect(find.text('Aktifkan Mode Admin?'), findsOneWidget);

      // Verifikasi ada textfield untuk input kode admin
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('4. Simulasi Input Kode Admin yang Salah',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: WelcomeScreen(camera: mockCamera),
      ));

      // Buka dialog admin
      await tester.tap(find.byIcon(Icons.lock));
      await tester.pumpAndSettle();

      // Masukkan teks sembarangan ke dalam TextField
      await tester.enterText(find.byType(TextField), 'kodesalah123');

      // Tekan konfirmasi
      await tester.tap(find.text('Konfirmasi'));
      await tester.pump(); // Render frame berikutnya untuk memunculkan snackbar

      // Pastikan ada pesan error (Snackbar) muncul di layar
      expect(find.text('Kode Salah!'), findsOneWidget);
    });
  });
}
