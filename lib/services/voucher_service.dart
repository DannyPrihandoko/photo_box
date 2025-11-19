import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VoucherService {
  static const String _kAdminIpKey = 'saved_admin_ip';
  static const String _kAdminPortKey = 'saved_admin_port';

  // Simpan Konfigurasi Admin (Setting Awal)
  Future<void> saveAdminConfig(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAdminIpKey, ip);
    await prefs.setInt(_kAdminPortKey, port);
  }

  // Cek apakah Admin sudah disetting
  Future<bool> isAdminConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kAdminIpKey);
  }

  // Verifikasi Voucher (Otomatis baca IP tersimpan)
  Future<Map<String, dynamic>> verifyVoucher(String code) async {
    final prefs = await SharedPreferences.getInstance();
    final String? ip = prefs.getString(_kAdminIpKey);
    final int port = prefs.getInt(_kAdminPortKey) ?? 8080;

    if (ip == null) {
      return {'valid': false, 'message': 'Admin belum disetting! Hubungi petugas.'};
    }

    final Uri url = Uri.parse('http://$ip:$port/verify-voucher');

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"code": code}),
      ).timeout(const Duration(seconds: 5)); // Timeout biar gak nunggu lama

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'valid': false, 'message': 'Server Error: ${response.statusCode}'};
      }
    } catch (e) {
      return {'valid': false, 'message': 'Gagal koneksi ke Admin. Cek Wi-Fi.'};
    }
  }
}