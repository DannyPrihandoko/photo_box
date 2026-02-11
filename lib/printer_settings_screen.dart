import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'printing_services.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterServices _printerService = PrinterServices();

  // State Variables Thermal
  bool _isConnected = false;
  List<BluetoothInfo> _pairedDevices = [];
  String? _selectedMac;

  // Settings Variables
  int _printerMode = 2;
  int _imageFilter = 1;
  double _brightness = 1.0;
  double _contrast = 1.0;
  bool _isLoading = false;

  // Preview Variables
  img.Image? _originalImage;
  Uint8List? _previewBytes;
  bool _isGeneratingPreview = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnection();
    _loadSampleImage();
  }

  // --- IMAGE LOADING & PROCESSING ---

  Future<void> _loadSampleImage() async {
    try {
      final ByteData data =
          await rootBundle.load('assets/icon/logo/icon_launcher.png');
      final Uint8List bytes = data.buffer.asUint8List();
      _processLoadedImage(bytes);
    } catch (e) {
      debugPrint("Gagal load sample image: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        final Uint8List bytes = await photo.readAsBytes();
        _processLoadedImage(bytes);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _processLoadedImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image != null) {
      _originalImage = img.copyResize(image, width: 300);
      _updatePreview();
    }
  }

  Future<void> _updatePreview() async {
    if (_originalImage == null || _isGeneratingPreview) return;
    if (mounted) setState(() => _isGeneratingPreview = true);

    try {
      final resultBytes = await compute(_processImage, {
        'image': _originalImage!,
        'brightness': _brightness,
        'contrast': _contrast,
        'filter': _imageFilter,
      });

      if (mounted) {
        setState(() {
          _previewBytes = resultBytes;
          _isGeneratingPreview = false;
        });
      }
    } catch (e) {
      debugPrint("Error processing preview: $e");
      if (mounted) setState(() => _isGeneratingPreview = false);
    }
  }

  static Uint8List _processImage(Map<String, dynamic> params) {
    img.Image image = img.Image.from(params['image'] as img.Image);
    double brightness = params['brightness'];
    double contrast = params['contrast'];
    int filter = params['filter'];

    // Brightness & Contrast
    if (brightness != 1.0 || contrast != 1.0) {
      for (var pixel in image) {
        num r = pixel.r * brightness;
        num g = pixel.g * brightness;
        num b = pixel.b * brightness;

        r = ((r - 128) * contrast + 128).clamp(0, 255);
        g = ((g - 128) * contrast + 128).clamp(0, 255);
        b = ((b - 128) * contrast + 128).clamp(0, 255);

        pixel.r = r;
        pixel.g = g;
        pixel.b = b;
      }
    }

    // Grayscale
    img.grayscale(image);

    // Dithering vs Threshold
    if (filter == 1) {
      const List<List<int>> bayerMatrix = [
        [1, 3],
        [4, 2]
      ];
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final lum = img.getLuminance(pixel);
          final val = (lum / 255) * 5;
          final threshold = bayerMatrix[y % 2][x % 2];
          image.setPixelRgb(x, y, val < threshold ? 0 : 255,
              val < threshold ? 0 : 255, val < threshold ? 0 : 255);
        }
      }
    } else {
      for (var pixel in image) {
        final lum = img.getLuminance(pixel);
        final val = lum < 128 ? 0 : 255;
        pixel.r = pixel.g = pixel.b = val;
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  // --- SETTINGS ---
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _printerMode = prefs.getInt('printer_mode_type') ?? 2;
      _imageFilter = prefs.getInt('printer_image_filter') ?? 1;
      _brightness = prefs.getDouble('printer_brightness') ?? 1.0;
      _contrast = prefs.getDouble('printer_contrast') ?? 1.0;
      _selectedMac = prefs.getString('selected_printer_mac');
    });
    if (_originalImage != null) _updatePreview();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is int) await prefs.setInt(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is String) await prefs.setString(key, value);
  }

  // --- BLUETOOTH & PERMISSION ---
  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      return (statuses[Permission.bluetoothConnect] ==
                  PermissionStatus.granted &&
              statuses[Permission.bluetoothScan] == PermissionStatus.granted) ||
          statuses[Permission.location] == PermissionStatus.granted;
    }
    return true;
  }

  Future<void> _checkConnection() async {
    bool status = await _printerService.isConnected;
    setState(() => _isConnected = status);
  }

  Future<void> _getPairedDevices() async {
    setState(() => _isLoading = true);
    if (!await _checkAndRequestPermissions()) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final devices = await _printerService.getPairedPrinters();
      setState(() => _pairedDevices = devices);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectToDevice(String mac) async {
    setState(() => _isLoading = true);
    bool success = await _printerService.connectAndSave(mac);
    setState(() {
      _isConnected = success;
      _selectedMac = mac;
      _isLoading = false;
    });
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    setState(() => _isConnected = false);
  }

  // ==========================================
  // FITUR EPSON (FLOW MEMILIH MODE)
  // ==========================================
  void _showEpsonPrintOptionDialog() {
    if (_originalImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pilih gambar terlebih dahulu!")));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Pilih Mode Cetak (Epson)",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.blue, size: 40),
                title: const Text("Cetak Foto Normal"),
                subtitle: const Text("Full page / Fit to paper."),
                onTap: () {
                  Navigator.pop(context);
                  _executePrintEpson(isStruk: false);
                },
              ),
              const Divider(),
              ListTile(
                leading:
                    const Icon(Icons.receipt, color: Colors.orange, size: 40),
                title: const Text("Cetak Struk Foto"),
                subtitle: const Text("Layout struk dengan tanggal."),
                onTap: () {
                  Navigator.pop(context);
                  _executePrintEpson(isStruk: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executePrintEpson({required bool isStruk}) async {
    try {
      setState(() => _isLoading = true);
      // Encode gambar asli (warna) ke PNG
      final pngBytes = img.encodePng(_originalImage!);
      // Kirim ke service
      await _printerService.printBytesToEpson(Uint8List.fromList(pngBytes),
          isStrukMode: isStruk);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- WIDGET HELPER ---
  Widget _buildCustomRadio(
      {required String title,
      String? subtitle,
      required int value,
      required int groupValue,
      required Function(int) onChanged}) {
    final bool isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                  if (subtitle != null)
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan Printer")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // BAGIAN 1: EPSON
                const Text("1. Printer Epson (USB)",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue)),
                const SizedBox(height: 8),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text("Sambungkan Epson via USB OTG."),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _showEpsonPrintOptionDialog,
                            icon: const Icon(Icons.print_outlined),
                            label: const Text("Mulai Mencetak (Pilih Mode)"),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(thickness: 2),
                const SizedBox(height: 10),

                // BAGIAN 2: THERMAL
                const Text("2. Printer Struk (Thermal)",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange)),
                const SizedBox(height: 8),
                _buildConnectionSection(),
                const SizedBox(height: 16),
                _buildPreviewSection(),
                const SizedBox(height: 16),
                _buildQualitySection(),
                const SizedBox(height: 16),
                _buildFilterSection(),
                const SizedBox(height: 16),
                _buildPaperSettingsSection(),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  onPressed: _isConnected
                      ? () => _printerService.testPrintThermal()
                      : null,
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("Test Print Struk (Thermal)"),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white),
                ),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Preview Gambar",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                    onPressed: _pickImageFromGallery,
                    child: const Text("Ganti Gambar")),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 180,
              width: double.infinity,
              color: Colors.grey[200],
              child: _previewBytes != null
                  ? Image.memory(_previewBytes!,
                      fit: BoxFit.contain, gaplessPlayback: true)
                  : const Center(child: Text("Belum ada gambar")),
            ),
            const Text(
                "Preview di atas adalah hasil Dithering (Thermal). Untuk Epson, gambar dicetak warna.",
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Icon(Icons.bluetooth,
                  color: _isConnected ? Colors.green : Colors.grey),
              const SizedBox(width: 10),
              Text(_isConnected ? "TERHUBUNG" : "TERPUTUS",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isConnected ? Colors.green : Colors.red)),
              const Spacer(),
              if (_isConnected)
                TextButton(onPressed: _disconnect, child: const Text("Putus"))
              else
                TextButton(
                    onPressed: _getPairedDevices, child: const Text("Scan")),
            ]),
            if (_pairedDevices.isNotEmpty && !_isConnected)
              ..._pairedDevices.map((d) => ListTile(
                    title: Text(d.name),
                    subtitle: Text(d.macAdress),
                    onTap: () => _connectToDevice(d.macAdress),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperSettingsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ukuran Kertas (Thermal)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            _buildCustomRadio(
                title: "80mm High",
                value: 2,
                groupValue: _printerMode,
                onChanged: (v) {
                  setState(() => _printerMode = v);
                  _saveSetting('printer_mode_type', v);
                }),
            _buildCustomRadio(
                title: "58mm",
                value: 1,
                groupValue: _printerMode,
                onChanged: (v) {
                  setState(() => _printerMode = v);
                  _saveSetting('printer_mode_type', v);
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Filter (Thermal)",
                style: TextStyle(fontWeight: FontWeight.bold)),
            _buildCustomRadio(
                title: "Standard (Dithering)",
                value: 1,
                groupValue: _imageFilter,
                onChanged: (v) {
                  setState(() => _imageFilter = v);
                  _saveSetting('printer_image_filter', v);
                  _updatePreview();
                }),
            _buildCustomRadio(
                title: "Hitam Putih (Threshold)",
                value: 2,
                groupValue: _imageFilter,
                onChanged: (v) {
                  setState(() => _imageFilter = v);
                  _saveSetting('printer_image_filter', v);
                  _updatePreview();
                }),
          ],
        ),
      ),
    );
  }

  Widget _buildQualitySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              const Text("Brightness"),
              const Spacer(),
              Text(_brightness.toStringAsFixed(1))
            ]),
            Slider(
                value: _brightness,
                min: 0.5,
                max: 2.5,
                onChanged: (v) => setState(() => _brightness = v),
                onChangeEnd: (v) {
                  _saveSetting('printer_brightness', v);
                  _updatePreview();
                }),
            Row(children: [
              const Text("Contrast"),
              const Spacer(),
              Text(_contrast.toStringAsFixed(1))
            ]),
            Slider(
                value: _contrast,
                min: 0.5,
                max: 2.5,
                onChanged: (v) => setState(() => _contrast = v),
                onChangeEnd: (v) {
                  _saveSetting('printer_contrast', v);
                  _updatePreview();
                }),
          ],
        ),
      ),
    );
  }
}
