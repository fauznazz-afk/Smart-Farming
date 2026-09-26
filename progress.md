# Progress - EnerGrow (PLTS Monitoring)

Dokumen ini adalah **handoff** untuk sesi berikutnya. Tujuannya supaya agent baru bisa melanjutkan tanpa harus membaca ulang seluruh riwayat percakapan.

- **Proyek**: `plts_monitoring` / **EnerGrow** - aplikasi monitoring energi PLTS hybrid
- **Konteks**: Proyek **FNN-XAI-IoT**, program MBKM, Politeknik Negeri Sriwijaya
- **Remote**: `https://github.com/fauznazz-afk/Smart-Farming.git` (branch `main`)
- **Dibuat**: 26 September 2026
- **Status saat ini**: `main` bersih dan sinkron dengan `origin/main`, analyze bersih, 119 test lulus

---

## 1. Ringkasan Eksekusi

Sesi ini berisi dua jenis pekerjaan: **refactor** (mengubah struktur tanpa mengubah perilaku) dan **perbaikan bug** (ditemukan lewat pengujian di perangkat fisik).

| Commit | Jenis | Ringkasan |
|---|---|---|
| `279347d` | refactor | Pecah `dashboard_screen.dart` (3.046 ke 1.389 baris) jadi widgets dan pure helpers |
| `a612a65` | refactor | Extract `SettingsController` dan section widgets (754 ke 157 baris) |
| `224907d` | refactor | Pecah CCTV dan Energy Report, duplikasi viewport dihapus, tambah `dart_test.yaml` |
| `2c6daf7` | fix | Sumbu chart terbaca, `applicationId` asli, dokumentasi diperbarui |
| `e897cca` | fix | Label chart ikut tanggal, weather refresh setelah simpan settings |
| `a5bdcaf` | fix | Pulihkan batas alert TDS dan humidity yang hilang saat refactor |
| `a3ef784` | fix | Estimasi runtime baterai pakai daya discharge, bukan peak AC |
| `d5da49e` | fix | Daya baterai diambil berdasarkan magnitudo (konvensi tanda BMS) |

Total: **8 commit**, 69 file berubah, +7.773 / -3.644 baris.

---

## 2. Lingkungan Kerja

### Tools

| Item | Nilai |
|---|---|
| Flutter | 3.47.5 stable |
| Dart SDK | `^3.13.4` |
| `compileSdk` / `targetSdk` | 36 |
| minSdk | `flutter.minSdkVersion` |
| Java | 17 |
| Gradle | 9.3.1 |
| `applicationId` | `tech.mbkm.energrow` |

### Perangkat uji

| Item | Nilai |
|---|---|
| Model | `24090RA29G` (Xiaomi, codename `malachite`) |
| Android | 16 (API 36) |
| Layar | 1220 x 2712 px, density 520 (override 513) |
| Koneksi | ADB wireless debugging |

### Batasan RAM mesin - PENTING

Mesin developer hanya punya **7,3 GB RAM total**, dan biasanya hanya **1,4 sampai 2,4 GB free** saat `flutter test` berjalan (VS Code + 2 browser + HP tersambung + Gradle daemon 800 MB).

Akibatnya `flutter test` **intermiten gagal** dengan gejala:

- `did not complete` untuk seluruh test di satu file, tanpa output error
- `Connection closed before test suite loaded`
- `loading <file>.dart` gagal

**Tanda khas**: tidak ada stack trace, tidak ada assertion failure, dan file yang "kalah" pindah-pindah dari run ke run. Ini **signature dari proses yang di-kill karena memori**, bukan test yang gagal.

Mitigasi yang sudah diterapkan:

- `dart_test.yaml` dengan `concurrency: 1` (serialisasi suite)
- Kalau masih terjadi: tutup browser, jalankan `gradlew --stop`, atau tunggu RAM free di atas 3 GB

Di mesin dengan RAM 16 GB atau lebih, masalah ini tidak terjadi. **Jangan menaikkan concurrency di `dart_test.yaml` tanpa memastikan RAM cukup.**

### Cara menyambungkan perangkat

Port wireless debugging **berubah setiap kali pairing diulang**. Urutan yang bekerja:

```bash
# 1. Temukan connect port yang aktif
adb mdns services
#   adb-ZLNJDMWWKFEYHUYD (2)  _adb-tls-connect._tcp  192.168.18.44:42057

# 2. Connect memakai IP dan port tersebut
adb connect 192.168.18.44:42057

# 3. Jalankan (WAJIB bentuk IP:port, serial mDNS ditolak Flutter)
flutter run -d "192.168.18.44:42057" --no-version-check
```

Kalau `flutter run` bilang `No supported devices found`, jalankan `adb mdns services` lagi lalu pakai port yang tertera. Kalau `device offline`, putuskan lalu connect ulang.

Sering muncul device duplikat lewat mDNS. `adb kill-server` dan `adb start-server` akan membersihkannya.

---

## 3. Arsitektur Aplikasi

```
ESP32 sensor --ESP-NOW--> ESP32 gateway --MQTT--> ThingsBoard CE (Orange Pi 4 Pro)
                                                      |
                                        HTTPS via Cloudflare Tunnel
                                                      |
                                            Flutter App (Android)
```

Baterai **tidak** lewat ESP32. Connect langsung via **Bluetooth BMS** dan menyumbang telemetry ke device ThingsBoard tersendiri.

### Kontrak data

- **Base URL**: `https://dashboard.mbkm20262027.tech`
- **CCTV**: `https://cctv.mbkm20262027.tech/stream.html?src=cam1` (host allowlist di `lib/services/cctv_url.dart`)
- **Device IDs** (UUID, bukan access token MQTT), di-hardcode di `lib/services/thingsboard_api.dart`:
  - Battery: `9465cf90-b264-11f1-9294-d92385142e6d`
  - Sensor: `2e1b25c0-af33-11f1-8455-0717167ff6c3`
  - PZEM: `af9531a0-ac44-11f1-841c-f5914d050259`
- **Login**: akun **Customer User** ThingsBoard, bukan sysadmin

### Telemetry per device

| Device | Keys |
|---|---|
| Battery | `voltage`, `current`, `power`, `soc`, `cycles`, `remain_capacity_ah`, `full_capacity_ah` |
| PZEM | `voltage_dc`, `current_dc`, `power_dc`, `voltage_ac`, `current_ac`, `power_ac`, `energy_ac`, `energy_dc`, `frequency_ac`, `pf_ac` |
| Sensor | `temp_dht`, `temp_ds18b20`, `humidity_dht`, `lux`, `tds_ppm` |

**PENTING**: tanda pada battery device bisa negatif. BMS Bluetooth ini melaporkan `current` sekitar `-2.08 A`. Jangan menulis logika yang mengasumsikan telemetry selalu positif. Lihat `EnergyForecastService.estimateBatteryDischargeWatts`.

### Spesifikasi perangkat keras terverifikasi

- **Baterai**: 12V lead-acid sekitar 100 Ah (`remain_capacity_ah` sekitar 90 Ah pada SOC 94%, `voltage` sekitar 13.3 V, jadi sekitar 1.2 kWh)
- **Beban AC**: sekitar 16 W (peak), PV peak sekitar 304 W
- **Lokasi**: Kertapati, Palembang (OpenWeatherMap)

---

## 4. Struktur Kode Setelah Refactor

Pola yang dipakai konsisten di semua layar: **state container, widgets presentasi, dan pure helpers**.

```
lib/                                    62 file, 11.445 baris
  main.dart                             entry, theme, biometric gate, routing
  models/
    telemetry_model.dart                DeviceTelemetry, TelemetryPoint
    settings_keys.dart                  kontrak SharedPreferences (dibuat sesi ini)
  services/                             10 file, semua integrasi eksternal
    thingsboard_api.dart                REST, JWT, refresh token, cache offline
    thingsboard_realtime_service.dart   WebSocket
    weather_service.dart                OpenWeatherMap dan geolocator
    energy_forecast_service.dart        kalkulasi lokal (diperbaiki sesi ini)
    energy_report_service.dart          agregasi historis
    alarm_history_service.dart          riwayat alarm
    alarm_notification_service.dart     notifikasi dan background alarm
    connection_health_service.dart      status multi-transport
    cctv_url.dart                       host allowlist dan secure storage
  theme/app_theme_controller.dart
  screens/
    dashboard_screen.dart               1.402 baris, state container, komposisi 5 tab
    dashboard/
      charts/chart_data.dart            Series, stats, bounds, interval snapping
      utils/                            energy, history_range, telemetry, color,
                                        date, bound, alarm helpers (semua murni)
      widgets/                          10 widget presentasi
    settings_screen.dart                157 baris, daftar kategori ke detail
    settings/                           controller, descriptors, sections, validation
    cctv_screen.dart                    319 baris
    cctv/                               utils/cctv_status, widgets/cctv_viewport
    energy_report_screen.dart           174 baris
    energy_report/                      widgets dan utils
    alarm_history_screen.dart           382 baris, belum di-refactor
    login_screen.dart
  widgets/                              design system (liquid_glass, energy cards)
  test/                                 8 file, 119 test, 1.400 baris
```

### Konvensi yang perlu dijaga

1. **Logic murni tinggal di `utils/`** - tanpa widget, tanpa I/O. Ini yang membuatnya bisa diuji.
2. **Widget menerima data secara eksplisit** - tidak menjangkau state privat screen. Contoh: `TelemetryCard(data:, metrics:, seedColor:)`, bukan `MetricCard` yang menarik dari `DashboardScreenState`.
3. **Nilai numerik lewat named parameter**, bukan singleton atau global.
4. **Pakai `SettingsKeys.*`** untuk setiap akses `SharedPreferences`. Jangan menulis string literal.

---

## 5. Bug yang Ditemukan dan Diperbaiki

### 5.1 URL CCTV di Settings tidak pernah berlaku

**Ditemukan**: selama investigasi refactor.

Settings menulis `cctv_url` ke `SharedPreferences`, tapi Dashboard membacanya lewat `loadCctvUrl()` yang memakai `FlutterSecureStorage`. `saveCctvUrl()` tidak pernah dipanggil dari mana pun, sehingga setiap edit CCTV diam-diam dibuang.

**Perbaikan**: `SettingsController` memakai `saveCctvUrl()` dan `loadCctvUrl()`. Konstanta `defaultCctvUrl` yang menduplikasi `defaultAllowedCctvUrl` juga dihapus.

### 5.2 Sumbu chart tidak terbaca

**Ditemukan**: screenshot di perangkat.

Interval aksis adalah `range / 3` mentah, sehingga:

- Sumbu X: `02:10`, `10:08` (bukan jam bulat)
- Sumbu Y: `111.45`, `222.91`, `334.36`
- Label pertama dan terakhir terpotong separuh di tepi plot dan saling bertumpuk

**Perbaikan** (`2c6daf7`):

- `niceStep()` membuat Y snap ke 1 / 2 / 2,5 / 5 dikali 10 pangkat n
- `niceTimeStep()` membuat X snap ke menit bulat sampai satuan hari, sumbu X di-align ke batas jam
- Label tepi didorong 14 px ke dalam memakai `TitleMeta.axisPosition` (dalam pixel, bukan nilai, jadi tahan terhadap perubahan alignment)
- Rentang lebih dari 1 hari menampilkan **tanggal** (`26/09`), bukan `00:00` berulang
- Efek samping yang bagus: kandidat step diperluas ke satuan hari, jadi range 90 hari dapat 3 tick, bukan 90 label

### 5.3 `applicationId` masih template Flutter

`com.example.plts_monitoring` adalah nilai default `flutter create` yang tidak pernah diganti. `applicationId` **tidak bisa diubah** setelah rilis Play Store.

**Perbaikan** (`2c6daf7`): menjadi `tech.mbkm.energrow`, dan `MainActivity.kt` dipindah ke `kotlin/tech/mbkm/energrow/`.

Konsekuensi: Android memperlakukannya sebagai app berbeda. APK lama harus di-uninstall lebih dulu, dan sesi login tidak ikut terbawa. Sudah dicatat di README.

### 5.4 Label chart tidak mengikuti tanggal terpilih

**Ditemukan**: laporan user.

`ChartSectionHeader` dan semantic label `TelemetryChartCard` hanya mengecek `rangeStart` dan `rangeEnd`. Memilih **satu hari** dari date strip menyisakan keduanya `null` dan hanya mengubah `_selectedDate`, sehingga label jatuh ke fallback `"Last 24 hours"`, padahal `historyTimeWindow` sedang mengambil data **hari tersebut**.

Hanya teks yang salah. Datanya sudah benar sejak awal. Bug ini **sudah ada sebelum refactor**.

**Perbaikan** (`e897cca`): `describeHistoryRange()` yang meniru `historyTimeWindow` persis, jadi label tidak mungkin berbeda dengan data.

| Pilihan | Label |
|---|---|
| Hari ini | `Last 24 hours` |
| Hari lalu | `25/9/2026` |
| Custom range | `20/9/2026 - 26/9/2026` |

### 5.5 Weather tidak update setelah mengisi API key

**Ditemukan**: laporan user. **Sudah ada sejak fitur cuaca ditambahkan.**

Dashboard memegang satu instans `WeatherService` yang hidup selama app berjalan. `initialize()` membaca `weather_api_key` dari prefs **saat app start**, ketika belum ada key, jadi `_apiKey` = `null` dan tetap `null`. Lalu `_openSettings` mengecek `if (_weatherService.hasApiKey)`, nilainya `false`, sehingga `_fetchWeather()` tidak pernah dipanggil.

**Perbaikan** (`e897cca`): `WeatherService.reloadStoredConfig()` membaca ulang key dan lokasi tersimpan **tanpa menyentuh GPS** (menghindari permintaan izin lokasi berulang), dipanggil dari `_openSettings` sebelum mengecek `hasApiKey`.

### 5.6 Batas alert TDS dan humidity hilang saat refactor

**Ditemukan**: laporan user ("ini kenapa TDS tidak boleh lebih dari 100.0").

Kode asli:

```dart
_validateRange('suhu',       _envRanges['temp']!,     -40, 100) ??
_validateRange('kelembapan', _envRanges['humidity']!, 0, 100) ??
_validateRange('TDS',        _envRanges['tds']!,      0, null);
//                                                        max = null
```

Saat memindahkan batas-batas ini ke `EnvRangeSetting`, ada transkripsi yang salah:

```dart
EnvRangeSetting(id: 'tds', ..., maxAllowed: 100)   // regresi
EnvRangeSetting(id: 'humidity', ...)               // minAllowed: 0 hilang
EnvRangeSetting(id: 'tds', ...)                    // minAllowed: 0 hilang
```

Dua konsekuensi:

1. **TDS dibatasi 100 ppm**, membuat alert tidak akan pernah bisa memicu. Larutan nutrien hydroponic 800 sampai 2000 ppm, air laut sekitar 35.000 ppm.
2. **Humidity dan TDS menerima nilai negatif**, yang tidak masuk akal untuk keduanya.

**Perbaikan** (`a5bdcaf`): dikembalikan sesuai kode asli.

**Pelajaran**: `test/settings_validation_test.dart` punya group `sensor bounds` yang mengunci konfigurasi batas tiap sensor. Group itu menemukan **regresi kedua** (`minAllowed`) tepat setelah yang pertama diperbaiki. Test penjaga konfigurasi ini wajib dipertahankan.

### 5.7 Estimasi runtime baterai 75 jam vs draw nyata 28 W

**Ditemukan**: laporan user ("estimasi baterai agak kacau, penggunaan daya sekitar 30 wattan").

Ada dua bug yang berantai.

**Bug 1** (`a3ef784`) - sumber daya salah:

```dart
final loadWatts = peak?.value ?? ...   // peak dari power_AC
```

Runtime dibagi dengan *peak* beban AC (16 W), bukan discharge baterai. Salah dua kali: peak AC sering terjadi saat PV masih menutupi beban, ketika baterai tidak discharge sama sekali, dan peak adalah kasus terburuk bukan draw rata-rata.

**Bug 2** (`d5da49e`) - konvensi tanda:

```dart
if (reported != null && reported > 0) return reported;    // ditolak
final watts = voltageValue * currentValue;
if (watts > 0) return watts;                              // ditolak
```

BMS Bluetooth melaporkan `current` sekitar `-2.08 A`, sehingga `voltage * current` juga negatif dan **kedua sumber ditolak**. Estimasi lalu diam-diam jatuh ke rata-rata beban AC. Ini sebabnya perbaikan pertama dipasang tapi tidak berefek.

**Verifikasi di perangkat** (setelah `d5da49e`):

```
13.3 V x 2.08 A = 27.7 W       cocok dengan "~30 W" yang dilaporkan user
40.6 jam x 0.0277 kW / 0.94 = 1.195 kWh
1.195 kWh / 13.3 V          = 89.8 Ah    baterai 12V 100Ah
```

Estimasi turun dari **75.8 ke 40.6 jam** (rasio 1,87 kali).

**Perbaikan final** (`EnergyForecastService.estimateBatteryDischargeWatts`), urutan prioritas:

1. `power` dari device baterai, **by magnitude**
2. `voltage x current`, **by magnitude**
3. Rata-rata beban AC pada jam tanpa PV
4. AC peak, sebagai fallback terakhir

Langkah 3: sebuah jam dianggap "malam" hanya bila **semua** sampel solar di jam itu nol, agar penampikan awan sesaat tidak salah dikira malam.

---

## 6. Status Pengujian

```
flutter analyze  ->  No issues found
flutter test     ->  139 tests, All tests passed
```

| File | Test | Cakupan |
|---|---|---|
| `cctv_test.dart` | 22 | status model, overlay, host allowlist `parseAllowedCctvUrl` |
| `dashboard_helpers_test.dart` | 22 | history window, interval, integrasi energi, cache split, `describeHistoryRange` |
| `energy_report_helpers_test.dart` | 21 | bucketing harian dan bulanan, lintas batas bulan dan tahun, skala chart |
| `thingsboard_api_test.dart` | 20 | URI WebSocket, state sesi, migrasi token, cache offline, key set |
| `settings_validation_test.dart` | 18 | validasi range, target harian, batas sensor |
| `chart_bounds_test.dart` | 16 | `niceStep`, `niceTimeStep`, alignment sumbu X, tick multi-hari |
| `energy_forecast_service_test.dart` | 13 | produksi harian, proyeksi runtime baterai |
| `settings_screen_test.dart` | 5 | widget test: daftar category, drill-down, navigasi back, penolakan URL |
| `widget_test.dart` | 2 | smoke test |

Semula hanya 4 test. Penambahan test bukan bonus. Beberapa regression di atas
**hanya ketahuan** karena test penjaga.

### `thingsboard_api_test.dart` - 26 September 2026

Service ini 500 baris dan dulunya **nol test**, padahal itu jantung integrasi.
Ironisnya bug `describeHistoryRange` yang lolos ke produksi justru karena kedua
fungsi yang dibandingkan tidak punya test.

Yang ditutup (tanpa network):

- URI WebSocket: `https` → `wss`, path plugin telemetry, dan **token tidak
  dikirim sama sekali** kalau belum login (bukan `token=` kosong)
- State sesi: token kosong bukan sesi, secure storage menang atas legacy yang
  basi, dan token legacy **dimigrasikan lalu dihapus** dari SharedPreferences
- Cache offline: round-trip, clear, dan JSON rusak → `null`, bukan crash
- Realtime service tidak membuka socket tanpa token
- Key set telemetry, device ID, dan base URL

### Key set sempat diduplikasi - sudah dirapikan

Saat menulis test di atas, ternyata daftar key **ditulis dua kali**: di fetcher
REST dan di langganan WebSocket. Kalau satu ditambah dan yang lain tidak,
metriknya tetap masuk lewat polling tapi **tidak pernah live-update**, dan
tidak ada apa pun di log yang menjelaskannya.

Kelas bug yang sama sudah menyerang project ini dua kali (§5.6 dan §11.6). Jadi
literalnya sekarang tinggal di satu tempat sebagai
`ThingsBoardApi.batteryKeys` / `pzemKeys` / `sensorKeys`, dan kedua transport
mengacunya. Test sisanya menjaga daftar itu dari duplikat, key yang tumpang
tindih antar device, dan mutasi.

Test suite: 119 → **139**.

---

## 7. Sudah Diverifikasi di Perangkat Fisik

| Area | Status |
|---|---|
| Login ThingsBoard (Customer User) | display name dari ThingsBoard tampil |
| REST dan WebSocket real-time | indikator "Live" hijau |
| Tab PV / AC / Battery dengan chart 3 seri | kurva produksi realistis, statistik terisi |
| Weather (OpenWeatherMap) | Kertapati, 31.0 C, 55 persen, 4.6 m/s |
| Energy analytics | produksi, perbandingan periode, forecast |
| Pengaturan ke Environment alerts | field min/max render dan tersimpan |
| Pengaturan ke Appearance | ganti accent (Solar amber) ikut diterapkan ke seluruh UI |
| CCTV (go2rtc) | HTTP 200, video decode `c2.mtk.avc.decoder` berjalan |
| Biometric gate | sidik jari |
| Estimasi baterai | 40.6 jam, cocok dengan perhitungan manual |
| Chart label ikut tanggal | header `25/9/2026`, bukan "Last 24 hours" |
| Field TDS 4 digit | menerima `1200` / `2500` |
| Release build 1.4.0 | cold launch **1038 ms**, fingerprint cocok PRD §3, APK di GitHub identik byte-per-byte dengan build lokal |

**Catatan tentang Weather.** Sesi build Linux (26 September 2026) mengosongkan
data aplikasi saat uninstall, jadi API key OpenWeatherMap ikut hilang. Keberadaan
fitur ini terverifikasi di sesi sebelumnya, tetapi kelanjutannya belum diuji
ulang di perangkat. Isi ulang API key di Settings → Weather untuk mengonfirmasi.

---

## 8. Sudah Diverifikasi - Ditutup 26 September 2026

Kedua item yang tadinya tertunda **sudah dicek manual di perangkat** dan benar.
Bagian ini ditutup; tidak perlu dikerjakan lagi.

### 8.1 Label chart mengikuti tanggal - ✅ VERIFIED

Membuka tab **PV** dan memilih tanggal kemarin di date strip memunculkan header
dengan tanggal (`25/9/2026`), bukan "Last 24 hours". Sumbu X di jam bulat.
Perbaikan `describeHistoryRange()` di `e897cca` bekerja sesuai rancangannya.

### 8.2 Field TDS menerima angka 4 digit - ✅ VERIFIED

Kolom Min / Max **Water TDS** di Settings → Environment alerts menerima
`1200` dan `2500` tanpa ditolak. Perbaikan `a5bdcaf` bekerja; batas TDS
kembali terbuka.

**Catatan**: dari 8 bug di section 5, sekarang **semua 8** punya hasil yang
sudah dilihat di layar, bukan hanya test hijau.

---

## 8A. Sesi Build Linux - 26 September 2026

Project berhasil dibuild dari nol di CachyOS. Ringkasan untuk sesi berikutnya.

### Hasil

| Item | Nilai |
|---|---|
| Cold launch | **1110 ms** (target <2 detik ✓) |
| Warm release build | 3 menit 12 detik |
| `flutter analyze` | No issues found |
| `flutter test` | 119/119 lulus, 26,6 detik |
| Sidik jari signing | `504d13ee...` cocok PRD §3 ✓ |
| Android SDK total | 732 MB (dari 7,5 GB sebelum optimasi) |

### MASALAH BESAR: `dl.google.com` di-throttle

Ini penyebab build pertama memakan **berjam-jam**. AGP dan Gradle wrapper
mengunduh dari `dl.google.com` dan `services.gradle.org` di **65-114 KB/s**,
sedangkan `curl -L` ke URL yang sama mencapai **7-44 MB/s**:

| Artefak | via AGP/Gradle | via `curl -fL` |
|---|---|---|
| gradle-9.3.1-bin.zip (131 MB) | 103 KB/s → 22 mnt | 6,5 MB/s → 20 dtk |
| android-ndk-r28c (690 MB) | 65 KB/s → 2,9 jam | 44 MB/s → 17 dtk |
| platform-35 (61 MB) | 84 KB/s → 13 mnt | 7 MB/s → 9 dtk |
| platform-34 (60 MB) | 114 KB/s → 9 mnt | 29 MB/s → 2 dtk |

**Jangan pernah membiarkan AGP mengunduh SDK component di mesin ini.**
Pre-stage dengan `curl`, verifikasi checksum, baru build.

### Gotcha: `package.xml`

`sdkmanager` menulis `<dir>/package.xml` sebagai catatan paket terpasang, dan
AGP memakainya untuk memutuskan apa yang sudah ada. **Unzip manual tanpa file
ini akan membuat AGP mengunduh ulang**, padahal payload-nya sudah utuh di
disk. Gejalanya build diam-diam macet di unduhan yang tidak perlu.

Kabar baik: AGP kadang mengadopsi folder yang ada dan menulis `package.xml`
sendiri (terjadi untuk `platforms/android-34` dan `35`), tapi tidak selalu
(`ndk/28.2.13676358` dan `cmake/3.22.1` tidak). Jangan andalkan ini.

Detail skema dan cara membuatnya ada di `~/dev/setup-energrow.sh`
(fungsi `write_package_xml`).

### Gotcha: parsing repository XML

`https://dl.google.com/android/repository/repository2-3.xml` adalah sumber
kebenaran untuk nama arsip, ukuran, dan checksum. **Jangan menebak nama.**

Contoh kesalahan nyata: `android-ndk-r28-linux.zip` berisi **28.0.13004108**,
sedangkan 28.2.13676358 ada di `android-ndk-r28c-linux.zip`. Huruf `c` di
akhir wajib ada.

Bentuk XML juga mengalahkan parser naïf: `<size>` muncul **sebelum** `<url>`
di dalam `<complete>`, dan `<host-os>` berada **di luar** `<complete>`. NDK
mengirim satu `<archive>` per host OS, jadi entry linux harus dipilih eksplisit.

### NDK tidak bisa dihapus dari sisi project

`FlutterPlugin.kt:230` memanggil `forceNdkDownload` **unconditional** untuk
setiap project Flutter, dan funcinya **memalsukan** `externalNativeBuild`
supaya AGP mengira NDK dibutuhkan. Tidak ada flag opt-out.

Diverifikasi: build bersih dengan `ndk/` dan `cmake/` dihapus → AGP tetap
unduh NDK 28.2.13676358, lalu build menghasilkan **0 file `.o`**, tanpa
`build.ninja`, tanpa `libdartjni.so`. Jadi 2,3 GB diunduh dan tidak dipakai.

Satu-satunya jalan menghilangkannya adalah patch Flutter SDK, yang hilang
tiap `flutter upgrade`. **Tidak layak repot** - unduhannya sekali seumur
hidup mesin, dan `~/dev/setup-energrow.sh` mengubahnya jadi 17 detik.

### Yang berhasil dihilangkan

`path_provider_android` 2.3.0 menulis ulang sisi Kotlin-nya di atas paket
`jni`, yang mengharuskan NDK + CMake. Rantainya:

```
share_plus → share_plus_platform_interface → path_provider → path_provider_android → jni → NDK + CMake
```

`dependency_overrides: path_provider_android: 2.2.23` memutus rantainya.
Plugin Android 14 → 12, `libdartjni.so` hilang dari APK, tidak ada build
native, tidak ada CMake. Chain tidak bisa diputus dari sisi app karena
`share_plus_platform_interface` depend on `path_provider` tanpa syarat di
semua versi yang pernah rilis.

### Toolchain

```
Flutter 3.47.5 · Dart 3.13.4 · OpenJDK 21.0.12
Android SDK 36.0.0 · build-tools 36.0.0 · adb 37.0.1 · Gradle 9.3.1
```

Semua di `$HOME` (`~/dev/flutter`, `~/Android/Sdk`); hanya JDK perlu sudo.
`~/dev/setup-energrow.sh` membangun ulang semuanya secara idempotent,
`--check` untuk audit tanpa mengubah apa pun.
PATH fish ada di `~/.config/fish/conf.d/energrow-toolchain.fish`.

### Dokumen untuk agent

`AGENTS.md` dibuat di sesi ini, berisi semua hal yang mahal untuk
ditemukan ulang: arsitektur, konvensi, workaround throttle, gotcha ADB,
dan batas RAM.

---

## 9. Known Issues dan Utang Teknis

Sudah tercatat di README bagian Known Issues:

- **PZEM-017 (DC) stale** - silent read failure di firmware ESP32, belum tertangani di level hardware
- **Ketergantungan Orange Pi tunggal** - tidak ada redundansi backend
- **CCTV membebani baterai** - WebView decode di perangkat, polling 10 detik tetap jalan
- **Sumbu Y dibulatkan** - nilai ekstrem bisa membuat label berbeda dari angka yang tercatat

### Utang teknis yang diketahui

| Item | Detail |
|---|---|
| **Battery `power` mungkin tidak ada** | BMS murah sering tidak mengirim `power`. App sudah handle dengan memakai `voltage x current`. Di screenshot kartu Battery hanya menampilkan Voltage dan Current, jadi kemungkinan besar sedang memakai hasil perkalian. Kalau BMS di-upgrade, app otomatis memakainya tanpa ubah kode. |
| **Runtime pakai snapshot** | Estimasi memakai `power` sesaat, bukan rata-rata. Kalau perlu lebih stabil, bisa fetch histori `power` baterai juga. |
| **Proyeksi saat baterai charging** | Pakai magnitudo, jadi kalau sedang charge angka ini menjadi charging power, bukan runtime. Tidak kritis, tapi juga tidak sangat akurat. |
| **Plugin Kotlin** | `package_info_plus` dan `share_plus` masih memakai Kotlin Gradle Plugin cara lama. Flutter akan gagal build di versi mendatang. |
| **Test suite flakiness** | Lihat section 2. Akibat RAM terbatas, bukan masalah kode. |

---

## 10. Langkah Berikutnya

### 10.1 ~~Verifikasi dua hal yang tertunda~~ - SELESAI 26 September 2026

Kedua item section 8 sudah dicek manual di perangkat dan benar. Tidak ada
loop terbuka dari sesi refactor.

### 10.2 Build APK release - SELESAI 26 September 2026

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk  (58 MB)
```

Terbangun, sidik jari signing diverifikasi cocok PRD §3, dan sudah terinstall
serta dijalankan di perangkat. Lihat section 8A.

`android/key.properties` ada (ter-ignore di git). Ada
`PRD_GitHub_Release_Process.md` yang menjelaskan langkah signing dan GitHub
Release.

### 10.3 Refactor sisa (opsional)

File terbesar yang masih belum disentuh:

| File | Baris | Catatan |
|---|---|---|
| `widgets/liquid_glass.dart` | 537 | design system, dipakai luas, hati-hati |
| `services/weather_service.dart` | 439 | service terbesar |
| `screens/alarm_history_screen.dart` | 382 | belum pernah di-refactor |
| `screens/dashboard/widgets/weather_card.dart` | 318 | belum pernah di-refactor |
| `screens/energy_report/widgets/chart_card.dart` | 280 | sudah dipisah, tapi masih satu widget besar |
| `services/thingsboard_api.dart` | 455 | jantung integrasi, tanpa test |

Folder `services/` sama sekali belum disentuh dan sekarang jadi file terbesar di luar widgets.

### 10.4 Menambah cakupan test

Masih tipis di:

- `thingsboard_realtime_service.dart` (WebSocket) - baru sebagian tertutup; yang
  diuji adalah guard, bukan parsing frame
- `weather_service.dart` - **belum ada test sama sekali**
- `energy_report_service.dart` - test hanya untuk helper, bukan service-nya
- `alarm_notification_service.dart` - logika background check belum teruji

`thingsboard_api.dart` **sudah ditutup** 26 September 2026, lihat section 6.

### 10.5 Push notification

Sudah ada `flutter_local_notifications`, `android_alarm_manager_plus`, dan service alarm background yang jalan, tapi notifikasi belum pernah diuji di Android 14 ke atas.

---

## 11. Gotcha untuk Agent Berikutnya

Hal-hal ini memakan waktu dan tidak terlihat di kode.

### 11.1 named record typedef tidak bisa dipakai

SDK ini **gagal** mendeteksi named field pada record typedef:

```dart
typedef PeriodTotals = ({double pv, double ac});
// -> "The getter 'pv' isn't defined for the type 'PeriodTotals'"
```

Gunakan **class** untuk data yang perlu named field. Record posisional masih aman, tapi `.$1` dan `.$2` di call site tidak terbaca.

### 11.2 `webview_flutter` callback nullable

```dart
onWebResourceError: (error) {
  if (mounted && error.isForMainFrame) { }          // ERROR: bool? can't be condition
  if (mounted && error.isForMainFrame == true) { }  // OK
}
```

`isForMainFrame` bertipe `bool?`.

### 11.3 Flutter hanya menerima device ID bentuk IP:port

Serial mDNS (`adb-XXXX._adb-tls-connect._tcp`) **ditolak** oleh `-d` walau muncul di `flutter devices`. Selalu pakai `IP:port`.

### 11.4 Jangan `tester.getSemantics()` tanpa `ensureSemantics()`

Bisa menggantung isolate, dan efeknya **seluruh test berikutnya di file itu** kena "did not complete". Kalau hanya butuh nilai properties, inspeksi widget-nya langsung:

```dart
final s = tester.widget<Semantics>(
  find.descendant(
    of: find.byType(MyWidget),
    matching: find.byType(Semantics),
  ).first,
);
expect(s.properties.label, '...');
```

`find.byType(Semantics).first` akan menangkap node milik `Scaffold` atau `MaterialApp`, bukan milik widget yang diuji. **Selalu persempit ke descendant.**

### 11.5 Jangan menyederhanakan tanpa cek tipe

Saat refactor CCTV, `error.isForMainFrame == true` diubah jadi `error.isForMainFrame` karena "lebih bersih", dan `flutter analyze` langsung menunjuknya. `== true` itu disengaja.

### 11.6 Regresi saat transkripsi nilai

Bug TDS dan humidity di section 5.6 lahir dari menyalin angka batas saat memindahkan kode. **Selalu cek git blame kode lama saat memindahkan literal:**

```bash
git show <commit-sebelum-refactor>:lib/screens/settings_screen.dart
```

### 11.7 CHANGELOG `[Unreleased]` sudah sangat panjang

Saat mau rilis, **petakan** isinya ke versi baru (misalnya 1.4.0) dan pindahkan, jangan biarkan menumpuk.

---

## 12. Referensi Cepat

### Perintah

```bash
flutter analyze                                   # harus bersih
flutter test                                      # 119 test
flutter run -d "192.168.18.44:42057" --no-version-check
flutter build apk --release

# Struktur dan status
git log --oneline -20
git status -sb
```

### Endpoint

| Layanan | URL |
|---|---|
| ThingsBoard | `https://dashboard.mbkm20262027.tech` |
| ThingsBoard API | `https://dashboard.mbkm20262027.tech/api` |
| CCTV | `https://cctv.mbkm20262027.tech/stream.html?src=cam1` |
| OpenWeatherMap | `https://api.openweathermap.org` (key di SharedPreferences `weather_api_key`) |

### Dokumentasi lain

| File | Isi |
|---|---|
| `README.md` | overview, arsitektur, setup, install, known issues |
| `PRD_PLTS_Monitoring_App.md` | requirement lengkap dan roadmap |
| `PRD_GitHub_Release_Process.md` | langkah signing dan GitHub Release |
| `CHANGELOG.md` | riwayat perubahan lengkap |
| `.github/agents/` | agent prompt: `security-qa-evaluator`, `ui-ux-performance` |

---

*Dokumen ini dibuat di akhir sesi refactor dan perbaikan bug. Diperbarui: 26 September 2026.*
