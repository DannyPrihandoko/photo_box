import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_box/main.dart'; // Mengambil warna tema

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  List<BluetoothInfo> _devices = [];
  String _savedMacAddress = '';
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _scanDevices();
  }

  // Load printer yang tersimpan di memori
  Future<void> _loadSavedPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedMacAddress = prefs.getString('selected_printer_mac') ?? '';
    });
  }

  // Scan perangkat bluetooth yang sudah dipairing
  Future<void> _scanDevices() async {
    setState(() => _isLoading = true);
    try {
      final List<BluetoothInfo> result =
          await PrintBluetoothThermal.pairedBluetooths;
      setState(() {
        _devices = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Gagal memindai: $e';
        _isLoading = false;
      });
    }
  }

  // Simpan MAC Address printer yang dipilih
  Future<void> _selectPrinter(BluetoothInfo device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_mac', device.macAdress);
    await prefs.setString('selected_printer_name', device.name);

    setState(() {
      _savedMacAddress = device.macAdress;
    });

    // Coba koneksi langsung untuk memastikan
    final bool connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: device.macAdress);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(connected
            ? 'Terhubung ke ${device.name}'
            : 'Gagal menghubungkan ke ${device.name}'),
        backgroundColor: connected ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        title: const Text('Pilih Printer Thermal'),
        backgroundColor: backgroundDark,
        foregroundColor: textDark,
      ),
      body: Column(
        children: [
          if (_statusMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_statusMessage,
                  style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryYellow))
                : _devices.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada perangkat Bluetooth yang terpasang.\nPastikan Bluetooth menyala dan printer sudah dipairing di pengaturan HP.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: accentGrey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final isSelected =
                              device.macAdress == _savedMacAddress;

                          return Card(
                            color: isSelected
                                ? primaryYellow.withAlpha(50)
                                : backgroundLight,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              side: isSelected
                                  ? const BorderSide(
                                      color: primaryYellow, width: 2)
                                  : BorderSide.none,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.print,
                                color: isSelected ? primaryYellow : accentGrey,
                              ),
                              title: Text(
                                device.name,
                                style: const TextStyle(
                                    color: textDark,
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                device.macAdress,
                                style: const TextStyle(color: accentGrey),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: primaryYellow)
                                  : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: backgroundDark,
                                        foregroundColor: primaryYellow,
                                      ),
                                      onPressed: () => _selectPrinter(device),
                                      child: const Text("Pilih"),
                                    ),
                              onTap: () => _selectPrinter(device),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Perangkat"),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundLight,
                foregroundColor: textDark,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          )
        ],
      ),
    );
  }
}
