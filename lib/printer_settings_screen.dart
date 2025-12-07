import 'dart:io';
import 'dart:typed_data';
import 'dart:async'; // Untuk Future
import 'package:flutter/foundation.dart'; // Untuk compute (Isolate)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart'; // WAJIB: Import Image Picker
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img; // Import library pengolah gambar
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
  int _printerMode = 2; // Default 80mm High
  int _imageFilter = 1; // Default Dithering

  double _brightness = 1.0; // Default Normal
  double _contrast = 1.0;   // Default Normal
  bool _isLoading = false;

  // --- PREVIEW VARIABLES ---
  img.Image? _originalImage; 
  Uint8List? _previewBytes;  
  bool _isGeneratingPreview = false;
  final ImagePicker _picker = ImagePicker(); // Instance Image Picker

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkConnection(); 
    _loadSampleImage(); // Load default awal (Logo)
  }

  // --- 1. LOAD GAMBAR ---
  
  // A. Load Default dari Aset (Fallback)
  Future<void> _loadSampleImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/icon/logo/icon_launcher.png');
      final Uint8List bytes = data.buffer.asUint8List();
      _processLoadedImage(bytes);
    } catch (e) {
      debugPrint("Gagal load sample image: $e");
    }
  }

  // B. Ambil dari Galeri (FITUR BARU)
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.gallery);
      if (photo != null) {
        final Uint8List bytes = await photo.readAsBytes();
        _processLoadedImage(bytes);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mengambil gambar dari galeri"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Helper untuk memproses bytes gambar mentah menjadi objek Image
  void _processLoadedImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image != null) {
      // Resize agar preview enteng (lebar 300px cukup untuk layar HP)
      // Kita simpan _originalImage untuk diproses ulang saat slider digeser
      _originalImage = img.copyResize(image, width: 300);
      _updatePreview(); 
    }
  }

  // --- 2. UPDATE PREVIEW (Background Process) ---
  Future<void> _updatePreview() async {
    if (_originalImage == null || _isGeneratingPreview) return;

    if (mounted) setState(() => _isGeneratingPreview = true);

    try {
      // Jalankan proses berat di thread terpisah (compute) agar UI tidak macet
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

  // --- 3. LOGIKA PENGOLAHAN GAMBAR (Static Function) ---
  static Uint8List _processImage(Map<String, dynamic> params) {
    // Clone gambar agar aslinya tidak rusak
    img.Image image = img.Image.from(params['image'] as img.Image); 
    double brightness = params['brightness'];
    double contrast = params['contrast'];
    int filter = params['filter'];

    // A. Atur Brightness & Contrast (Manual Pixel Loop)
    if (brightness != 1.0 || contrast != 1.0) {
       for (var pixel in image) {
         num r = pixel.r;
         num g = pixel.g;
         num b = pixel.b;

         // Apply Brightness
         r *= brightness;
         g *= brightness;
         b *= brightness;

         // Apply Contrast
         r = ((r - 128) * contrast + 128).clamp(0, 255);
         g = ((g - 128) * contrast + 128).clamp(0, 255);
         b = ((b - 128) * contrast + 128).clamp(0, 255);

         pixel.r = r;
         pixel.g = g;
         pixel.b = b;
       }
    }

    // B. Convert ke Grayscale
    img.grayscale(image);

    // C. Simulasi Efek Thermal (1-bit Black & White)
    if (filter == 1) {
      // Dithering (Ordered Dither - Bayer 2x2)
      const List<List<int>> bayerMatrix = [
        [  1,  3 ],
        [  4,  2 ]
      ];
      
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final lum = img.getLuminance(pixel);
          
          final val = (lum / 255) * 5;
          final threshold = bayerMatrix[y % 2][x % 2];
          
          if (val < threshold) {
            image.setPixelRgb(x, y, 0, 0, 0); // Hitam
          } else {
            image.setPixelRgb(x, y, 255, 255, 255); // Putih
          }
        }
      }

    } else {
      // Thresholding (Hitam Putih Tegas)
      for (var pixel in image) {
        final lum = img.getLuminance(pixel);
        if (lum < 128) {
          pixel.r = 0; pixel.g = 0; pixel.b = 0;
        } else {
          pixel.r = 255; pixel.g = 255; pixel.b = 255;
        }
      }
    }

    return Uint8List.fromList(img.encodePng(image));
  }

  // --- LOAD & SAVE SETTINGS ---
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
      if (isLocationGranted) return true;
      
      return false;
    }
    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Izin Dibutuhkan"),
        content: const Text("Aplikasi butuh izin Bluetooth & Lokasi untuk mencari printer."),
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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Terhubung!" : "Gagal terhubung."),
          backgroundColor: success ? Colors.green : Colors.red
        )
      );
    }
  }

  Future<void> _disconnect() async {
    await _printerService.disconnect();
    setState(() => _isConnected = false);
  }

  // --- WIDGET HELPER: Custom Radio ---
  Widget _buildCustomRadio({
    required String title,
    String? subtitle,
    required int value,
    required int groupValue,
    required Function(int) onChanged,
  }) {
    final bool isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3)
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.black87
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                // 1. KONEKSI PRINTER (TETAP DI ATAS)
                _buildConnectionSection(),
                
                const SizedBox(height: 16),
                
                // 2. PREVIEW GAMBAR (BARU)
                _buildPreviewSection(), 
                
                const SizedBox(height: 16),
                
                // 3. SETTING KUALITAS (Persis di bawah Preview)
                _buildQualitySection(), 
                
                const SizedBox(height: 16),
                
                // 4. FILTER (Dithering dll)
                _buildFilterSection(),
                
                const SizedBox(height: 16),
                
                // 5. UKURAN KERTAS
                _buildPaperSettingsSection(),
                
                const SizedBox(height: 24),
                
                ElevatedButton.icon(
                  onPressed: _isConnected ? () => _printerService.testPrint() : null,
                  icon: const Icon(Icons.print),
                  label: const Text("Test Print (Kertas)"),
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

  // --- WIDGET PREVIEW GAMBAR ---
  Widget _buildPreviewSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Simulasi Hasil Cetak", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                // TOMBOL GANTI GAMBAR (BARU)
                TextButton.icon(
                  onPressed: _pickImageFromGallery, 
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text("Ganti Gambar"),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              "Gambar di bawah mensimulasikan efek Dithering/Hitam Putih pada kertas.", 
              style: TextStyle(fontSize: 11, color: Colors.grey)
            ),
            const SizedBox(height: 12),
            Container(
              height: 180, // Sedikit lebih tinggi agar jelas
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isGeneratingPreview 
                  ? const Center(child: CircularProgressIndicator())
                  : _previewBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: InteractiveViewer( // Bisa di-zoom biar detail
                            child: Image.memory(
                              _previewBytes!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                        )
                      : const Center(child: Text("Gagal memuat gambar contoh")),
            ),
          ],
        ),
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
            const Text("Koneksi Printer", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
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
            
            _buildCustomRadio(
              title: "80mm High (Default)",
              subtitle: "Kualitas Terbaik (576 dots)",
              value: 2,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val); _saveSetting('printer_mode_type', val); },
            ),

            _buildCustomRadio(
              title: "80mm Medium (384 dots)",
              subtitle: "Standard",
              value: 3,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val); _saveSetting('printer_mode_type', val); },
            ),

            _buildCustomRadio(
              title: "80mm Custom (350 dots)",
              subtitle: "Resolusi Menengah",
              value: 7,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val); _saveSetting('printer_mode_type', val); },
            ),

            _buildCustomRadio(
              title: "80mm Low (288 dots)",
              subtitle: "Resolusi Rendah - Cepat",
              value: 4,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val); _saveSetting('printer_mode_type', val); },
            ),
            
            const Divider(),
            
            _buildCustomRadio(
              title: "Kertas 58mm",
              subtitle: "Ukuran Kecil (Struk Biasa)",
              value: 1,
              groupValue: _printerMode,
              onChanged: (val) { setState(() => _printerMode = val); _saveSetting('printer_mode_type', val); },
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
              "Ganti filter untuk melihat perbedaannya di preview atas.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            
            _buildCustomRadio(
              title: "Standard (Dithering)",
              subtitle: "Bintik-bintik gradasi. Lebih lambat tapi detail.",
              value: 1,
              groupValue: _imageFilter,
              onChanged: (val) { 
                setState(() => _imageFilter = val); 
                _saveSetting('printer_image_filter', val); 
                _updatePreview(); // Trigger update preview
              },
            ),

            _buildCustomRadio(
              title: "Hitam Putih Tegas (Threshold)",
              subtitle: "Kontras tinggi, tanpa abu-abu. LEBIH CEPAT.",
              value: 2,
              groupValue: _imageFilter,
              onChanged: (val) { 
                setState(() => _imageFilter = val); 
                _saveSetting('printer_image_filter', val); 
                _updatePreview(); // Trigger update preview
              },
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
            
            // Brightness Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text("Kecerahan"), Text(_brightness.toStringAsFixed(1))],
            ),
            Slider(
              value: _brightness, min: 0.5, max: 2.5, divisions: 20,
              label: _brightness.toStringAsFixed(1),
              onChanged: (val) => setState(() => _brightness = val),
              onChangeEnd: (val) {
                _saveSetting('printer_brightness', val);
                _updatePreview(); // Trigger update preview saat slider dilepas
              },
            ),

            // Contrast Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text("Kontras"), Text(_contrast.toStringAsFixed(1))],
            ),
            Slider(
              value: _contrast, min: 0.5, max: 2.5, divisions: 20,
              label: _contrast.toStringAsFixed(1),
              onChanged: (val) => setState(() => _contrast = val),
              onChangeEnd: (val) {
                _saveSetting('printer_contrast', val);
                _updatePreview(); // Trigger update preview saat slider dilepas
              },
            ),
          ],
        ),
      ),
    );
  }
}