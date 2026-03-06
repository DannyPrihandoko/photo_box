import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_box/main.dart'; 
import 'package:photo_box/printing_services.dart';

class CalendarCreatorScreen extends StatefulWidget {
  final List<File> imageFiles;
  final String voucherCode;

  const CalendarCreatorScreen({
    super.key,
    required this.imageFiles,
    required this.voucherCode,
  });

  @override
  State<CalendarCreatorScreen> createState() => _CalendarCreatorScreenState();
}

class _CalendarCreatorScreenState extends State<CalendarCreatorScreen> {
  bool _isProcessing = false;
  final PrinterServices _printingServices = PrinterServices();

  Future<void> _processCalendar({required bool printNow}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Menyimpan Kalender 2026...')));

      // 1. Buat dan Simpan PDF Kalender
      File savedPdf = await _printingServices.saveCalendarPdf(
        widget.imageFiles, // Kirim list 3 foto
        widget.voucherCode,
      );

      // 2. Jika cetak ditekan
      if (printNow) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan! Menyiapkan printer...'), backgroundColor: Colors.green));
        await _printingServices.printPdfFile(savedPdf);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil Disimpan ke Galeri!'), backgroundColor: Colors.blue));
      }

      if (mounted) {
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).popUntil((route) => route.isFirst); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: Text("Kalender 2026 - ${widget.voucherCode}", style: const TextStyle(color: textDark, fontSize: 16)),
        backgroundColor: primaryYellow,
        iconTheme: const IconThemeData(color: textDark),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text("PREVIEW FOTO KALENDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2)),
            const SizedBox(height: 10),
            
            Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: widget.imageFiles.map((file) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Container(
                      width: 100, // Sesuaikan ukuran
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 5)],
                      ),
                      child: Image.file(file, fit: BoxFit.cover),
                    ),
                  )).toList(),
                )
              ),
            ),

            const SizedBox(height: 10),
            const Text("Sistem akan otomatis merender Kalender lengkap 12 Bulan beserta 3 foto ini pada kertas A4.", 
              textAlign: TextAlign.center,
              style: TextStyle(color: accentGrey, fontSize: 12)
            ),
            const SizedBox(height: 30),
            
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text("SIMPAN SAJA"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isProcessing ? null : () => _processCalendar(printNow: false),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 55,
                    child: ElevatedButton.icon(
                      icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: textDark, strokeWidth: 2)) : const Icon(Icons.print),
                      label: Text(_isProcessing ? "MEMPROSES..." : "CETAK EPSON"),
                      style: ElevatedButton.styleFrom(backgroundColor: primaryYellow, foregroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: _isProcessing ? null : () => _processCalendar(printNow: true),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}