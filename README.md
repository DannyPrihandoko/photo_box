# 📸 PhotoBox - Aplikasi Photobooth Thermal Printer

**PhotoBox** adalah sistem aplikasi photobooth berbasis Flutter yang dirancang untuk perangkat Android. Aplikasi ini memungkinkan pengguna untuk mengambil foto selfie, menyusunnya menjadi photostrip, dan mencetaknya langsung menggunakan **Printer Thermal Bluetooth**.

Sistem ini terdiri dari dua aplikasi yang saling terhubung melalui jaringan lokal (Wi-Fi):
1.  **Aplikasi User (Client):** Digunakan oleh pelanggan untuk berfoto.
2.  **Aplikasi Admin (Server):** Digunakan oleh kasir/operator untuk membuat voucher dan memantau aktivitas.

---

## ✨ Fitur Utama

### 📱 Aplikasi User (PhotoBox)
* **Sistem Voucher:** Akses eksklusif menggunakan kode unik yang digenerate Admin.
* **Auto-Connect Admin:** Menggunakan *Network Service Discovery* (mDNS) untuk menemukan Admin di Wi-Fi tanpa perlu input IP manual.
* **Kamera Selfie:** Integrasi kamera depan dengan hitungan mundur otomatis.
* **Editor Photostrip:**
    * *Drag & Drop* foto ke dalam template.
    * Pilihan Layout: **1 Kotak** atau **2 Kotak**.
* **Pencetakan Canggih:**
    * Support Printer Thermal Bluetooth (58mm/80mm).
    * **Image Dithering:** Algoritma Floyd-Steinberg untuk hasil cetak tajam pada kertas struk (hitam-putih).
    * Koneksi otomatis ke printer tersimpan.
* **Galeri:** Simpan otomatis dan cetak ulang riwayat foto.

### 💻 Aplikasi Admin (Server)
* **Voucher Generator:** Membuat kode unik acak (misal: `A7X99`).
* **Local Server:** Menjalankan HTTP Server ringan untuk verifikasi kode secara real-time.
* **Keamanan:** Kode yang sudah dipakai otomatis hangus (tidak bisa dipakai 2x).
* **Laporan Harian:** Rekapitulasi jumlah voucher dibuat, terpakai, dan sisa.
* **Database Lokal:** Data tersimpan permanen di memori perangkat, aman meski aplikasi ditutup.

---

## 🛠️ Teknologi

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Library Kunci:**
    * `camera`: Akses kamera.
    * `print_bluetooth_thermal` & `esc_pos_utils_plus`: Komunikasi printer ESC/POS.
    * `nsd`: Penemuan layanan jaringan lokal (mDNS).
    * `shelf` & `shelf_router`: Web server backend di sisi Admin.
    * `image`: Pemrosesan gambar (Resize, Grayscale, Dithering).
    * `permission_handler`: Manajemen izin runtime Android 12+.
    * `shared_preferences`: Penyimpanan data lokal.

---

## ⚙️ Prasyarat Perangkat

1.  **2 Perangkat Android:**
    * Satu sebagai **User** (Tablet disarankan).
    * Satu sebagai **Admin** (HP Kasir).
    * Kedua perangkat **WAJIB** terhubung ke **Jaringan Wi-Fi yang sama** (Bisa menggunakan Router atau Hotspot Tethering dari salah satu HP).
2.  **1 Printer Thermal Bluetooth:**
    * Mendukung protokol ESC/POS.
    * Ukuran kertas 58mm atau 80mm.

---

## 🔧 Konfigurasi Izin (AndroidManifest.xml)

Pastikan file `android/app/src/main/AndroidManifest.xml` pada **Aplikasi User** memiliki izin berikut agar fitur Bluetooth dan Wi-Fi Discovery berjalan:

```xml
<manifest ...>
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />

    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
    
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" /> <application
        ...
        android:usesCleartextTraffic="true"> ...
    </application>
</manifest>
