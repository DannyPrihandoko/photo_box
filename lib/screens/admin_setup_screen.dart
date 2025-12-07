import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import 'package:photo_box/main.dart'; // Import tema warna
import 'package:photo_box/services/voucher_service.dart';
import 'package:photo_box/screens/frame_management_screen.dart'; // Import Screen Frame

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final VoucherService _voucherService = VoucherService();
  
  // List untuk menampung service yang ditemukan
  final List<Service> _foundServices = []; 
  
  bool _isScanning = false;
  Discovery? _discovery;

  @override
  void dispose() {
    // Stop discovery saat keluar halaman untuk menghemat resource
    _stopDiscovery();
    super.dispose();
  }

  Future<void> _stopDiscovery() async {
    if (_discovery != null) {
      await stopDiscovery(_discovery!);
      _discovery = null;
    }
  }

  Future<void> _startScan() async {
    // Reset state
    await _stopDiscovery();
    if (!mounted) return;

    setState(() {
      _isScanning = true;
      _foundServices.clear();
    });

    try {
      // Mulai mencari service dengan tipe _http._tcp
      _discovery = await startDiscovery('_http._tcp');
      _discovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          // Filter hanya service yang bernama 'PhotoBoxAdmin' (jika Anda set nama ini di server)
          // Atau tampilkan semua untuk debugging
          // if (service.name == 'PhotoBoxAdmin') { 
            setState(() {
              // Cek duplikat agar tidak muncul berkali-kali
              final index = _foundServices.indexWhere((s) => s.name == service.name);
              if (index == -1) {
                 _foundServices.add(service);
              }
            });
          // }
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error Scan: $e"), backgroundColor: Colors.red)
        );
      }
      setState(() => _isScanning = false);
    }
  }

  Future<void> _saveConfig(Service service) async {
    String? ip = service.host;

    // Logika Fallback: Jika host null, ambil dari list addresses
    if (ip == null && service.addresses != null && service.addresses!.isNotEmpty) {
       ip = service.addresses!.first.address;
    }

    if (ip != null) {
      // Simpan IP dan Port ke SharedPreferences
      await _voucherService.saveAdminConfig(ip, service.port ?? 8080);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tersambung ke Admin ($ip)!"), backgroundColor: Colors.green)
        );
        // Kembali ke layar sebelumnya setelah sukses
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text("Gagal mendapatkan IP Admin"), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: const Text("Admin & Setup"), 
        backgroundColor: backgroundDark, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView( // Pakai ScrollView agar aman di layar kecil
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Center(
              child: Column(
                children: const [
                  Icon(Icons.settings_remote, size: 60, color: accentGrey),
                  SizedBox(height: 10),
                  Text(
                    "Pengaturan Kiosk",
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // --- MENU 1: MANAJEMEN FRAME (FITUR BARU) ---
            const Text("KONTEN", style: TextStyle(color: primaryYellow, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            Card(
              color: Colors.white10,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.crop_original, color: Colors.blueAccent, size: 30),
                title: const Text("Manajemen Frame", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: const Text("Upload frame custom untuk photostrip", style: TextStyle(color: Colors.white70, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const FrameManagementScreen())
                  );
                },
              ),
            ),

            const SizedBox(height: 30),

            // --- MENU 2: KONEKSI SERVER ---
            const Text("KONEKSI SERVER", style: TextStyle(color: primaryYellow, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 10),
            
            const Text(
              "Pastikan Tablet ini dan Admin Server terhubung ke Wi-Fi yang sama.",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: textDark)) 
                : const Icon(Icons.wifi_find),
              label: Text(_isScanning ? "MENCARI SERVER..." : "CARI SERVER OTOMATIS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryYellow, 
                foregroundColor: textDark,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),
            
            if (_foundServices.isNotEmpty)
              const Text("Ditemukan:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            
            // List Service yang ditemukan
            ListView.builder(
              shrinkWrap: true, // Agar bisa dalam SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _foundServices.length,
              itemBuilder: (context, index) {
                final s = _foundServices[index];
                return Card(
                  color: Colors.white10,
                  margin: const EdgeInsets.only(top: 8),
                  child: ListTile(
                    leading: const Icon(Icons.computer, color: Colors.greenAccent),
                    title: Text(s.name ?? "Unknown Device", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text("${s.host ?? 'IP Detecting...'} : ${s.port}", style: const TextStyle(color: Colors.grey)),
                    trailing: ElevatedButton(
                      onPressed: () => _saveConfig(s),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 10)
                      ),
                      child: const Text("Sambungkan", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}