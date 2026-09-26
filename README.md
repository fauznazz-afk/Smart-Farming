# EnerGrow

Aplikasi mobile monitoring energi untuk sistem PLTS (Pembangkit Listrik Tenaga Surya) hybrid — bagian dari proyek **FNN-XAI-IoT**, program MBKM. Aplikasi ini menampilkan data real-time dari baterai aki, listrik AC (PZEM), dan panel surya (PV), dikonsumsi langsung dari dashboard [ThingsBoard](https://thingsboard.io/) yang sudah berjalan di infrastruktur IoT lahan.

> 📄 Lihat [PRD lengkap](./PRD_PLTS_Monitoring_App.md) untuk detail requirement, scope MVP, dan roadmap.
> 🚀 Ikuti [panduan rilis GitHub](./PRD_GitHub_Release_Process.md) untuk menyiapkan APK bertanda tangan dan menerbitkan release.

---

## Fitur (MVP)

- **Login** menggunakan akun ThingsBoard (JWT, auto-redirect saat token expired)
- **Dashboard real-time** dengan navigasi Overview, PV, AC, dan Battery
- **Chart histori 24 jam** untuk Voltage, Current, dan Power pada tiap sumber energi
- **Ringkasan energi harian dan mingguan** dengan estimasi produksi PV, pemakaian AC, dan perbandingan terhadap periode sebelumnya
- **Laporan energi harian dan bulanan** dari histori time-series ThingsBoard, diperbarui otomatis setiap 5 menit dan dapat diekspor ke CSV
- **Peringatan dalam aplikasi** untuk SOC baterai rendah dan telemetry yang stale, dengan ambang yang bisa diatur
- **Auto-refresh** tiap 10 detik + pull-to-refresh manual
- UI dashboard bertab dengan Overview serta halaman PV, AC, Battery, dan CCTV
- **Dark Mode & Light Mode toggle** di menu Pengaturan dengan penyimpanan preferensi lokal
- **Indikator data stale** yang menampilkan usia telemetry terakhir
- **CCTV layar penuh** dalam orientasi landscape
- **(Roadmap)** Push notification

Versi pengembangan saat ini: **1.3.0 (build 8)**, mengikuti metadata di `pubspec.yaml`. Catatan perubahan tersedia di [CHANGELOG](./CHANGELOG.md). Release 1.3.0 belum diterbitkan.

---

## Arsitektur Singkat

```
ESP32 (sensor) → ESP-NOW → ESP32 gateway → MQTT (Mosquitto)
                                                    ↓
                                        ThingsBoard CE (Orange Pi 4 Pro)
                                                    ↓
                                    REST API (HTTPS via Cloudflare Tunnel)
                                                    ↓
                                          Flutter App (Android)
```

Aplikasi ini **tidak punya backend sendiri** — semua data, autentikasi, dan histori diambil langsung dari REST API ThingsBoard yang sudah live di:
```
https://dashboard.mbkm20262027.tech
```

---

## Struktur Project

```
lib/
 ├── main.dart                      # Entry point, cek token, biometrik, routing awal
 ├── models/
 │    └── telemetry_model.dart      # Model parsing response telemetry
 ├── services/                      # Integrasi eksternal (ThingsBoard, cuaca, alarm)
 ├── screens/
 │    ├── login_screen.dart
 │    ├── dashboard_screen.dart     # State container + komposisi 5 tab
 │    ├── dashboard/
 │    │    ├── charts/chart_data.dart   # Series, statistik, bounds, downsampling
 │    │    ├── utils/                   # Helper murni (energy, history range, warna, banner)
 │    │    └── widgets/                 # Komponen presentasi per bagian dashboard
 │    ├── energy_report_screen.dart
 │    ├── energy_report/            # Widget & util modul untuk laporan energi
 │    ├── settings_screen.dart
 │    ├── alarm_history_screen.dart
 │    └── cctv_screen.dart
 ├── theme/app_theme_controller.dart
 └── widgets/                       # Glass design system + kartu ringkasan
```

Dashboard sengaja dipisah menjadi tiga lapis: `dashboard_screen.dart` memegang
state dan orkestrasi, `dashboard/widgets/` menangani tampilan, dan
`dashboard/utils/` berisi logika murni yang bisa diuji tanpa widget.

---

## Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable)
- Android Studio (untuk Android SDK + emulator/device manager)
- VS Code dengan extension **Dart** dan **Flutter**
- Perangkat Android fisik (USB debugging aktif) atau emulator
- Akun **Customer User** ThingsBoard yang sudah di-assign ke device terkait (bukan akun sysadmin — lihat bagian [Setup ThingsBoard](#setup-thingsboard))

Cek instalasi:
```bash
flutter doctor -v
```
Pastikan semua item bertanda `[✓]` sebelum lanjut.

---

## Instalasi & Menjalankan

1. **Clone / buka project ini di VS Code**

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Cek device yang terhubung:**
   ```bash
   flutter devices
   ```

4. **Jalankan dalam mode debug:**
   ```bash
   flutter run
   ```

5. **Build APK release** (untuk install permanen ke HP):
   ```bash
   flutter build apk --release
   ```
   Hasil APK ada di:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```
   Install ke device yang terhubung langsung via:
   ```bash
   flutter install
   ```

### Instal APK Release

APK release tersedia pada GitHub Release project ini. Unduh file `app-release.apk` dari halaman Releases, lalu buka file tersebut pada perangkat Android. Jika Android meminta izin, aktifkan instalasi dari sumber ini untuk aplikasi yang digunakan membuka APK.

Untuk membangun APK sendiri:

```bash
flutter build apk --release
```

File hasil build:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Checksum SHA-256 dapat dibuat untuk memverifikasi file yang diunduh:

```bash
certutil -hashfile app-release.apk SHA256
```

---

## Konfigurasi

Device ID (UUID) dan base URL ThingsBoard di-set di `lib/services/thingsboard_api.dart`:

```dart
static const String baseUrl = 'https://dashboard.mbkm20262027.tech';

static const String deviceBattery = '9465cf90-b264-11f1-9294-d92385142e6d';
static const String deviceSensor  = '2e1b25c0-af33-11f1-8455-0717167ff6c3';
static const String devicePzem    = 'af9531a0-ac44-11f1-841c-f5914d050259';
```

Ganti sesuai Device ID dari ThingsBoard kalau ada perubahan device atau deploy ulang instance.

---

## Setup ThingsBoard

Aplikasi ini dirancang untuk login memakai **Customer User**, bukan Tenant Admin, agar akses tetap terbatas ke device yang relevan saja.

1. Login ke ThingsBoard sebagai admin → menu **Customers** → buat customer baru
2. Menu **Devices** → assign ketiga device (Battery, PZEM, Sensor) ke customer tersebut
3. Buka customer → tab **Users** → tambah user baru dengan email & password
4. Gunakan kredensial user ini untuk login di aplikasi

> ⚠️ Device ID (UUID) berbeda dengan **access token** perangkat (dipakai ESP32 untuk kirim data via MQTT). Ambil Device ID dari tab **Details** pada halaman device, bukan dari token MQTT.

---

## Known Issues

- **PZEM-017 (DC) stale data** — nilai kadang tidak update karena silent read failure di firmware ESP32; belum sepenuhnya teratasi di level hardware. Aplikasi menampilkan data apa adanya dari ThingsBoard.
- **CCTV belum aktif** — fitur ini menunggu setup `go2rtc` di sisi Orange Pi selesai.
- **Ketergantungan pada Orange Pi tunggal** — tidak ada redundansi backend; jika Orange Pi/Cloudflare Tunnel down, aplikasi tidak bisa fetch data sama sekali.

---

## Roadmap

Lihat bagian **7. Roadmap Pengembangan Lanjutan** di [PRD](./PRD_PLTS_Monitoring_App.md) untuk daftar lengkap fitur yang direncanakan setelah MVP: push notification, integrasi Google Sheets, mode offline, WebSocket real-time, dan integrasi prediksi FNN+XAI.

---

## Lisensi

Proyek internal — bagian dari tugas akhir/MBKM di Politeknik Negeri Sriwijaya. Belum ditentukan lisensi publik.
