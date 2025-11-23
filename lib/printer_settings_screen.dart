import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'printing_services.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterServices _printerService = PrinterServices();

  // State Variables
  bool _isConnected = false;
  List<BluetoothInfo> _pairedDevices = [];
  String? _selectedMac;

  // Settings Variables
  // 1 = 58mm (384 dots)
  // 2 = 80mm High (576 dots) - Default
  // 3 = 80mm Medium (384 dots)
  // 7 = 80mm Custom (350 dots) -> BARU
  // 4 = 80mm Low (288 dots)
  int _printerMode = 2; 
  
  // Filter Gambar: 1 = Dithering (Detail), 2 = Threshold (Kontras Tinggi/Cepat)
  int _imageFilter = 1; 

  double _brightness = 1.2;
  double _contrast = 1.5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnection(); 
  }

  // --- LOAD & SAVE SETTINGS ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _printerMode = prefs.getInt('printer_mode_type') ?? 2;
      _imageFilter = prefs.getInt('printer_image_filter') ?? 1;
      _brightness = prefs.getDouble('printer_brightness') ?? 1.2;
      _contrast = prefs.getDouble('printer_contrast') ?? 1.5;
      _selectedMac = prefs.getString('selected_printer_mac');
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  // --- LOGIKA PERMISSION ---
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      final isConnectGranted = statuses[Permission.bluetoothConnect] == PermissionStatus.granted;
      final isScanGranted = statuses[Permission.bluetoothScan] == PermissionStatus.granted;
      final isLocationGranted = statuses[Permission.location] == PermissionStatus.granted;

      if (isConnectGranted && isScanGranted) return true;
      if (isLocationGranted && (await Permission.bluetooth.status.isGranted)) return true;
      if (statuses[Permission.bluetoothConnect] == PermissionStatus.permanentlyDenied) return false;
    }
    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Izin Dibutuhkan"),
        content: const Text("Aplikasi butuh izin Bluetooth untuk printer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text("Buka Pengaturan"),
          ),
        ],
      ),
    );
  }

  // --- PRINTER LOGIC ---
  Future<void> _checkConnection() async {
    bool status = await _printerService.isConnected;
    setState(() => _isConnected = status);
  }

  Future<void> _getPairedDevices() async {
    setState(() => _isLoading = true);
    bool hasPermission = await _checkAndRequestPermissions();
    if (!hasPermission) {
      setState(() => _isLoading = false);
      if (mounted) _showPermissionDialog();
      return;
    }

    try {
      final devices = await _printerService.getPairedPrinters();
      setState(() => _pairedDevices = devices);
      if (devices.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada printer paired.")));
      }
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToDevice(String mac) async {
    setState(() => _isLoading = true);
    if (!await _checkAndRequestPermissions()) {
      setState(() => _isLoading = false);
      if (mounted) _showPermissionDialog();
      return;
    }

    bool success = await _printerService.connectAndSave(mac);
    setState(() {
      _isConnected = success;
      _selectedMac = mac;
      _isLoading = false;
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Terhubung!"), backgroundColor: Colors.green));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal."), backgroundColor: Colors.red));
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    setState(() => _isConnected = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan Printer"),
        backgroundColor: Colors.white,
        elevation: 1,
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildConnectionSection(),
                const SizedBox(height: 16),
                _buildPaperSettingsSection(),
                const SizedBox(height: 16),
                _buildFilterSection(),
                const SizedBox(height: 16),
                _buildQualitySection(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isConnected ? () => _printerService.testPrint() : null,
                  icon: const Icon(Icons.print),
                  label: const Text("Test Print"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: _isConnected ? Colors.green : Colors.grey),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? "Status: TERHUBUNG" : "Status: TERPUTUS",
                  style: TextStyle(fontWeight: FontWeight.bold, color: _isConnected ? Colors.green : Colors.red),
                ),
                const Spacer(),
                if (_isConnected)
                  TextButton(onPressed: _disconnect, child: const Text("Putuskan", style: TextStyle(color: Colors.red)))
                else
                  TextButton(onPressed: _getPairedDevices, child: const Text("Scan")),
              ],
            ),
            const Divider(),
            if (_pairedDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("List kosong. Pastikan printer sudah pairing di Setting Bluetooth HP."),
              )
            else
              ..._pairedDevices.map((device) => ListTile(
                    title: Text(device.name.isEmpty ? "Unknown" : device.name),
                    subtitle: Text(device.macAdress),
                    trailing: (_selectedMac == device.macAdress && _isConnected)
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.link),
                    onTap: () => _connectToDevice(device.macAdress),
                    dense: true,
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperSettingsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Resolusi & Ukuran Kertas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            
            RadioListTile<int>(
              title: const Text("80mm High (Default)"),
              subtitle: const Text("Kualitas Terbaik (576 dots)"),
              value: 2,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val!); _saveSetting('printer_mode_type', val); },
            ),

            RadioListTile<int>(
              title: const Text("80mm Medium (384 dots)"),
              subtitle: const Text("Standard"),
              value: 3,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val!); _saveSetting('printer_mode_type', val); },
            ),

            // --- OPSI BARU 350 DOTS ---
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RadioListTile<int>(
                title: const Text("80mm Custom (350 dots)"),
                subtitle: const Text("Resolusi Menengah"),
                value: 7,
                groupValue: _printerMode,
                onChanged: (val) { setState(() => _printerMode = val!); _saveSetting('printer_mode_type', val); },
              ),
            ),
            // ---------------------------

            RadioListTile<int>(
              title: const Text("80mm Low (288 dots)"),
              subtitle: const Text("Resolusi Rendah - Cepat"),
              value: 4,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val!); _saveSetting('printer_mode_type', val); },
            ),
            
            const Divider(),
            
            RadioListTile<int>(
              title: const Text("Kertas 58mm"),
              value: 1,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val!); _saveSetting('printer_mode_type', val); },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Gaya & Filter Gambar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              "Gunakan 'Hitam Putih Tegas' jika proses print macet/lambat.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            
            RadioListTile<int>(
              title: const Text("Standard (Dithering)"),
              subtitle: const Text("Ada gradasi abu-abu (titik-titik). Lebih lambat."),
              value: 1,
              groupValue: _imageFilter,
              onChanged: (val) { 
                setState(() => _imageFilter = val!); 
                _saveSetting('printer_image_filter', val); 
              },
            ),

            Container(
               decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RadioListTile<int>(
                title: const Text("Hitam Putih Tegas (Threshold)"),
                subtitle: const Text("Tanpa abu-abu. Kontras tinggi & LEBIH CEPAT."),
                value: 2,
                groupValue: _imageFilter,
                onChanged: (val) { 
                  setState(() => _imageFilter = val!); 
                  _saveSetting('printer_image_filter', val); 
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Kecerahan & Kontras", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text("Kecerahan"), Text(_brightness.toStringAsFixed(1))],
            ),
            Slider(
              value: _brightness, min: 0.5, max: 2.5, divisions: 20,
              label: _brightness.toStringAsFixed(1),
              onChanged: (val) => setState(() => _brightness = val),
              onChangeEnd: (val) => _saveSetting('printer_brightness', val),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text("Kontras"), Text(_contrast.toStringAsFixed(1))],
            ),
            Slider(
              value: _contrast, min: 0.5, max: 2.5, divisions: 20,
              label: _contrast.toStringAsFixed(1),
              onChanged: (val) => setState(() => _contrast = val),
              onChangeEnd: (val) => _saveSetting('printer_contrast', val),
            ),
          ],
        ),
      ),
    );
  }
}