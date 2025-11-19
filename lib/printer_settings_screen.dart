import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:photo_box/main.dart'; // Import warna (backgroundDark, dll)
import 'package:photo_box/printing_services.dart'; // Import service yg baru diupdate
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
    _scanDevices();
    _checkSavedConnection();
  }

  // 1. Cek printer yang tersimpan
  Future<void> _checkSavedConnection() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _connectedMacAddress = prefs.getString('saved_printer_mac');
    });
  }

  // 2. Scan Bluetooth
  Future<void> _scanDevices() async {
    setState(() { _isLoading = true; });
    
    // Pastikan permission bluetooth aktif (biasanya service handle, tp safety check)
    try {
      final devices = await _printerService.getPairedPrinters();
      setState(() {
        _availableDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error scan: $e")));
    }
  }

  // 3. Connect ke Device
  Future<void> _connectToDevice(BluetoothInfo device) async {
    setState(() { _isLoading = true; });
    
    bool success = await _printerService.connectAndSave(device.macAdress); // Perhatikan spelling library 'macAdress'

    setState(() { _isLoading = false; });

    if (success) {
      setState(() {
        _connectedMacAddress = device.macAdress;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Terhubung ke ${device.name}"), backgroundColor: Colors.green)
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Gagal terhubung"), backgroundColor: Colors.red)
      );
    }
  }

  // 4. Test Print
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
          // --- STATUS SECTION ---
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.black26,
            child: Column(
              children: [
                const Icon(Icons.print, size: 60, color: Colors.white54),
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
              child: Text("PERANGKAT TERSEDIA:", style: TextStyle(color: accentGrey, fontWeight: FontWeight.bold)),
            ),
          ),

          // --- DEVICE LIST ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: primaryYellow))
              : _availableDevices.isEmpty 
                ? const Center(child: Text("Tidak ada perangkat Bluetooth ditemukan.\nPastikan Bluetooth nyala & sudah pairing di setting HP.", 
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
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
                              child: const Text("Connect"),
                            ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}