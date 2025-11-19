import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // Import wajib
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:photo_box/main.dart';
import 'package:photo_box/printing_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterServices _printerService = PrinterServices();
  
  List<BluetoothInfo> _availableDevices = [];
  bool _isLoading = false;
  String? _connectedMacAddress;

  @override
  void initState() {
    super.initState();
    _initPrinterSetup();
  }

  Future<void> _initPrinterSetup() async {
    await _checkSavedConnection();
    // Jangan langsung scan, biarkan user tekan refresh atau panggil manual dengan permission
    _scanDevices();
  }

  Future<void> _checkSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Pastikan key ini sama dengan yang ada di printing_services.dart
      _connectedMacAddress = prefs.getString('selected_printer_mac');
    });
  }

  // --- BAGIAN PENTING: REQUEST PERMISSION ---
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      // Minta izin Bluetooth Scan, Connect, dan Lokasi (untuk Android lama)
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      // Cek apakah izin Connect diberikan (Krusial untuk Android 12+)
      bool isConnectGranted = statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
      bool isScanGranted = statuses[Permission.bluetoothScan] == PermissionStatus.granted;
      
      // Jika Android 12+, Connect & Scan wajib. Jika Android < 12, Location biasanya cukup.
      if (isConnectGranted || isScanGranted) {
        return true;
      }
      
      // Fallback cek bluetooth standard
      if (await Permission.bluetooth.request().isGranted) {
        return true;
      }

      // Jika user menolak permanen, arahkan ke pengaturan
      if (statuses[Permission.bluetoothConnect] == PermissionStatus.permanentlyDenied) {
        return false; 
      }
    }
    return true; // iOS atau platform lain dianggap aman dulu
  }

  Future<void> _scanDevices() async {
    setState(() { _isLoading = true; });

    // 1. Minta Izin Dulu
    bool hasPermission = await _checkAndRequestPermissions();

    if (!hasPermission) {
      setState(() { _isLoading = false; });
      if (mounted) {
        _showPermissionDialog();
      }
      return;
    }

    // 2. Lakukan Scan jika izin aman
    try {
      final devices = await _printerService.getPairedPrinters();
      setState(() {
        _availableDevices = devices;
        _isLoading = false;
      });

      if (devices.isEmpty && mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tidak ada printer yang terhubung. Cek menu Bluetooth di HP Anda."))
        );
      }
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint("Error scan: $e");
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Izin Dibutuhkan"),
        content: const Text("Aplikasi butuh izin 'Perangkat Sekitar' (Nearby Devices) untuk connect ke printer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings(); // Buka setting HP
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() { _isLoading = true; });
    
    // Cek izin lagi sebelum connect (jaga-jaga)
    if (!await _checkAndRequestPermissions()) {
      setState(() { _isLoading = false; });
      if (mounted) _showPermissionDialog();
      return;
    }

    bool success = await _printerService.connectAndSave(device.macAdress);

    setState(() { _isLoading = false; });

    if (success) {
      setState(() {
        _connectedMacAddress = device.macAdress;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Terhubung ke ${device.name}"), backgroundColor: Colors.green)
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal terhubung. Pastikan printer nyala."), backgroundColor: Colors.red)
        );
      }
    }
  }

  Future<void> _testPrint() async {
    setState(() { _isLoading = true; });
    await _printerService.testPrint();
    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: backgroundDark,
        title: const Text("Pengaturan Printer", style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primaryYellow),
            onPressed: _scanDevices,
          )
        ],
      ),
      body: Column(
        children: [
          // --- STATUS HEADER ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.black26,
            child: Column(
              children: [
                Icon(Icons.print, size: 60, color: _connectedMacAddress != null ? primaryYellow : Colors.white54),
                const SizedBox(height: 10),
                Text(
                  _connectedMacAddress != null ? "PRINTER TERHUBUNG" : "BELUM TERHUBUNG",
                  style: TextStyle(
                    color: _connectedMacAddress != null ? Colors.greenAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold
                  ),
                ),
                if (_connectedMacAddress != null) ...[
                  const SizedBox(height: 5),
                  Text("MAC: $_connectedMacAddress", style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _testPrint,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryYellow, foregroundColor: textDark),
                    child: const Text("TEST PRINT"),
                  )
                ]
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("PERANGKAT PAIRED:", style: TextStyle(color: accentGrey, fontWeight: FontWeight.bold)),
            ),
          ),

          // --- LIST PERANGKAT ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: primaryYellow))
              : _availableDevices.isEmpty 
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bluetooth_disabled, color: Colors.grey, size: 50),
                          const SizedBox(height: 10),
                          const Text(
                            "Tidak ada printer ditemukan.\nPastikan printer sudah dipairing di menu Bluetooth HP Anda.", 
                            textAlign: TextAlign.center, 
                            style: TextStyle(color: Colors.grey)
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: openAppSettings,
                            child: const Text("Cek Izin Aplikasi"),
                          )
                        ],
                      ),
                    ))
                : ListView.separated(
                    itemCount: _availableDevices.length,
                    separatorBuilder: (c, i) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final device = _availableDevices[index];
                      final isConnected = device.macAdress == _connectedMacAddress;

                      return ListTile(
                        leading: Icon(
                          Icons.bluetooth, 
                          color: isConnected ? Colors.green : Colors.white 
                        ),
                        title: Text(device.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(device.macAdress, style: const TextStyle(color: Colors.grey)),
                        trailing: isConnected 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10, 
                                foregroundColor: Colors.white
                              ),
                              onPressed: () => _connectToDevice(device),
                              child: const Text("Pilih"),
                            ),
                        onTap: () => _connectToDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}