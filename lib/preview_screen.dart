import 'package:flutter/material.dart';
import 'dart:io'; // Import ini sekarang akan digunakan oleh 'File'

class PreviewScreen extends StatelessWidget {
  // 1. Variabel untuk menampung file gambar diaktifkan kembali
  final File imageFile; 
  
  // 2. Constructor diperbarui untuk menerima imageFile
  const PreviewScreen({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2342), // Darker blue for focus
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Preview'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              // 3. Menampilkan gambar dari file yang diterima, bukan placeholder lagi
              child: Image.file(imageFile), 
            ),
          ),
          Container(
            height: 120,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(context, Icons.replay, 'Retake', () {
                  Navigator.of(context).pop(); // Kembali ke HomeScreen
                }),
                _buildActionButton(context, Icons.save_alt, 'Save', () {
                  // Logika menyimpan gambar
                }),
                _buildActionButton(context, Icons.print, 'Print', () {
                  // Logika untuk mencetak via thermal printer
                }),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, IconData icon, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, color: Colors.white, size: 30),
          onPressed: onPressed,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        )
      ],
    );
  }
}