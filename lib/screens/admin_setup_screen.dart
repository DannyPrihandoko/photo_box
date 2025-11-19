import 'package:flutter/material.dart';
import 'package:nsd/nsd.dart';
import 'package:photo_box/main.dart'; // Pastikan path import ini benar sesuai struktur folder Anda
import 'package:photo_box/services/voucher_service.dart'; // Pastikan path import ini benar

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final VoucherService _voucherService = VoucherService();
  
  // Perbaikan Error 4: Tambahkan 'final'
  final List<Service> _foundServices = []; 
  
  bool _isScanning = false;
  Discovery? _discovery;

  @override
  void dispose() {
    // Perbaikan Error 1: Cek null sebelum stopDiscovery
    if (_discovery != null) {
      stopDiscovery(_discovery!);
    }
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() {
      _isScanning = true;
      _foundServices.clear();
    });

    try {
      _discovery = await startDiscovery('_http._tcp');
      _discovery!.addServiceListener((service, status) {
        if (status == ServiceStatus.found) {
          if (service.name == 'PhotoBoxAdmin') {
            setState(() {
              // Cek duplikat
              if (!_foundServices.any((s) => s.name == service.name)) {
                 _foundServices.add(service);
              }
            });
          }
        }
      });
    } catch (e) {
      // Perbaikan Error 5: Cek mounted sebelum pakai context
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error Scan: $e"))
        );
      }
      setState(() => _isScanning = false);
    }
  }

  Future<void> _saveConfig(Service service) async {
    String? ip = service.host;

    // Perbaikan Error 2 & 3: Cek null safety pada service.addresses
    if (ip == null && service.addresses != null && service.addresses!.isNotEmpty) {
       ip = service.addresses!.first.address;
    }

    if (ip != null) {
      await _voucherService.saveAdminConfig(ip, service.port!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Tersambung ke Admin ($ip)!"), backgroundColor: Colors.green)
        );
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
        title: const Text("Setup Koneksi Admin"), 
        backgroundColor: backgroundDark, 
        foregroundColor: Colors.white
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Icon(Icons.wifi_tethering, size: 80, color: accentGrey),
            const SizedBox(height: 20),
            const Text(
              "Pastikan Tablet ini dan Tablet Admin\nterhubung ke Wi-Fi yang sama.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 30),
            
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScan,
              icon: _isScanning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.search),
              label: Text(_isScanning ? "MENCARI ADMIN..." : "CARI OTOMATIS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryYellow, 
                foregroundColor: textDark,
                minimumSize: const Size(double.infinity, 50)
              ),
            ),

            const SizedBox(height: 20),
            const Align(alignment: Alignment.centerLeft, child: Text("Ditemukan:", style: TextStyle(color: Colors.white))),
            
            Expanded(
              child: ListView.builder(
                itemCount: _foundServices.length,
                itemBuilder: (context, index) {
                  final s = _foundServices[index];
                  return Card(
                    color: Colors.white10,
                    child: ListTile(
                      leading: const Icon(Icons.computer, color: Colors.white),
                      title: Text(s.name ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text("${s.host ?? 'IP Detecting...'} : ${s.port}", style: const TextStyle(color: Colors.grey)),
                      trailing: ElevatedButton(
                        onPressed: () => _saveConfig(s),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        child: const Text("Sambungkan"),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}