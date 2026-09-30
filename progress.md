# Progress - EnerGrow (PLTS Monitoring)

Dokumen ini adalah **handoff** untuk sesi berikutnya. Tujuannya supaya agent baru bisa melanjutkan tanpa harus membaca ulang seluruh riwayat percakapan.

- **Proyek**: `plts_monitoring` / **EnerGrow** - aplikasi monitoring energi PLTS hybrid
- **Konteks**: Proyek **FNN-XAI-IoT**, program MBKM, Politeknik Negeri Sriwijaya
- **Remote**: `https://github.com/fauznazz-afk/Smart-Farming.git` (branch `main`)
- **Dibuat**: 26 September 2026 · **Diperbarui**: 30 September 2026 (sesi kedelapan)
- **Status**: rilis **1.6.1 (build 13)** di `origin/main`. Setelah itu, **enam
  commit tanpa tag rilis** yang mengubah sistem secara mendasar — `pubspec.yaml`
  masih `1.6.1+13`. Rilis berikutnya harus memotong seluruh `[Unreleased]` di
  `CHANGELOG.md` sebagai **1.7.0**, bukan 1.6.2: surface system, navigasi, dan
  set chart berubah, yang tidak memenuhi syarat patch. Rilis
  sebelumnya: 1.5.0 (27 September 2026, commit `24189a0`).

- **Sesi kedelapan (30 Sep 2026 sore)** menutup dua hal besar:
  1. **Bug kontras yang sudah dua commit tertidur.** `test/color_helpers_test.dart`
     mengukur AA terhadap **enam dari enam hex basi** — nilai pre-restyle, yang
     *lebih terang* dari yang sebenarnya, jadi suite hijau sementara
     `faintColor` 4,47 · `statusBad` 4,48 · `statusAlert` 4,47 di bawah AA.
     List-nya sekarang dibaca dari `AppSurfaces`.
  2. **Neumorphism diperdalam** (`ce7a7a9`): raised jadi **tiga** shadow
     (contact + ambient + bounce), light mode naikkan alpha gelap dua kali
     setelah pengukuran piksel, dan `Pressable` yang baru — karena
     `AppCard.pressed` **tidak pernah dipakai satu pun call site** sejak
     migrasi soft-UI.

  Kedalaman sengaja ditaruh di shadow, bukan fill, karena `BoxShadow` hanya
  digambar di luar rect dan jadi tidak bisa menyentuh teks. Gradien fill sudah
  diukur dan ditolak: 4% sudah 4,15:1.

---

## 0. ✅ MULAI DI SINI - Status Terkini

**Rilis 1.6.0 (build 12) terbit.** Isinya ada di `CHANGELOG.md` §1.6.0; catatan
perangkat di §7 dokumen ini.

### Langkah pertama sesi baru

```bash
cd /run/media/fzn/Data/POLSRI/SEMESTER_7/AndroidDashboard/plts_monitoring
export PATH="/home/fzn/dev/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME=/home/fzn/Android/Sdk JAVA_HOME=/usr/lib/jvm/java-21-openjdk

flutter analyze          # harus: No issues found
flutter test             # harus: 363/363 (25 file) — jalankan PER-FILE, mesin 7 GB OOM kalau sekali jalan
cd android && ./gradlew :app:testDebugUnitTest   # harus: 11
git log --oneline -5     # lihat commit terakhir
```

### Yang sudah selesai (batch 1.6.0)

- ✅ Halaman **Hydroponics** dan **Fish** dari device ThingsBoard keempat;
  navigasi bawah 6 → 4 tab (PV/AC/Battery jadi satu tab Power)
- ✅ **Weather dihapus** — kartu, `WeatherService` + 15 test, `geolocator`,
  izin lokasi, dan API key yang satu-satunya tersimpan di luar secure storage
- ✅ Performa: race cache offline, frame WebSocket membangun seluruh tree,
  `_alarmRules` dihitung ulang per frame, selector Power 14–20 ms → median 6 ms
- ✅ Save Settings crash saat field limit kosong — diverifikasi di perangkat
  (Save pop + `run-as` membaca nilai baru dari `shared_prefs`)
- ✅ Konvensi tanda BMS (BMS diganti, arah berbalik) terpusat di
  `battery_sign.dart` dan dipin test
- ✅ `EnvironmentGrid` → `MetricGrid` generik; grid environment pindah ke
  Hydroponics; `AlarmThresholds.minFor`/`maxFor` jadi satu sumber limit
- ✅ Dua file test yang tidak pernah ikut gate (`*_test.dart`) di-rename, 5
  asersi basi diperbaiki — lihat sesi keenam di §0A
- ✅ Test 223 → **273**; `flutter analyze` bersih; Gradle 11 lulus

---

## 0A. Ringkasan Sesi

### Sesi pertama (26 Sep pagi) - refactor + 8 bug

Delapan commit refactor, dashboard 3.046 → 1.490 baris, settings 754 → 157,
CCTV dan energy report dipecah, plus 8 bug diperbaiki (§5C).

### Sesi kedua (26 Sep sore/malam) - build Linux + rilis 1.4.0

| Commit | Isi |
|---|---|
| `cb377fb` | Build Linux: `.gitattributes` ( CRLF), Gradle heap 12 GB → 1,5 GB, wrapper `-all` → `-bin` |
| `2af6d68` | NDK + CMake dihilangkan lewat `dependency_overrides: path_provider_android: 2.2.23` |
| `c1f5b44` | `AGENTS.md` baru, `CHANGELOG.md` dirapikan, `progress.md` §8 ditutup |
| `a24d6f8` | Test `thingsboard_api.dart` (0 → 20), key set dideduplikasi |
| `f6d50ee` | Dokumentasi cakupan test |
| `77633ef` | **Rilis 1.4.0 (build 10)**, tag `v1.4.0` |
| `34e3671` | Rekonsiliasi README vs progress.md soal verifikasi perangkat |
| `daf6a58` | Header versi di PRD + AGENTS.md brought up to date |
| `1ecafc5` | Geocoding endpoint HTTP → HTTPS |

**Pencapaian**: dari nol (tidak ada Flutter/Dart/Java/Android SDK) sampai rilis
terpublikasi. Test 119 → 143. Android SDK untuk setup bersih 7,5 GB → 732 MB.
Cold launch 911–1176 ms.

### Sesi ketiga (27 Sep) - fix One Call API + 36 test + terjemahan UI

| Commit | Isi |
|---|---|
| `749123e` | Fix `WeatherForecast.fromJson` (One Call API), tambah 36 test, terjemahan UI ke Indonesia, dokumentasi battery sign convention, `WeatherService.dispose()` |

**Pencapaian**: Test 143 → 179. `flutter analyze` bersih. Debug APK
ter-build dan ter-install di device. Semua perubahan ter-push ke `origin/main`.

### Sesi keempat (27 Sep) - compact dashboard + rounded splash logo

| Commit | Isi |
|---|---|
| `71bb751` | Compact dashboard layout (spacing 12-20px → 8px, padding dikurangi), rounded splash logo dengan `ClipRRect` |

**Pencapaian**: Dashboard lebih compact, lebih banyak informasi terlihat
tanpa scroll. Splash screen logo sekarang rounded. 179 tests lolos,
`flutter analyze` bersih, debug APK ter-build dan ter-install di device.

### Sesi kelima (27–28 Sep) - batch 1.6.0: Fish/Hydroponics, 4 tab, weather dihapus

Rincian lengkap di `CHANGELOG.md` §1.6.0. Ringkas:

- Halaman **Hydroponics** dan **Fish** dari device ThingsBoard keempat
  (`1c433980-…`), CCTV jadi bagian Hydroponics, kamera kedua `?src=cam2` punya
  setting dan secure-storage key sendiri. Fish device jadi `AlarmDevice`
  penuh (stale/offline), lalu threshold `Fish tank alerts` (pH 6–8,5, suhu
  20–30 °C, turbidity ≤100 NTU) menyusul di sesi keenam.
- Navigasi bawah **6 → 4 tab**: PV/AC/Battery jadi satu tab Power dengan
  segmented selector (`ValueNotifier`, median frame 6 ms, semula 14–20 ms),
  plus prefetch ketiga sub-view saat masuk tab.
- **Weather dihapus**: kartu Overview, `WeatherService` + 15 test,
  `geolocator`, izin `ACCESS_*_LOCATION`, section Settings API key.
- Performa dan konsistensi: race `cached_telemetry` (read-modify-write per
  device), WebSocket `changed: true` per frame, `ConnectionHealthService`
  notify per frame, `_alarmRules` getter per frame, token `Bound` tak memuat
  `_thresholds`.
- `EnvironmentGrid` → **`MetricGrid`** generik (`MetricSpec`, `decimals` per
  sensor, dua kolom untuk Fish); `minFor`/`maxFor` pindah ke `AlarmThresholds`.
- Konvensi tanda BMS **berbalik karena BMS diganti** → `battery_sign.dart`
  (`negative = discharging`), dipin `battery_sign_convention_test.dart`.
- **Save Settings crash** saat ada field limit kosong (`minKey!` pada
  turbidity) — exception lolos sebelum SnackBar, layar tidak pop, dan `true`
  untuk re-ship rules hilang. Kini di-null-guard dan punya regression test.
- Dead-code sweep ±24 simbol; offline cache & bound-token dirapikan.
- Test 179 → 223 di akhir sesi ini.

### Sesi keenam (28 Sep) - nama test, wiring grid, rilis 1.6.0

- **Dua file test tidak pernah dijalankan gate.**
  `widget_test_environment_grid.dart` dan `widget_test_live_power_card.dart`
  tidak match pola `*_test.dart` yang dikumpulkan `flutter test`. Di-rename ke
  `metric_grid_test.dart` dan `live_power_card_test.dart`, keduanya langsung
  gagal 5 asersi: 3 memakai teks gabungan `"25.0 °C"` padahal widget merender
  value dan unit sebagai dua `Text`, dan 2 memakai konvensi tanda BMS lama
  (negatif = Charging). Semua asersi kini mengklaim apa yang benar-benar
  dirender layar.
- **`kFishSpecs` diberi `metric`** (`ph`, `suhu`, `turbidity_ntu`) — tanpa ini
  wiring fish grid ke `AlarmThresholds` adalah no-op: verdict dan caption tidak
  akan pernah terhitung. Komentar basi "no threshold rules yet" diganti.
- **`showGridColors` di-wire**: `_environmentGrid` → `_thresholds.environmentAlerts`,
  `_fishGrid` → `_thresholds.fishAlerts` (+ `limitLabelFor`, jadi limit Fish
  tampil). Tag breach mengikuti toggle; tag `Stale data` sengaja tidak — sensor
  mati adalah fakta data, bukan limit yang di setel.
- Tiga gate terakhir: `flutter analyze` bersih, **273 test** lulus, Gradle 11.
- Dokumentasi rilis: `CHANGELOG.md` §1.6.0, FEATURE §18/§19, AGENTS.md
  (versi, jumlah test, konvensi baterai), progress.md, PRD version header.

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
    dashboard_screen.dart               1.490 baris, state container, komposisi 5 tab
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
    alarm_history_screen.dart           402 baris, belum di-refactor
    login_screen.dart
  widgets/                              primitif permukaan (AppCard/AppTile/AppBadge — nama file `liquid_glass` tidak akurat)
  test/                                 25 file, 363 test, ~5.900 baris
```

### Konvensi yang perlu dijaga

1. **Logic murni tinggal di `utils/`** - tanpa widget, tanpa I/O. Ini yang membuatnya bisa diuji.
2. **Widget menerima data secara eksplisit** - tidak menjangkau state privat screen. Contoh: `TelemetryCard(data:, metrics:, seedColor:)`, bukan `MetricCard` yang menarik dari `DashboardScreenState`.
3. **Nilai numerik lewat named parameter**, bukan singleton atau global.
4. **Pakai `SettingsKeys.*`** untuk setiap akses `SharedPreferences`. Jangan menulis string literal.

---

## 5. Bug yang Ditemukan dan Diperbaiki

### 5B. Dua Bug Setelah Rilis 1.4.0 - SUDAH DIPERBAIKI

Keduanya ditemukan pada 26 September 2026, **setelah** 1.4.0 terbit, dan
keduanya hanya muncul di build **release**.

#### 5B.1 Ikon notifikasi hilang dari APK release

> **Catatan 27 September 2026**: bagian ini masih berlaku untuk ikon, tapi
> mechanismenya sudah berbeda. `flutter_local_notifications` masih dipakai untuk
> alarm yang ditemukan saat aplikasi terbuka, jadi declare `<meta-data>` di
> `AndroidManifest.xml` tetap wajib. Modul alarm native memakai `NotificationCompat`
> dengan referensi drawable di Kotlin, yang selalu terlihat shrinker.

**Gejala**: setiap kali app start di release,
`PlatformException(invalid_icon, The resource @drawable/ic_energrow could not
be found)`. Tidak terlihat user karena `main.dart` menangkap exception itu
diam-diam. Efeknya: **alarm SOC rendah tidak pernah muncul**.

**Akar masalah**: `AlarmNotificationService` meneruskan
`@drawable/ic_energrow` sebagai string Dart. Resource shrinker tidak bisa
lihat string Dart, jadi resource yang hanya terjangkau dari Dart terhapus
dari APK.

**Perbaikan**: declare di `AndroidManifest.xml` lewat
`<meta-data android:resource="@drawable/ic_energrow" />`, satu-satunya tempat
yang selalu dibaca shrinker.

**Verifikasi**: `aapt2 dump resources` → `ic_energrow` ✅ ada; di perangkat,
`invalid_icon` = 0 kemunculan; ikon EnerGrow muncul di status bar.

#### 5B.2 Splash hang selamanya kalau secure storage tidak terbaca

**Gejala**: app **menggantung di logo tanpa jalan keluar**. Tidak ada error, tidak
ada login, tidak ada tombol. Satu-satunya jalan keluar: uninstall.

**Akar masalah**: `ThingsBoardApi.loadSavedToken()` memanggil
`FlutterSecureStorage.read()` **tanpa `try/catch`**. `_SplashRouterState`
menunggu Future itu sebelum memilih layar. Waktu secure storage melempar,
Future tidak pernah selesai, jadi splash tidak pernah adjourn.

**Perbaikan**: `try/catch` di `loadSavedToken()` (kegagalan = "tidak ada
sesi", user sampai ke Login); pemindahan `_removeLegacyCredentials()` agar
hanya jalan setelah read terbukti berhasil; `logout()` dibenahi agar state
in-memory dibersihkan lebih dulu dan delete jadi best-effort.

**Verifikasi**: 4 test baru memakai platform yang **selalu melempar**.
Dipastikan menangkap bug: dengan fix di-stash 3 test gagal, dengan fix semua
lulus.

### 5C. Bug dari sesi pertama (refactor, 8 item - semua sudah diverifikasi)

#### 5.1 URL CCTV di Settings tidak pernah berlaku

**Perbaikan**: `SettingsController` memakai `saveCctvUrl()` dan `loadCctvUrl()`. Konstanta `defaultCctvUrl` yang menduplikasi `defaultAllowedCctvUrl` juga dihapus.

#### 5.2 Sumbu chart tidak terbaca

**Perbaikan** (`2c6daf7`):

- `niceStep()` membuat Y snap ke 1 / 2 / 2,5 / 5 dikali 10 pangkat n
- `niceTimeStep()` membuat X snap ke menit bulat sampai satuan hari, sumbu X di-align ke batas jam
- Label tepi didorong 14 px ke dalam memakai `TitleMeta.axisPosition` (dalam pixel, bukan nilai, jadi tahan terhadap perubahan alignment)
- Rentang lebih dari 1 hari menampilkan **tanggal** (`26/09`), bukan `00:00` berulang

#### 5.3 `applicationId` masih template Flutter

**Perbaikan** (`2c6daf7`): menjadi `tech.mbkm.energrow`, dan `MainActivity.kt` dipindah ke `kotlin/tech/mbkm/energrow/`.

#### 5.4 Label chart tidak mengikuti tanggal terpilih

**Perbaikan** (`e897cca`): `describeHistoryRange()` yang meniru `historyTimeWindow` persis, jadi label tidak mungkin berbeda dengan data.

#### 5.5 Weather tidak update setelah mengisi API key

**Perbaikan** (`e897cca`): `WeatherService.reloadStoredConfig()` membaca ulang key dan lokasi tersimpan **tanpa menyentuh GPS** (menghindari permintaan izin lokasi berulang), dipanggil dari `_openSettings` sebelum mengecek `hasApiKey`.

#### 5.6 Batas alert TDS dan humidity hilang saat refactor

**Perbaikan** (`a5bdcaf`): dikembalikan sesuai kode asli.

#### 5.7 Estimasi runtime baterai 75 jam vs draw nyata 28 W

**Perbaikan final** (`EnergyForecastService.estimateBatteryDischargeWatts`), urutan prioritas:

1. `power` dari device baterai, **by magnitude**
2. `voltage x current`, **by magnitude**
3. Rata-rata beban AC pada jam tanpa PV
4. AC peak, sebagai fallback terakhir

---

## 6. Status Pengujian

```
flutter analyze  ->  No issues found
flutter test     ->  273 tests, All tests passed (19 file)
cd android && ./gradlew :app:testDebugUnitTest -> BUILD SUCCESSFUL (11 tests)
```

`alarm_parity_test.dart` menghitung 1 test statis + 23 skenario vektor dari
`alarm_parity_vectors.json` (dinamis), jadi jumlah statis per file (250) +
vektor (23) = 273.

| File | Test | Cakupan |
|---|---|---|
| `thingsboard_api_test.dart` | 26 | state sesi, token/refresh, URI WebSocket, key set per device, cache offline |
| `dashboard_helpers_test.dart` | 23 | history window, interval, integrasi energi, cache split, `describeHistoryRange` |
| `cctv_test.dart` | 22 | status model, overlay, host allowlist `parseAllowedCctvUrl` |
| `thingsboard_realtime_service_test.dart` | 21 | service lifecycle, device config, TelemetryPoint, DeviceTelemetry |
| `settings_validation_test.dart` | 21 | validasi range, target harian, batas per sensor (termasuk TDS tanpa plafon) |
| `energy_report_helpers_test.dart` | 21 | bucketing harian dan bulanan, lintas batas bulan dan tahun, skala chart |
| `alarm_rules_test.dart` | 20 | `buildAlarmRules` per kelompok, device tanpa pembacaan bukan stale, staleness per rule |
| `chart_bounds_test.dart` | 16 | `niceStep`, `niceTimeStep`, alignment sumbu X, tick multi-hari |
| `energy_forecast_service_test.dart` | 13 | produksi harian, proyeksi runtime baterai |
| `metric_grid_test.dart` | 10 | widget: verdict/caption/limit label, tag breach, `showGridColors`, stale tag, dark mode |
| `live_power_card_test.dart` | 10 | widget: unavailable, konvensi tanda (negatif = discharging), standby, arus tidak tertutupi beban |
| `energy_report_service_test.dart` | 9 | bucketing jam, data parsial DC/AC, clamp negatif, error kosong |
| `alarm_path_thresholds_to_rules_test.dart` | 9 | Settings → rules → JSON native, kedua kelompok alert, limit yang di-clear tidak hidup lagi |
| `color_helpers_test.dart` | 8 | satu accent satu hue (index diabaikan), warna terukur AA di permukaan nyata |
| `settings_screen_test.dart` | 6 | widget: daftar kategori, versi app, field limit, back, tolak URL CCTV & Fish |
| `settings_save_regression_test.dart` | 6 | save menulis semua key, satu sisi limit, `minKey` null tidak crash, pop & error terlihat |
| `battery_sign_convention_test.dart` | 6 | negatif = discharging (BMS kini), positif = charging, deadband ±1 W, konvensi BMS lama |
| `widget_test.dart` | 2 | smoke test: app boot, logo |
| `alarm_parity_test.dart` | 2 (+23 vektor) | fixture ada; evaluator Dart == evaluator Kotlin per skenario |

Semula hanya 4 test. Penambahan test bukan bonus. Beberapa regression di atas
**hanya ketahuan** karena test penjaga.

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
| Compact dashboard | spacing 8px antar card, padding dikurangi, lebih banyak info terlihat |
| Rounded splash logo | logo di splash screen sekarang rounded dengan `ClipRRect` |
| Save Settings setelah fix kosong (28 Sep) | Save pop ke dashboard; `run-as` membaca `fish_ph_min=6`, `fish_ph_max=8.5`, `fish_temp_min=20`, `fish_temp_max=30`, `fish_turbidity_max=100` dan limit environment dari `shared_prefs` |
| Sub-tab AC → PV (28 Sep) | satu detik setelah pindah, layar sudah menampilkan metrik DC saja — angka sub-tab sebelumnya tidak lagi tertinggal |
| Selector Power (28 Sep) | median frame **6 ms** di perangkat (semula 14–20 ms, diukur dengan tool perf) |

> Baris "Weather (OpenWeatherMap)" di atas adalah catatan historis: integrasi
> itu dihapus dari aplikasi pada 1.6.0, termasuk izin lokasi dan API key-nya.

---

## 8. Sudah Diverifikasi - Ditutup 26 September 2026

Kedua item yang tadinya tertunda **sudah dicek manual di perangkat** dan benar.
Bagian ini ditutup; tidak perlu dikerjakan lagi.

### 8.1 Label chart mengikuti tanggal - ✅ VERIFIED

Membuka tab **PV** dan memilih tanggal kemarin di date strip memunculkan header
dengan tanggal (`25/9/2026`), bukan "Last 24 hours". Sumbu X di jam bulat.

### 8.2 Field TDS menerima angka 4 digit - ✅ VERIFIED

Kolom Min / Max **Water TDS** di Settings → Environment alerts menerima
`1200` dan `2500` tanpa ditolak.

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

### NDK tidak bisa dihapus dari sisi project

`FlutterPlugin.kt:230` memanggil `forceNdkDownload` **unconditional** untuk
setiap project Flutter, dan funcinya **memalsukan** `externalNativeBuild`
supaya AGP mengira NDK dibutuhkan. Tidak ada flag opt-out.

Diverifikasi: build bersih dengan `ndk/` dan `cmake/` dihapus → AGP tetap
unduh NDK 28.2.13676358, lalu build menghasilkan **0 file `.o`**, tanpa
`build.ninja`, tanpa `libdartjni.so`. Jadi 2,3 GB diunduh dan tidak dipakai.

### Yang berhasil dihilangkan

`path_provider_android` 2.3.0 menulis ulang sisi Kotlin-nya di atas paket
`jni`, yang mengharuskan NDK + CMake. Rantainya:

```
share_plus → share_plus_platform_interface → path_provider → path_provider_android → jni → NDK + CMake
```

`dependency_overrides: path_provider_android: 2.2.23` memutus rantainya.
Plugin Android 14 → 12, `libdartjni.so` hilang dari APK, tidak ada build
native, tidak ada CMake.

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
| **Battery `power` mungkin tidak ada** | BMS murah sering tidak mengirim `power`. App sudah handle dengan memakai `voltage x current`. |
| **Runtime pakai snapshot** | Estimasi memakai `power` sesaat, bukan rata-rata. |
| **Proyeksi saat baterai charging** | Pakai magnitudo, jadi kalau sedang charge angka ini menjadi charging power, bukan runtime. |
| **Plugin Kotlin** | `package_info_plus` dan `share_plus` masih memakai Kotlin Gradle Plugin cara lama. Butuh coordinated upgrade (lihat §9A). |
| **Test suite flakiness** | Lihat section 2. Akibat RAM terbatas, bukan masalah kode. |

---

## 9A. Percobaan yang Gagal - Jangan Diulang

Bagian ini sengaja ada. Semuanya sudah dicoba dan gagal, dan knowing ini
menghemat satu sesi penuh.

### Upgrade KGP (BATAL, sudah di-revert)

**Tujuan**: menghilangkan peringatan
`WARNING: plugins that apply Kotlin Gradle Plugin (KGP): package_info_plus,
share_plus. Future versions of Flutter will fail to build`.

**Kenapa battal**: bukan karena gagal build. Build **sukses** dan peringatan
**hilang**. Dibatalkan karena:

1. **Bukti keamanannya tidak lengkap.** `flutter_secure_storage` 9 → 11
   menyimpan JWT ThingsBoard. Sesi tidak terbaca setelah upgrade, dan tidak
   bisa dibedakan apakah itu karena upgrade atau karena sesi sudah hilang dari
   uninstall sebelumnya.
2. **Biarnya bukan 2 paket tapi 3**, termasuk `flutter_secure_storage` major 9→11.
3. **Tidak menghapus kerusakan nyata**, hanya warning.

**Rantainya** (ini yang tidak jelas dari `flutter pub add`):

```
share_plus 13.x              → win32 ^6
flutter_secure_storage 9.x   → flutter_secure_storage_windows 3.x → win32 ^5
                               ↑ bentrok, harus naik ke 11.2.0
```

Kalau someday dikerjakan: **tiga paket**, dan `flutter_secure_storage` wajib
ikut naik. Plus `share_plus` 13.x memindahkan `XFile` dari `cross_file` ke
package `file` - itu perubahan kode nyata di
`lib/screens/energy_report/utils/csv_builder.dart`, bukan ganti nomor.

Diff percobaan tersimpan di `/tmp/opencode/kgp-upgrade.patch` (239 baris)
- **hilang** kalau `/tmp` sudah dibersihkan.

### Remedy ikon yang gagal

Alias di `res/values/ic_launcher_aliases.xml` **tidak mencegah stripping**,
karena alias itu sendiri hanya dirujuk dari resource, bukan dari manifest.
Jawabannya ada di `AndroidManifest.xml` (§5B.1).

### Kesalahan lain yang memakan biaya

- **`pkill -f "flutter_tools.snapshot build"` membunuh shell-nya sendiri**,
  dua kali, karena pattern-nya ada di command line shell itu. Pakai
  `[f]lutter_tools` (kurung siku) supaya tidak self-match.
- **`adb install` gagal `INSTALL_FAILED_UPDATE_INCOMPATIBLE`** karena HP punya
  build **debug** (flag `DEBUGGABLE`), sedangkan yang dibangun release.
  Delete dan install ulang wajib. Bukan masalah signature.
- **`am start` tidak selalu bring app ke depan.** Widget jadi dibangun, activity
  jalan, tapi top activity bisa tetap aplikasi lain. Selalu cek
  `topResumedActivity` sebelum `screencap` - kalau tidak, screenshot bisa
  menangkap konten pribadi pengguna. Ini benar-benar terjadi sekali di sesi ini.
- **`grep -oE '[0-9.]+'` juga mencocokkan titik di `Pkg.Revision`**, jadi
  parsing versi menghasilkan `.`. Pakai `sed` yang meng-anchor ke kunci.

---

## 10. Langkah Berikutnya

### 10.0 ~~Commit perbaikan yang tertenda~~ - SELESAI 27 September 2026

Semua perubahan sudah di-commit sebagai `71bb751` dan ter-push ke `origin/main`.

### 10.1 ~~Verifikasi dua hal yang tertenda~~ - SELESAI 26 September 2026

Kedua item section 8 sudah dicek manual di perangkat dan benar. Tidak ada
loop terbuka dari sesi refactor.

### 10.2 Build APK release - SELESAI 26 September 2026

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk  (58 MB)
```

Terbangun, sidik jari signing diverifikasi cocok PRD §3, dan sudah terinstall
serta dijalankan di perangkat. Lihat section 8A.

### 10.3 Refactor sisa (opsional)

File terbesar yang masih belum disentuh:

| File | Baris | Catatan |
|---|---|---|
| `widgets/liquid_glass.dart` | 583 | design system, dipakai luas, hati-hati |
| `screens/dashboard_screen.dart` | 1490 | core orchestrator, butuh device testing ekstensif |
| `screens/alarm_history_screen.dart` | 402 | belum pernah di-refactor |
| `screens/dashboard/widgets/weather_card.dart` | 331 | belum pernah di-refactor |
| `screens/energy_report/widgets/chart_card.dart` | 297 | sudah dipisah, tapi masih satu widget besar |

`thingsboard_api.dart` **tidak lagi tanpa test** - ditutup 26 September 2026
(§6). `weather_service.dart` dan `thingsboard_realtime_service.dart` juga
sudah ditutup 27 September 2026.

### 10.4 Menambah cakupan test

Sudah ditutup 27 September 2026:

- ✅ `weather_service.dart` - 15 tests (current weather + One Call API)
- ✅ `thingsboard_realtime_service.dart` - 21 tests (lifecycle + models)

Masih tipis di:

- `energy_report_service.dart` - test hanya untuk helper, bukan service-nya
- `alarm_notification_service.dart` - test hanya untuk helper, bukan service-nya.
  Tapi **logika alarm yang menentukan apa yang dihitung sebagai alarm sudah
  tercover penuh** per 27 September 2026: `lib/utils/alarm_rules.dart` dipisah
  dari I/O, lalu `test/alarm_rules_test.dart` (17 test) mengujinya dan
  `test/alarm_parity_test.dart` memutar ulang fixture yang sama dengan
  `AlarmParityTest.kt` di sisi Kotlin. Yang belum tercover adalah sisanya:
  pemanggilan method channel dan lifecycle scheduling, yang butuh perangkat.

### 10.5 Alarm background: ditemukan rusak, sekarang native, sudah terbukti

**27 September 2026.** Tuduhan lama "hanya belum diuji" ternyata salah: alarm
tidak pernah jalan sama sekali. `android_alarm_manager_plus` mewajibkan
`<service> AlarmService` dan `<receiver> AlarmBroadcastReceiver` di manifest,
dan keduanya tidak pernah ada. Alarm terdaftar tapi tidak pernah dikirim, dan
tidak menghasilkan log apa pun, jadi dari luar tidak bisa dibedakan dari
"belum diuji".

Diganti modul native Kotlin (§ AGENTS.md "Background alarms are native
Kotlin"). **Sudah terverifikasi end-to-end di Xiaomi malachite**, termasuk
notifikasi sungguhan:

- `configure` menerima aturan dari Dart, `arm=true`, kredensial tersimpan
- `dumpsys alarm` → dua trigger: `repeatInterval=60000` dan `flags=0x8`
  (`ALLOW_WHILE_IDLE`)
- cek berjalan saat app **terlatar belakang** dan selesai dalam ~450 ms:
  `check finished: 1 active (1 new): environment_humidity_high`
- notifikasi benar-benar muncul:
  `EnerGrow: Warning alarm` / `Kelembapan tinggi: 88.9 % (batas 80.0 %)`
- cek berikutnya `0 new` → **tidak ada spam**, notifikasi tidak diulang
- saat app di depan, cek `standing down` → ThingsBoard tidak dipoll dua kali
- APK release memuat `drawable/ic_energrow` dan string channel ✅
- aturan mengalir: 4 aturan default → 6 setelah ambang environment diisi

### 10.5a Tiga bug yang ketemu saat verifikasi

1. **Alarm lama tidak pernah fires** (di atas). Manifest kurang `<service>` dan
   `<receiver>`.
2. **Notifikasi duplikat tiap cold start.** Active-alert set dari sisi native
   dimuat *asinkron setelah* notifikasi dikirim, jadi tiap pembukaan app
   mengirim ulang alarm yang sudah dilaporkan background. Diperbaiki dengan
   priming sebelum evaluasi pertama, dan ada test penjaganya di
   `test/alarm_rules_test.dart` (`newlyActiveSignals`).
3. **Alarm dibuang MIUI.** `setInexactRepeating` berbunyi 6× lalu hilang dari
   `dumpsys alarm`; `com.miui.powerkeeper` terlihat di output yang sama.
   Diperbaiki dengan trigger kedua `setAndAllowWhileIdle` yang di-rearm tiap
   kali jalan.

Bug ke-2 dan ke-3 sama-sama tidak akan terlihat dari UI: keduanya muncul
sebagai "alarm tidak muncul" atau "alarm muncul saat app dibuka".

### 10.5b Catatan operasional

- `adb shell am broadcast` **tidak bisa** memicu `AlarmCheckReceiver` karena
  `exported="false"`. Itu memang benar secara keamanan. Untuk tes cepat pakai
  `AlarmDebugReceiver` (khusus build debug):
  `am broadcast -a tech.mbkm.energrow.action.DEBUG_CHECK_ALARMS -n tech.mbkm.energrow/tech.mbkm.energrow.alarm.AlarmDebugReceiver`
  dan `...DEBUG_RESET_ALARMS...` untuk memaksa alarm yang sedang menyala
  diumumkan ulang.
- APK **debug** tidak bisa dipasang di atas APK **release** (signature beda).
  `adb uninstall` dulu, dan sesi loginnya hilang → login ulang.
- Untuk memverifikasi notifikasi tanpa menunggu kondisi baru, set batas yang
  pasti terlampaui (mis. Humidity Max 80 saat kelembapan 88).
- MIUI masih bisa lebih agresif dari dua trigger itu. Jika alarm diam di
  perangkat lain, cek `dumpsys alarm` dulu sebelum conclude apa pun.

### 10.5c Review keamanan dan perapian (27 September 2026)

Tiga subagent read-only dipakai: audit keamanan, review kualitas kode, dan
audit UI dashboard. Temuan keamanan di kode baru ini sendiri:

- **Budget receiver terlampaui.** Worst case ~48 detik melawan ~10 detik yang
  diizinkan `BroadcastReceiver`, dan jalur lambat itu justru yang **diharapkan**
  setiap kali access token kedaluwarsa. Kalau proses dibunuh di tengah tulis,
  active set tidak pernah diperbarui → tick berikutnya menganggap alarm yang
  sama itu baru → notifikasi dobel. Deadlines 8 detik + timeout per request
  dibatasi + refresh dilewati kalau budget habis.
- **Tiga runner tanpa mutual exclusion.** Receiver, tombol "check now", dan
  debug trigger jalan di thread masing-masing tanpa guard bersama, jadi dua bisa
  membaca active set yang sama dan sama-sama memutuskan alarm itu baru. Satu
  `AtomicBoolean` proses-wide sekarang menutup semuanya.
- **Tombol "check now" tidak melakukan apa-apa.** Manual trigger mewarisi
  stand-down foreground, jadi ditekan saat app terlihat malah dilewati.
- **`allowBackup="false"` tidak menutup D2D** sejak Android 12. Ditambah
  `dataExtraction_rules.xml` + `backup_rules.xml`.
- **Host ThingsBoard hanya dicek prefix `https://`.** Prefix menerima host TLS
  apa pun, jadi begitu base URL jadi configurable, token bocor ke host salah.
  Sekarang allowlist host persis, menolak userinfo, port bukan 443, dan path.
- **Fragment JWT bisa masuk logcat** lewat pesan error `org.json` di jalur
  refresh. Sekarang hanya nama kelas yang di-log.

Semua sudah diperbaiki dan diberi test. Tidak ada temuan Critical.

### 10.5d Yang dibongkar di review kualitas kode

- `geocoding`, `csv`, `cupertino_icons` — dependency mati. `geocoding` bahkan
  pernah di-upgrade khusus kompatibilitas Android 14, untuk kode yang tak
  pernah dipakai, dan menarik satu plugin Android ke build.
- `searchCities`, `getAlarmsSince`, `acknowledgeAlarm`, `resolveAlarm`,
  `_find`, `alarmValueFromId`, `clearCctvUrl`, `fetchHistory`,
  `DashboardShortcut`, dan seluruh file `energy_forecast_card.dart`.
- 22 literal telemetry key yang diduplikasi di dua file.

**Satu klaim dari review kode salah**, dan hampir ikut terhapus karena
terdengar meyakinkan. `_history` di `dashboard_screen.dart` disebut dead code
plus memory leak; kenyataannya `TelemetryChartCard` menerimanya di baris 1460,
jadi field itu hidup. Yang salah adalah klaimnya, bukan kodenya.

### 10.5e Yang diperbaiki di UI dashboard

Lima temuan terbesar dari audit UI:

- **`metricColor` mengabaikan `index`** → semua metrik satu warna. Sekarang
  rotasi hue 40° per index, sesuai niat parameter itu sejak awal.
- **Tiga banner bertentangan** → offline menampilkan hijau "polling active"
  di atas oranye "offline". Sekarang satu strip dengan presedensi.
- **Label date strip salah** → menyebut rentang 7 chip, bukan hari yang
  dipilih, jadi berbeda dengan halaman detail untuk state yang sama.
- **Kartu environment tanpa status** → lima angka tanpa acuan. Sekarang
  menampilkan batas, ikon status, dan verdict keseluruhan.
- **22 lokasi kontras gagal WCAG AA** (`black45` ≈ 3.4:1 untuk teks 9dp).

Plus: desimal tidak masuk akal (`Cycles 12.00` → `12`), label DC/AC ambigu,
indikator kesegaran data yang selalu terlihat, kapasitas penuh baterai yang
sudah di-fetch tapi tidak pernah ditampilkan, 4 warna aksen yang hampir sama,
dan toggle "Smooth Glass" yang menyalakan blur saat dimatikan.

**Belum dikerjakan** (agak besar, perlu keputusan terpisah): mengganti
`DualStatusCards` dengan strip status, dan mengganti chart 3-seri-berbeda-
satuan dengan satu metrik terpilih lewat segmented button. Keduanya bagus, tapi
menyentuh layout substantially.

### 10.6 Utang KGP - jika someday dikerjakan

Lihat §9A. Ringkasnya: **tiga paket** (`share_plus` → 13,
`package_info_plus` → 10, `flutter_secure_storage` → 11), plus `XFile` pindah
dari `cross_file` ke `file` di `csv_builder.dart`. Dan wajib diuji di perangkat
karena menyangkut penyimpanan sesi.

**Update 27 September 2026**: Sudah dicoba upgrade `package_info_plus` ke 10.x
dan `flutter_secure_storage` ke 11.x. Keduanya gagal karena konflik `win32`:
- `package_info_plus` 10.x butuh `win32 ^6.0.1`
- `flutter_secure_storage_windows` 3.x masih butuh `win32 ^5.0.0`
- `flutter_secure_storage` 11.x butuh `flutter_secure_storage_platform_interface` 2.x,
  yang konflik dengan pin 1.1.2 di dev_dependencies untuk testing

Ini adalah **coordinated upgrade** — tidak bisa dilakukan piecemeal.

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

### 11.7 ~~CHANGELOG `[Unreleased]` sudah sangat panjang~~ - SUDAH SELESAI

Sudah diselesaikan saat rilis 1.4.0: tiga header `[Unreleased]` dan tiga
heading `1.3.0` yang bertentangan digabung, dan blok
`[Unreleased] - 2026-09-25` diverifikasi terhadap git tag lalu dipindahkan ke
1.3.1. Aturannya sekarang: **tepat satu** `[Unreleased]`, dipetakan ke versi
saat rilis.

### 11.8 Resource hanya terjangkau dari Dart akan terhapus di release

`flutter_local_notifications` dan plugin serupa meneruskan nama resource
sebagai **string Dart**. Resource shrinker tidak bisa melihat string itu, jadi
resource-nya hilang dari APK **release** saja (build debug tidak strip).
Gejalanya `PlatformException(invalid_icon, ...)` yang tertelan `try/catch`.

Sudah diperbaiki di §5B.1 lewat deklarasi di `AndroidManifest.xml`. Kalau
muncul gejala serupa, cek dulu:

```bash
aapt2 dump resources build/app/outputs/flutter-apk/app-release.apk | grep <nama>
```

### 11.9 Future yang di-await sebelum menampilkan UI bisa menggantung

`loadSavedToken()` tidak pernah melempar saat normal, jadi tidak ada yang
sadar ia perlu `try/catch`. Waktu ia **melempar**, `_SplashRouterState` yang
menunggu Future-nya tidak pernah selesai, dan aplikasi diam di splash tanpa
error dan tanpa jalan keluar.

Aturan: Future yang dibaca sebelum menentukan UI harus punya error handling,
dan harus ada test dengan platform yang melempar. Sudah ada di
`test/thingsboard_api_test.dart` (`_ThrowingSecureStorage`).

---

## 12. Referensi Cepat

### Setup environment (dipakai di shell fish, bukan bash)

```bash
export PATH="/home/fzn/dev/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
export ANDROID_HOME=/home/fzn/Android/Sdk
export ANDROID_SDK_ROOT=/home/fzn/Android/Sdk
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
```

Permanen di `~/.config/fish/conf.d/energrow-toolchain.fish`. Shell aktif user
adalah **fish**, bukan bash.

### Perintah

```bash
flutter analyze                    # harus: No issues found
flutter test                       # harus: 363/363 (PER-FILE)
flutter build apk --release        # warm ~2-3 menit

# Perangkat (HP Xiaomi 24090RA29G, Android 16)
adb connect 192.168.18.44:<port>
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb -s 192.168.18.44:<port> logcat -d | grep -i flutter

# Struktur dan status
git log --oneline -20
git status -sb

# Toolchain
~/dev/setup-energrow.sh --check    # audit, read-only
~/dev/setup-energrow.sh            # install idempotent
```

### Endpoint

| Layanan | URL |
|---|---|
| ThingsBoard | `https://dashboard.mbkm20262027.tech` |
| ThingsBoard API | `https://dashboard.mbkm20262027.tech/api` |
| CCTV | `https://cctv.mbkm20262027.tech/stream.html?src=cam1` |
| OpenWeatherMap | `https://api.openweathermap.org` (key di SharedPreferences `weather_api_key`) |

### Toolchain

```
Flutter 3.47.5 · Dart 3.13.4 · OpenJDK 21.0.12
Android SDK 36.0.0 · build-tools 36.0.0 · adb 37.0.1 · Gradle 9.3.1
```

Semua di `$HOME` (`~/dev/flutter`, `~/Android/Sdk`); hanya JDK perlu sudo.

### ⚠️ `dl.google.com` di-throttle di mesin ini

AGP/Gradle mengunduh 65-114 KB/s; `curl -L` 7-44 MB/s. Untuk build pertama
di mesin baru, pre-stage dengan skrip. Detail dan tabel pengukuran di §8A.

### Dokumentasi lain

| File | Isi |
|---|---|
| `AGENTS.md` | catatan kerja untuk agent: arsitektur, konvensi, gotcha |
| `README.md` | overview, arsitektur, setup, install, known issues |
| `PRD_PLTS_Monitoring_App.md` | requirement lengkap dan roadmap |
| `PRD_GitHub_Release_Process.md` | langkah signing dan GitHub Release |
| `CHANGELOG.md` | riwayat perubahan lengkap |
| `RELEASE_NOTES_v1.4.0.md` | ringkasan rilis terakhir |
| `.github/agents/` | agent prompt: `security-qa-evaluator`, `ui-ux-performance` |

---

*Dokumen ini dibuat di akhir sesi refactor dan perbaikan bug. Diperbarui: 27 September 2026 (sesi keempat).*
