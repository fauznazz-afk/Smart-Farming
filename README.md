# EnerGrow

<p align="center">
  <b>Monitoring energi PLTS hybrid untuk smart farming</b><br>
  <sub>Baterai · Listrik AC · Panel surya — langsung dari ThingsBoard, tanpa backend sendiri</sub>
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.47.5-02569A?logo=flutter&logoColor=white">
  <img alt="Android" src="https://img.shields.io/badge/Android-24%2B-3DDC84?logo=android&logoColor=white">
  <img alt="Tests" src="https://img.shields.io/badge/tests-363%20Dart%20%2B%2011%20Kotlin-4CAF50">
</p>

Aplikasi Android untuk memantau sistem **PLTS (Pembangkit Listrik Tenaga Surya) hybrid**
di lahan smart farming. Menampilkan data real-time dari baterai aki, listrik AC (PZEM),
dan panel surya — semua diambil langsung dari dashboard
[ThingsBoard](https://thingsboard.io/) yang sudah berjalan di infrastruktur IoT lahan.

> 📄 Requirement, scope, dan roadmap lengkap: [PRD](./PRD_PLTS_Monitoring_App.md)
> 🚀 Cara menyiapkan APK bertanda tangan dan menerbitkan release: [Panduan Rilis](./PRD_GitHub_Release_Process.md)

---

## ⚡ Alarm jalan di latar belakang, tanpa buka aplikasi

Ini fitur yang paling sering ditanyakan, dan sekarang benar-benar bekerja.

When the app is closed, EnerGrow still watches the greenhouse. Every minute a small
native Android check reads the battery, the AC meter and the environment sensor, and
posts a notification the moment a condition is crossed — SOC below threshold, telemetry
that stopped reporting, or a temperature/humidity/TDS limit breached.

```
02:56:35.683  check started
02:56:36.133  check finished: 1 active (1 new): environment_humidity_high

android.title = "EnerGrow: Warning alarm"
android.text  = "Kelembapan tinggi: 88.9 % (batas 80.0 %)"
```

**450 milidetik**, dengan aplikasi di background — *lima belas menit* per deteksi, bukan
setiap sepuluh detik seperti saat aplikasi kebuka.

Yang membuatnya murah adalah karangannya. Pengecekan ini **tidak menjalankan Flutter
Engine sama sekali** — murni Kotlin, `HttpURLConnection` + `NotificationCompat`, seperti
yang selalu ada di Android. Pendekatan yang lebih mudah dipahami, yaitu
`android_alarm_manager_plus`, menjalankan isolate Flutter baru di setiap tick; engine itu
tinggal di memori, jadi biayanya puluhan MB yang terus ditahan dan detik-detik startup
yang terulang selamanya.

| |isolate Flutter (lama) | Kotlin native (sekarang) |
|---|---|---|
| RAM tertahan | puluhan MB | < 10 MB |
| Startup per tick | 1–3 detik (engine) | ~0,45 detik total |
| 3 device, retry | bisa > 3 menit (sekuensial) | 450 ms (paralel, tanpa retry) |

Tiga detail yang membuatnya bisa dipercaya:

- **Satu daftar aturan, dua mesin.** Ambang yang Anda ubah di Settings dipakai dashboard
  *dan* pengecekan background. Notifikasi dan banner di app tidak mungkin berbeda
  ombak, karena keduanya membaca `lib/utils/alarm_rules.dart` yang sama.
- **Satu notifikasi per kemunculan.** SOC yang tetap rendah tidak akan mengirim
  notifikasi tiap menit. Alarm diumumkan saat *muncul*, lalu diam selama kondisi itu masih berlaku.
- **Berhenti saat Anda memakai app.** Dashboard sudah polling tiap 10 detik dan
  mengevaluasi aturan yang sama, jadi pengecekan background mundur agar ThingsBoard
  tidak dipoll dua kali.

Kalau latar belakang terasa tidak bisa diandalkan, cek `dumpsys alarm` dulu — bukan
berarti aplikasi rusak. Detail lengkap ada di [AGENTS.md](./AGENTS.md#background-alarms-are-native-kotlin-and-must-stay-that-way).

---

## Fitur

**Monitoring**

- Dashboard real-time dengan navigasi **Overview**, **Power** (PV / AC / Battery
  dalam satu tab bersegmen), **Hydroponics**, dan **Fish**
- **Tujuh chart histori** — Power (PV / AC / Battery, masing-masing tiga seri), Hydroponics
  (Temperature dua sensor pada satu sumbu, Humidity, Light, TDS), Fish (pH, Temperature, Turbidity).
  Dikelompokkan **berdasarkan satuan**, jadi hanya deret yang bisa dibandingkan yang berbagi sumbu Y
- Update real-time lewat **WebSocket ThingsBoard**, dengan polling REST sebagai cadangan
- Auto-refresh tiap 10 detik + pull-to-refresh, intervalnya bisa diatur
- Indikator usia telemetry terakhir, sehingga data basi tidak disamarakan jadi data segar

**Analisis energi**

- Ringkasan harian dan mingguan: estimasi produksi PV, pemakaian AC, dan perbandingan
  terhadap periode sebelumnya
- Laporan harian/bulanan dari histori time-series, dapat diekspor ke **CSV**
- Proyeksi runtime baterai, dengan konvensi tanda discharge BMS yang sering tidak
  konsisten antar vendor sudah ditangani

**Alarm**

- **Pengecekan latar belakang tiap menit** (lihat di atas) — native, hemat RAM
- Ambang yang bisa diatur: SOC baterai, usia telemetry, serta batas minimum/maksimum
  suhu, kelembapan, dan TDS — plus batas tank ikan (pH, suhu air, turbidity)
- **Deteksi perangkat mati** — telemetry yang diam 10 menit memberi peringatan,
  dan diam lebih lama (default 60 menit) memberi alarm kritis tersendiri, karena
  "telat" dan "mati" butuh tindakan yang berbeda
- Batas lingkungan sudah terisi secara default (suhu 15–35 °C, kelembapan
  40–85 %, TDS ≥ 800 ppm) dan setiap kartu menampilkan apakah nilainya berada
  di dalam batas
- Batas kosong berarti "tidak dipantau"; alert lingkungan hanya dievaluasi dari data
  sensor yang **masih segar**, supaya tidak ada alarm untuk kondisi yang sudah berakhir
- **Riwayat alarm** dengan acknowledge, resolve, dan reopen

**Lain-lain**

- Login **Customer User** ThingsBoard dengan token yang disimpan di keystore terenkripsi
- **Biometric gate** (sidik jari / pengenalan wajah) untuk membuka sesi
- Dua stream CCTV (go2rtc) — greenhouse di Hydroponics dan `?src=cam2` di Fish —
  dengan allowlist host, dan status koneksi yang jujur
  (standby / connecting / live / offline)
- Dark & light mode, empat pilihan aksen, dan sistem permukaan **soft-UI opaque**
  (kartu se warna halaman, kedalaman dari pasangan bayangan satu arah cahaya)
- Konfigurasi ThingsBoard tersimpan di secure storage, bukan di teks biasa

---

## Arsitektur

```
ESP32 (sensor) → ESP-NOW → ESP32 gateway → MQTT (Mosquitto)
                                                    ↓
                                        ThingsBoard CE (Orange Pi 4 Pro)
                                                    ↓
                                    REST API (HTTPS via Cloudflare Tunnel)
                                                    ↓
                                          Flutter App (Android)
                                                    ↓
                              native Kotlin (AlarmManager + receiver)
                                                    ↓
                                          Notifikasi lokal
```

Aplikasi ini **tidak punya backend sendiri**. Autentikasi, data, dan histori semuanya
langsung dari ThingsBoard yang sudah live di
`https://dashboard.mbkm20262027.tech`. Pengecekan alarm background memakai endpoint
yang sama, dengan token yang diteruskan dari Dart dan disimpan terenkripsi di
**AndroidKeyStore** — token asli tetap milik `flutter_secure_storage` dan tidak pernah
pernah ditulis di luar itu.

---

## Struktur Project

```
lib/
├── main.dart                        # Entry point, cek token, biometrik, routing awal
├── models/
│   ├── alarm_record.dart            # AlarmType, AlarmSeverity, AlarmRecord (murni)
│   └── telemetry_model.dart         # Model parsing response telemetry
├── utils/                           # Logika murni, tanpa widget & tanpa I/O
│   ├── alarm_rules.dart             # ★ Sumber tunggal: apa yang dihitung sebagai alarm
│   └── alarm_helpers.dart           # Klasifikasi id alarm, daftar device stale
├── services/
│   ├── thingsboard_api.dart         # REST client, refresh token, cache offline
│   ├── thingsboard_realtime_service.dart
│   ├── alarm_bridge.dart            # Jembatan ke modul alarm native
│   ├── alarm_notification_service.dart  # Push aturan + token ke native
│   ├── alarm_history_service.dart   # Riwayat (gabung store Dart & native)
│   ├── alarm_settings.dart          # Ambang dari SharedPreferences
│   ├── energy_forecast_service.dart
│   ├── energy_report_service.dart
│   └── connection_health_service.dart
├── screens/                         # Login, dashboard, laporan, settings, CCTV, riwayat
├── theme/app_theme_controller.dart
└── widgets/                         # Primitif permukaan (AppCard, AppTile, AppBadge) — nama file `liquid_glass.dart` sudah tidak akurat

android/app/src/
├── main/kotlin/tech/mbkm/energrow/
│   ├── MainActivity.kt
│   └── alarm/                       # ★ Modul alarm native
│       ├── AlarmRule.kt             # Kontrak aturan yang dikirim Dart
│       ├── AlarmEvaluator.kt        # Interpreter — padanan evaluateAlarmRules
│       ├── AlarmMessageFormat.kt    # Format pesan — padanan formatAlarmMessage
│       ├── AlarmCheckRunner.kt      # Orkestrasi satu siklus pengecekan
│       ├── AlarmCheckReceiver.kt    # BroadcastReceiver + goAsync
│       ├── AlarmScheduler.kt        # AlarmManager (cadence + anti-Doze)
│       ├── AlarmNotifier.kt         # Channel + notification
│       ├── AlarmTokenStore.kt       # AES-GCM di AndroidKeyStore
│       ├── ThingsBoardClient.kt     # HTTP minimal
│       ├── AlarmStateStore.kt       # Riwayat & state alarm native
│       ├── AlarmBridgePlugin.kt     # MethodChannel
│       └── AlarmDebugReceiver.kt    # Trigger manual, build debug saja
├── main/AndroidManifest.xml
├── debug/AndroidManifest.xml        # Trigger debug, TIDAK ada di release
└── test/
    ├── kotlin/.../AlarmParityTest.kt
    └── resources/alarm_parity_vectors.json   # ★ Fixture bersama dengan Dart
```

Dashboard sengaja dipisah tiga lapis: `dashboard_screen.dart` memegang state dan
orkestrasi, `dashboard/widgets/` menangani tampilan, dan `dashboard/utils/` berisi
logika murni yang bisa diuji tanpa widget.

---

## Prasyarat

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (channel stable)
- Android Studio (Android SDK + device manager)
- VS Code dengan extension **Dart** dan **Flutter**
- Perangkat Android fisik atau emulator
- Akun **Customer User** ThingsBoard yang sudah di-assign ke device terkait
  (bukan sysadmin — lihat [Setup ThingsBoard](#setup-thingsboard))

```bash
flutter doctor -v   # pastikan semua [✓]
```

---

## Menjalankan

```bash
flutter pub get
flutter devices
flutter run                          # mode debug
flutter build apk --release          # APK untuk dipasang permanen
flutter install                      # pasang ke device yang terhubung
```

Hasil build: `build/app/outputs/flutter-apk/app-release.apk`

> ℹ️ `applicationId` adalah `tech.mbkm.energrow`. Android menganggapnya aplikasi berbeda
> dari versi `com.example.*` yang lama, jadi versi lama harus di-uninstall lebih dulu —
> token login dan preferensi tidak ikut terbawa.

### Menguji alarm background

Pengecekan normal mengikuti jadwal. Untuk memicunya langsung, pakai build **debug**:

```bash
adb shell am broadcast -a tech.mbkm.energrow.action.DEBUG_CHECK_ALARMS \
  -n tech.mbkm.energrow/tech.mbkm.energrow.alarm.AlarmDebugReceiver

# conditions yang sedang menyala diumumkan ulang
adb shell am broadcast -a tech.mbkm.energrow.action.DEBUG_RESET_ALARMS \
  -n tech.mbkm.energrow/tech.mbkm.energrow.alarm.AlarmDebugReceiver
```

Receiver ini hanya dideklarasikan di `src/debug/AndroidManifest.xml`, jadi **tidak ada
di APK release** dan tidak bisa dijangkau aplikasi lain. Build debug juga tidak bisa
dipasang di atas build release karena signing key-nya berbeda.

---

## Setup ThingsBoard

Aplikasi dirancang untuk login memakai **Customer User**, bukan Tenant Admin, agar akses
tetap terbatas ke device yang relevan.

1. Login sebagai admin → **Customers** → buat customer baru
2. **Devices** → assign ketiga device (Battery, PZEM, Sensor) ke customer tersebut
3. Buka customer → **Users** → tambah user dengan email & password
4. Gunakan kredensial ini untuk login di aplikasi

> ⚠️ Device ID (UUID) berbeda dengan **access token** perangkat (dipakai ESP32 untuk kirim
> data via MQTT). Ambil Device ID dari tab **Details** halaman device.

Konfigurasi ThingsBoard ada di `lib/services/thingsboard_api.dart`:

```dart
static const String baseUrl = 'https://dashboard.mbkm20262027.tech';
static const String deviceBattery = '9465cf90-b264-11f1-9294-d92385142e6d';
static const String deviceSensor  = '2e1b25c0-af33-11f1-8455-0717167ff6c3';
static const String devicePzem    = 'af9531a0-ac44-11f1-841c-f5914d050259';
```

---

## Verifikasi di Perangkat

Semua dicek di **Xiaomi 24090RA29G (Android 16, API 36)**. Rincian per-area di
`progress.md` §7 dan §10.5.

- [x] ThingsBoard REST + WebSocket real-time, indikator "Live" hijau
- [x] Login Customer User, display name dari server tampil
- [x] Tab PV / AC / Battery dengan chart 3 seri
- [x] Chart Hydroponics (Temperature dua sensor, Humidity, Light, TDS) dan Fish (pH, Temperature, Turbidity)
- [x] Energy analytics, termasuk proyeksi runtime baterai
- [x] Pengaturan Environment alerts (field min/max) dan Appearance (ganti accent)
- [x] Biometric gate (sidik jari)
- [x] go2rtc CCTV live, video decode berjalan
- [x] **Alarm background**: notifikasi muncul saat app tertutup, 450 ms, tanpa duplikat
- [x] Alarm dijalankan ulang setelah reboot (`BOOT_COMPLETED`)
- [ ] Halaman Hydroponics dan Fish — lolos test, **belum pernah dibuka di perangkat**

OpenWeatherMap dihapus dari aplikasi pada 1.6.0 (termasuk izin lokasi dan API
key-nya); baris verifikasinya ikut ditarik.

Release build 1.6.0 (build 12) terbit 28 September 2026; fingerprint signing
terverifikasi terhadap `PRD_GitHub_Release_Process.md` §3. Cold launch terakhir
diukur pada 1.4.0: 1038 ms.

---

## Known Issues

- **PZEM-017 (DC) stale data** — nilai kadang tidak update karena silent read failure di
  firmware ESP32; belum teratasi di level hardware. Aplikasi menampilkan data apa adanya.
- **Ketergantungan pada Orange Pi tunggal** — tidak ada redundansi backend. Jika Orange
  Pi atau Cloudflare Tunnel down, tidak ada data sama sekali. Pengecekan background
  diam-diam dilewati dalam keadaan ini, bukan melaporkan data basi.
- **Alarm background bisa ditunda OEM** — `AlarmManager` yang inexact bisa ditunda Doze
  atau dibuang vendor power manager. Dua trigger dipakai untuk mengurangi risiko ini,
  dan secara nonaktif battery optimisation untuk EnerGrow di pengaturan Xiaomi.
- **Video CCTV membebani baterai** — WebView decoding berjalan di perangkat sementara
  dashboard tetap polling. Aliran ini sudah diisolasi di balik `RepaintBoundary` dan
  tidak melakukan rebuild, tapi tetap boros; tidak ada pengaturan untuk 이를.
- **Sumbu Y dibulatkan** — label sumbu memakai angka bersih (1 / 2 / 2,5 / 5), jadi nilai
  ekstrem bisa membuat label berbeda dari angka yang tercatat.

---

## Roadmap

Lihat bagian **7. Roadmap Pengembangan Lanjutan** di
[PRD](./PRD_PLTS_Monitoring_App.md): push notification dari server, integrasi Google
Sheets, mode offline, dan integrasi prediksi FNN+XAI.

---

## Lisensi

Proyek internal — bagian dari tugas akhir/MBKM di Politeknik Negeri Sriwijaya.
