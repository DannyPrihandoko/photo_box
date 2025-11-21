import 'package:flutter/material.dart';
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
  int _paperSize = 576; // Default 80mm (576 dots)
  double _brightness = 1.2;
  double _contrast = 1.5;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnection();
    _getPairedDevices();
  }

  // --- LOAD & SAVE SETTINGS ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 576 = 80mm, 384 = 58mm
      _paperSize = prefs.getInt('printer_paper_width') ?? 576;
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

  // --- PRINTER LOGIC ---
  Future<void> _checkConnection() async {
    bool status = await _printerService.isConnected;
    setState(() => _isConnected = status);
  }

  Future<void> _getPairedDevices() async {
    final devices = await _printerService.getPairedPrinters();
    setState(() => _pairedDevices = devices);
  }

  Future<void> _connectToDevice(String mac) async {
    setState(() => _isLoading = true);
    bool success = await _printerService.connectAndSave(mac);
    setState(() {
      _isConnected = success;
      _selectedMac = mac;
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Terhubung ke Printer!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Gagal menghubungkan."), backgroundColor: Colors.red),
      );
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
        titleTextStyle: const TextStyle(
            color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
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
                _buildQualitySection(),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed:
                      _isConnected ? () => _printerService.testPrint() : null,
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
                Icon(Icons.bluetooth,
                    color: _isConnected ? Colors.green : Colors.grey),
                const SizedBox(width: 10),
                Text(
                  _isConnected ? "Status: TERHUBUNG" : "Status: TERPUTUS",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _isConnected ? Colors.green : Colors.red,
                  ),
                ),
                const Spacer(),
                if (_isConnected)
                  TextButton(
                    onPressed: _disconnect,
                    child: const Text("Putuskan",
                        style: TextStyle(color: Colors.red)),
                  )
                else
                  TextButton(
                    onPressed: _getPairedDevices,
                    child: const Text("Refresh"),
                  ),
              ],
            ),
            const Divider(),
            const Text("Pilih Perangkat Paired:",
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            if (_pairedDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                    "Tidak ada perangkat Bluetooth yang ditemukan.\nPastikan Bluetooth nyala & sudah pairing di setting HP."),
              )
            else
              ..._pairedDevices.map((device) => ListTile(
                    // PERBAIKAN DI SINI: Menghapus operator '??' karena device.name tidak null
                    title: Text(
                        device.name.isEmpty ? "Unknown Device" : device.name),
                    subtitle: Text(device.macAdress),
                    trailing: (_selectedMac == device.macAdress && _isConnected)
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.link),
                    onTap: () => _connectToDevice(device.macAdress),
                    contentPadding: EdgeInsets.zero,
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
            const Text("Ukuran Kertas",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text("58mm"),
                    subtitle: const Text("(384 dots)"),
                    value: 384,
                    groupValue: _paperSize,
                    onChanged: (val) {
                      setState(() => _paperSize = val!);
                      _saveSetting('printer_paper_width', val);
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<int>(
                    title: const Text("80mm"),
                    subtitle: const Text("(576 dots)"),
                    value: 576,
                    groupValue: _paperSize,
                    onChanged: (val) {
                      setState(() => _paperSize = val!);
                      _saveSetting('printer_paper_width', val);
                    },
                  ),
                ),
              ],
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
            const Text("Kualitas Gambar",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),

            // Brightness Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kecerahan (Brightness)"),
                Text(_brightness.toStringAsFixed(1)),
              ],
            ),
            Slider(
              value: _brightness,
              min: 0.5,
              max: 2.5,
              divisions: 20,
              label: _brightness.toStringAsFixed(1),
              onChanged: (val) {
                setState(() => _brightness = val);
              },
              onChangeEnd: (val) => _saveSetting('printer_brightness', val),
            ),

            // Contrast Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kontras (Contrast)"),
                Text(_contrast.toStringAsFixed(1)),
              ],
            ),
            Slider(
              value: _contrast,
              min: 0.5,
              max: 2.5,
              divisions: 20,
              label: _contrast.toStringAsFixed(1),
              onChanged: (val) {
                setState(() => _contrast = val);
              },
              onChangeEnd: (val) => _saveSetting('printer_contrast', val),
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Default: Brightness 1.2, Contrast 1.5\nNaikkan kontras jika hasil pudar.",
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
