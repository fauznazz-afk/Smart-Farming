# FEATURE.md — Fitur yang Terimplementasi

Daftar fitur yang **benar-benar ada di kode**, diverifikasi dengan membaca
source — bukan dengan membaca dokumen lain. Kalau fitur tidak ada di sini, ia
tidak ada di aplikasi.

**Kenapa dokumen ini ada.** Tiga kali dalam satu sesi, regresi lolos
`flutter analyze`, lolos `flutter build --release`, dan lolos seluruh test yang
ada: `PV Output` yang muncul tiga kali di satu kartu, satuan yang terpotong jadi
`109....`, dan sebuah bar yang tidak menggambar apa pun tanpa exception.
Semuanya baru ketahuan dengan menjalankan aplikasi dan melihat layarnya. Feature
list yang tidak diverifikasi terhadap kode adalah cara kesalahan seperti itu
berhasil lolos review.

**Cara memperbarui.** Tiap fitur menuliskan di mana ia hidup dan bagaimana ia
dibuktikan bekerja. Kalau fitur dihapus, hapus juga barisnya di sini. Jangan buat
dokumen kedua.

**Untuk agent:** cara kerja, aturan keras, dan jebakan harness-nya ada di
AGENT_PLAYBOOK.md. Baca kedua dokumen ini sebelum menyentuh kode.

**Status verifikasi:** 30 September 2026, pada `ce7a7a9`. Flutter 3.47.5 /
Dart 3.13.4, target Android (API 36). `flutter analyze` bersih, `flutter test`
**372 lulus** di 26 file, `./gradlew :app:testDebugUnitTest` 11 lulus. Suite
Dart dijalankan **per-file dengan upto 3 percobaan** karena mesin 7 GB ini OOM
kalau sekali jalan — gejalanya `did not complete` tanpa stack trace, dan file
yang gagal **berpindah-pindah antar run**. Sudah dikonfirmasi terhadap baseline
yang di-`git stash`: suite yang sama gagal dengan cara yang sama tanpa perubahan
kode apa pun.

**Temuan 30 September sore yang menutup §18.2 butir 3.** `test/color_helpers_test.dart`
mengukur AA terhadap daftar hex yang **semuanya basi** — enam dari enam tidak
cocok dengan permukaan yang benar-benar dirender. Nilai basi itu *lebih terang*
dari yang sebenarnya, jadi test menghitung terhadap permukaan yang lebih memaafkan
dan tetap hijau sementara `faintColor` 4,47 · `statusBad` 4,48 · `statusAlert`
4,47 — **tiga di bawah AA**. Margennya berubah negatif tepat pada commit yang
tujuannya membuat bayangan terbaca. Sekarang list-nya dibaca dari `AppSurfaces`,
dan satu test baru memverifikasi lima guard `design_tokens_test.dart` dengan
**mematahkan tiap bug-nya satu per satu** — karena guard yang tidak bisa gagal
bukan guard.

**Yang sudah dilihat di perangkat pada 30 September 2026** (Xiaomi 24090RA29G,
`malachite`, 1220×2712 @ density 520/513, lewat USB, mode light **dan** dark):

- Keempat tab terbuka dan merender; **tujuh chart** menarik data nyata:
  Hydroponics Temperature (Air 45,88 °C vs **Panel 62,53 °C**), Humidity,
  Light (maks 54.612 lx), TDS (min 795,81 / maks 2509,07 ppm); Fish pH
  (6,37–7,75) dan Temperature `suhu` (24,99–31,53 °C) — `suhu` adalah key yang
  benar-benar dipublikasikan device dan kekhawatiran bahwa ia kosong **tidak
  terbukti**
- Sistem permukaan soft-UI terverifikasi di kedua mode: pasangan bayangan
  terbaca, kartu elevated, chip **inset** vs **raised**, tidak ada hijau di tepi
  kartu
- 20 rule ter-push ke modul native, session loaded, tidak ada crash di logcat
- 120 fps dilaporkan **oleh pemilik perangkat**, bukan diukur dengan
  `dumpsys gfxinfo` — belum ada bukti frame rate dari alat

**Yang masih belum pernah dilihat di perangkat:** stream CCTV end-to-end pada
URL produksi, energy report dengan data bulan penuh, dan nama Oktober/Desember
(§18.5).

**Konvensi tanda sensor.** BMS saat ini melaporkan **minus saat discharging** —
terukur 27 September 2026 setelah BMS diganti: `Power -22 W` sementara SOC turun.
BMS sebelumnya melaporkan kebalikannya (`Power -12.92 W` saat SOC naik di 69 %),
dan pertukaran itu membalik semua tampilan baterai tanpa satu pun indikator merah.
Pemetaan terpusat di `lib/utils/battery_sign.dart` dan dipin oleh test. Tiga
aturan yang lahir dari riwayat itu ada di §18.6.

---

## Daftar isi

1. [Autentikasi dan sesi](#1-autentikasi-dan-sesi)
2. [Dashboard](#2-dashboard)
3. [Chart](#3-chart)
4. [Halaman PV, AC, Battery](#4-halaman-pv-ac-battery)
5. [Environment grid](#5-environment-grid)
6. [Energy analytics](#6-energy-analytics)
7. [Energy report dan ekspor CSV](#7-energy-report-dan-ekspor-csv)
8. [Weather](#8-weather)
9. [CCTV](#9-cctv)
10. [Alarm — mesin aturan](#10-alarm--mesin-aturan)
11. [Alarm background native](#11-alarm-background-native)
12. [Pengaturan](#12-pengaturan)
13. [Alarm history](#13-alarm-history)
14. [Tema dan visual](#14-tema-dan-visual)
15. [Data layer](#15-data-layer)
16. [Integrasi](#16-integrasi)
17. [Yang bukan fitur / di luar cakupan](#17-yang-bukan-fitur--di-luar-cakupan)
18. [Celah yang diketahui](#18-celah-yang-diketahui)
19. [Verifikasi](#19-verifikasi)

---

## 1. Autentikasi dan sesi

| Fitur | Status | Bukti |
|---|---|---|
| Login username/password ThingsBoard | ✅ | `services/thingsboard_api.dart` → `POST /api/auth/login` |
| JWT + refresh token di secure storage | ✅ | `flutter_secure_storage`, key `tb_token` / `tb_refresh_token` |
| Migrasi token lama dari SharedPreferences, lalu dihapus | ✅ | `loadSavedToken()` |
| Sesi dimuat saat aplikasi dibuka | ✅ | `main.dart` → `_SplashRouterState._checkToken` |
| Login biometrik ke sesi tersimpan | ✅ | `local_auth`, splash screen |
| Refresh access token otomatis saat 401 | ✅ | `_getWithTokenRefresh` |
| Deteksi token kedaluwarsa | ✅ | **reaktif terhadap 401 saja** — tidak ada decode JWT, tidak ada cek `exp` |
| Logout manual dengan dialog konfirmasi | ✅ | Settings → Account |
| Nama pengguna ditampilkan | ✅ | `GET /api/auth/user`, `firstName` atau prefix email |
| Register / lupa password | ❌ | dikelola di ThingsBoard |

**Endpoint ThingsBoard yang dipakai:** `/api/auth/login` (POST),
`/api/auth/token` (POST), `/api/auth/user` (GET),
`/api/plugins/telemetry/DEVICE/{id}/values/timeseries` (GET, terbaru dan histori),
`/api/ws/plugins/telemetry` (wss). Header auth adalah `X-Authorization: Bearer …`
— bukan `Authorization`.

---

## 2. Dashboard

### Navigasi

| Fitur | Detail |
|---|---|
| 4 tab | Overview · Power (PV/AC/Battery) · Hydroponics · Fish |
| Bottom nav GlassNavBar | tombol melebar saat dipilih, menyusut jadi tombol bulat 64 px saat scroll turun ≥ 12 px, 380 ms |
| App bar transparan dengan blur progress | `DecoratedBox` berbasis progress scroll, di-quantize agar tidak rebuild tiap frame |
| Pull-to-refresh | semua halaman; di Overview juga refresh histori energi |
| Gesture chart tidak ganti halaman | `ChartGestureLockPhysics` — gate yang meneruskan physics dasar, bukan `NeverScrollableScrollPhysics` yang mematikan snapping. Delegasinya ke `createBallisticSimulation` baru benar pada 29 September 2026; sebelumnya fling jatuh ke friksi dan pager berjalan melewati ujungnya |
| Akses cepat app bar | Reload (disabled saat loading) · Alarm History · Settings |

### Hero card — `LivePowerCard`

| Elemen | Isi |
|---|---|
| Header | ikon matahari + teks `Live power` + label umur telemetry (**selalu tampil**) |
| Angka besar | Daya DC, 48 dp w900, `W` di 20 dp, atau `--` |
| Gauge | SOC baterai, lingkaran 90 dp, label `SOC`, warna accent |
| Power flow | `Solar N W` → `House N W` · `Charging` / `Discharging` / `Standby` |
| Split bar | 5 dp, proporsi beban rumah terhadap produksi solar |
| Kalimat status | `The array is not covering the house load right now` (amber) · `The array covers the house, N W spare` · `The array is just covering the house load` |

Nilai baterai dicetak **apa adanya seperti yang dilaporkan device** — bisa negatif.
Labelnya yang membawa arah, bukan tanda. Battery di standby menampilkan `Standby`,
bukan `Discharging 0 W`, karena nol bukan arah.

### SystemStatusStrip

Satu baris verdict, **tappable → halaman Battery**:

| Verdict | Label | Nilai | Detail | Syarat tampil |
|---|---|---|---|---|
| Baterai | `Charging` / `Battery` | `N%` | `min N%` | selalu |
| Jaringan AC | `AC grid` | `Stable` / `Unstable` | `220 V · 50 Hz` | selalu |
| Alarm | `Alarm` | jumlah | `active` | hanya bila > 0 |

`Stable` bila `|freq − 50| < 2 && 200 < volt < 240`.

**Hanya pelanggaran yang diberi warna.** Nilai yang sehat memakai warna teks biasa
dan ikonnya memakai accent.

### Banner — satu slot, presedensi ketat

| # | Kondisi | Widget | Teks |
|---|---|---|---|
| 1 | Fetch gagal | `ConnectionStatusBanner` | `ThingsBoard unreachable` |
| 2 | Mode offline | `OfflineBanner` | `Offline - showing the last data from {umur}` |
| 3 | **Hanya di Overview** + ada alarm | `EnergyAlertBanner` | daftar pesan alarm aktif |
| 4 | Perangkat stale | `ConnectionStatusBanner` | `Connected - stale data: {nama}` |

Semua melewati `BannerSwitcher`: fade + slide naik + **SizeTransition** (320 ms
masuk, 420 ms keluar). Keluar lebih lama daripada masuk.

### Sapaan dan date strip

Sapaan `Good morning` / `Good afternoon` / `Good evening` / `Good night` lalu
`, {nama}!`; tanggal `{hari}, {tanggal} {bulan} {tahun}`. Date strip 7 chip
`today−6 … today`, label kiri `Today` / rentang, kanan `Pick a day` / `Range`.
Calendar: rentang `today−90 … today`, locale `en_US`.

### Polling dan rebuild

| Mekanisme | Nilai |
|---|---|
| Interval default | 10 detik |
| Pilihan | 5 / 10 / 30 / 60 detik, atau mati |
| Auto-refresh mati | WebSocket saja, tanpa polling REST sama sekali |
| Device fetch | 3 request paralel, dijaga `in-flight` flag |
| Rebuild avoidance | 3 penghitung revisi (`_liveRevision`, `_energyRevision`, `_chartRevision`) + widget `Bound` dengan token hash |
| Pause | `paused` / `inactive` / `hidden` membatalkan timer |

---

## 3. Chart

**Tujuh chart di empat halaman.** Dideklarasikan sekali di
`dashboard/widgets/chart_groups.dart`; kunci request, legenda, statistik, dan
sumbu semuanya dibaca dari deklarasi itu, jadi satu halaman tidak bisa meminta
kunci yang tidak digambar atau menggambar kunci yang tidak diminta.

**Pengelompokan ditentukan oleh satuan**, dan itu sifat data, bukan pilihan
tata letak. Page prefix → grup:

| Prefix | Halaman | Grup | Seri per grup |
|---|---|---|---|
| `pv` | Power | 1 | `voltage_dc` · `current_dc` · `power_dc` |
| `ac` | Power | 1 | `voltage_ac` · `current_ac` · `power_ac` |
| `battery` | Power | 1 | `voltage` · `current` · `power` |
| `env` | Hydroponics | **4** | Temperature (`temp_dht` + `temp_ds18b20`) · Humidity · Light · TDS |
| `fish` | Fish Tank | **3** | pH · Temperature (`suhu`) · Turbidity |

Tegangan/arus/daya satu sumbu karena satu sistem listrik dalam besaran yang
bisa dibandingkan. Dua sensor suhu satu sumbu karena keduanya derajat Celsius —
dan itulah **titiknya**: jarak panel terhadap udara adalah pembacaan yang
dibutuhkan orang greenhouse, dan dua chart terpisah menyembunyikannya. Di
perangkat, panel memuncak 62,53 °C melawan udara 45,88 °C. Lux, persen, dan ppm
tidak berbagi sumbu dengan apa pun, dan bersama-sama akan menghasilkan chart
yang bentuknya artefak satuan, bukan greenhouse.

`water_level_percent` **tidak** punya chart: un-monitored di seluruh aplikasi,
tanpa limit dan tanpa `metric`, dan chart akan menyajikannya sebagai tren
primary yang selama ini tidak pernah diperlakukan demikian.

### Warna seri

| Kondisi | Warna |
|---|---|
| Grup multi-seri | Triad `#E53935` / `#43A047` / `#1E88E5` (gelap: `#FF5252` / `#69F0AE` / `#448AFF`), urutan yang sama |
| Grup satu-seri | **Accent pengguna** |

Grup satu-seri memakai accent karena tidak ada yang perlu dibedakan, dan merah di
sana akan punya dua arti dalam satu aplikasi. Triad **dipakai ulang, bukan
diperluas** — menambah hue untuk accommodate chip baru adalah kesalahan yang
sama dengan rotasi hue yang pernah di-revert, terbalik.

| Aspek | Nilai |
|---|---|
| Sumbu Y | `minY = min<0 ? min*1.1 : 0`; `interval = niceStep(maxY-minY, 4)`; `maxY` **di-snap ke kelipatan interval** |
| Label sumbu Y | semua pakai `faintColor`. Nilai **sebelumnya**: light `0xFF64748B` = 4,30:1 (gagal AA), dark `0xFFB7C4BD` = abu ke-4 yang berbeda |
| Label paling atas | `AxisSide.top` — menggantung **di bawah** garisnya sendiri, bukan di tengah. Di tengah, separuhnya keluar dari plot dan terpotong padding kartu |
| Sumbu X | `DD/MM` bila rentang > 1 hari, else `HH:MM`; tick tepi digeser 16 px |
| Downsample | ≤ 180 titik mentah, else 90 bucket × (min, max) |
| Legenda | ikon + nama + nilai terbaru per seri |
| Statistik | `Last` / `min` / `max` per seri, satu baris masing-masing, **16dp antar kolom dan 2dp antar baris** |
| Tooltip | waktu + seluruh nilai dalam satuan masing-masing |
| Animasi data | **mati** (`duration: Duration.zero`) di kedua chart |
| Cache bounds | per `prefix/grupTitle`, **bukan** per prefix — empat kartu satu halaman akan berbagi batas tanpa itu |

### Yang tidak ada lagi di header chart

Ikon kalender dihapus, dan bersamanya **satu-satunya jalan ke range picker
kustom**. Date strip hanya bisa memilih satu hari. Rentang yang sedang dilihat
tetap named di header, jadi tidak menjadi ambigu. Kalau dikembalikan, tempat
yang benar adalah app bar.

### Tidak diputuskan

**Sumbu Y pH dimulai dari 0.** Datanya hidup di 6,37–7,75 dalam rentang 0–10,
jadi penurunan 7,75 → 6,37 terjekan di seperlima plot. Nol adalah baseline
yang jujur untuk lux dan watt, di mana nol berarti sesuatu, dan tidak untuk
indeks tanpa dimensi. Apakah indeks terbatas boleh tidak berpatok ke nol
adalah keputusan tentang grup mana yang indeks dan mana besaran — belum
diubah secara global.
| Rentang | hari ini = 24 jam bergulir · hari lalu = 00:00–23:59 · kustom = 00:00–23:59:59.999 |
| Sampling | ≤ 1 hari → 5 mnt · ≤ 7 hari → 30 mnt · ≤ 30 hari → 2 jam · else 6 jam |
| Indikator | `Live` / `Polling` (state WebSocket, **bukan** sumber chart) |
| Alpha | 0.85, supaya arus dan daya yang coincided tetap kelihatan |

**Yang sengaja tidak ada:** metric picker, sumbu ternormalisasi 0–100%, dash
pattern. Ketiganya pernah dibuat dan dibatalkan; alasannya di `AGENTS.md`.
`dashArray` juga dibiarkan kosong, karena `[]` di fl_chart berarti "gambar nol".

---

## 4. Halaman PV, AC, Battery

Tiga halaman seragam: header → kartu metrik → header chart → kartu chart. Kartu
metrik menyisipkan baris "no update" bila telemetry lebih tua dari
`staleMinutes` atau belum pernah datang.

| Halaman | Metrik |
|---|---|
| **PV** | `Voltage DC` V · `Current DC` A · `Power DC` W · `Energy` kWh |
| **AC** | `Voltage AC` V · `Current AC` A · `Power AC` W · `Frequency` Hz · `Energy` kWh · `Power Factor` |
| **Battery** | `Voltage` V · `Current` A · `Power` W · `State of Charge` % · `Cycles` · `Remaining Capacity` Ah · `Full Capacity` Ah |

---

## 5. Environment grid

Lima sensor, layout 3 + 2, **tidak interaktif**.

| Sensor | Key | Label | Satuan | Dipantau? |
|---|---|---|---|---|
| Suhu ambient | `temp_dht` | `Temperature` | °C | ya |
| Kelembapan | `humidity_dht` | `Humidity` | % | ya |
| Suhu panel | `temp_ds18b20` | `PV Temp` | °C | tidak (informatif) |
| Cahaya | `lux` | `Light` | lx | tidak (informatif) |
| TDS air | `tds_ppm` | `TDS` | ppm | ya |

- **Hanya pelanggaran yang berwarna**: border merah + caption merah. Dalam batas →
  border accent + teks biasa.
- **Tidak ada centang, tidak ada segitiga peringatan, tidak ada hijau.**
- Caption rentang: `15–35` · `≥ 800` · `≤ 60`; tanpa caption bila tidak ada batas.
- Tag header hanya tampil saat bermasalah: `Stale data` atau `{n} out of range`.
  **Tidak ada state "semua normal".**

---

## 6. Energy analytics

Kartu di Overview. Sumber: `power_dc` + `power_ac`, agregasi `AVG` 30 mnt, window
`today − 13d15m … now` — **tidak mengikuti date strip**.

| Elemen | Konten |
|---|---|
| Period | `Day` / `7 days` |
| Tile | `PV production` kWh · `AC usage` kWh, masing-masing + perbandingan periode sebelumnya |
| Perbandingan | `{±N}% vs previous`; di bawah 0.1 kWh dianggap bermakna, sisanya `Nothing to compare yet` / `No production` / `N kWh, none last period` / `Same as before` |
| Forecast | `Daily estimate` kWh · `Peak usage` W · bar progres target |
| Runway | `N h of estimated battery` atau `No battery runway available` |
| Subtitle | `Estimated from average telemetry power` |

**`EnergyForecastService` murni, sinkron, tanpa I/O.** Menghitung observed
production (integral trapesium hari ini), daily estimate (ekstrapolasi linear ke
24 jam), peak usage, battery depletion hours, dan target progress.

**Asumsi yang perlu diketahui sebelum memakai angkanya** — semua tercatat di kode
dan tidak dinyatakan di UI:

1. Produksi dianggap **merata** sepanjang hari yang sudah lewat. Pagi × 2,67,
   sore × 1,33.
2. Agregat `AVG` 30 menit diperlakukan sebagai sampel instan.
3. Celah > 6 jam **dibuang**, bukan dijembatani, jadi energi hilang diam-diam.
4. Runway memakai `.abs()` pada `power`, jadi **tidak bisa membedakan charge dari
   discharge**.
5. Kapasitas dihitung dari tegangan paket saat ini, bukan nominal.
6. Kapasitas baterai **tidak pernah diteruskan** (`batteryCapacityKwh` selalu null).

---

## 7. Energy report dan ekspor CSV

| Aspek | Detail |
|---|---|
| Period | `Daily` / `Monthly` + pemilih tanggal |
| Window query | **selalu ~2 bulan** (1st bulan sebelumnya → now) — dibutuhkan untuk periode pembanding, tidak disebut di UI |
| Chunking | 28 hari per query, `AVG` 1 jam, `limit: 720`, berurutan |
| Bar chart | 2 batang per bucket (PV, AC), hard-coded amber `#FFC857` dan biru `#69B7FF` |
| Interaksi | tap → readout, stepper prev/next, slider |
| Totals | PV production, AC usage, jumlah sampel, jumlah bucket dengan data |
| Refresh | timer 5 menit + pull-to-refresh + tombol app bar; **hanya reload kalau bulan berubah** |
| CSV | `energy_report_{yyyy}_{MM}[_{dd}].csv`, UTF-8 BOM, CRLF, semua field di-quote |
| Share | `share_plus` dari memori — `path_provider` tidak dipakai |

Isi CSV: title, period, source, **method**, header
`Date|Hour / Sample count / PV production (kWh) / AC usage (kWh)`, satu baris per
bucket, baris `TOTAL`.

**Perbedaan realitas yang perlu diketahui:**

- Semua angka berasal dari **integrasi ulang `AVG` daya**, bukan dari energy
  counter ThingsBoard. `energy_ac` / `energy_dc` ada di key set tapi tidak pernah
  diminta, jadi laporan ini **tidak akan sama** dengan penghitung energi di
  ThingsBoard.
- `sampleCount` dihitung dengan increment **per key**, jadi satu jam yang punya
  `power_dc` dan `power_ac` dilaporkan sebagai 2 sampel.
- **Perbandingan periode memakai kebijakan berbeda** dari Energy analytics:
  tidak ada ambang 0.1 kWh.

---

## 8. Weather - dihapus

**Tidak ada lagi.** Integrasi OpenWeatherMap dicabut bersama kartunya.

Yang dihapus: `WeatherCard` di Overview, `WeatherService`,
`test/weather_service_test.dart`, section Weather di Settings, dependency
`geolocator`, dan permission `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION`
dari manifest.

**Alasannya.** `lux` sudah tampil di halaman Hydroponics dan `power_dc` sudah
tampil di Energy analytics, jadi kartu itu hanya mengulang angka yang sudah ada
di tab lain. Selain itu `weather_api_key` adalah satu-satunya kredensial yang
disimpan di SharedPreferences bukan secure storage, dan `/onecall` dipanggil di
setiap fetch lalu 48 + 48 entri dibuang karena `WeatherCard.forecast` tidak pernah
dirender. Field City sudah tidak berfungsi sejak lama: `getWeatherByCity` hanya
dipakai tombol Test Connection, sedangkan dashboard selalu me-resolve dari GPS.

**Yang hilang, dan itu harus dicatat jujur:** suhu dan kelembapan **luar**,
angin, tutupan awan, dan seluruh prakiraan ke depan. `power_dc` dan `lux` adalah
**pengukuran, bukan prediksi** - keduanya tahu apa yang terjadi sekarang, tidak
tahu apa yang terjadi besok. Kalau prakiraan dibutuhkan lagi, jalurnya adalah
backend push atau prediksi FNN-XAI (PRD §7.4), bukan API cuaca.

---

## 9. CCTV

| Aspek | Detail |
|---|---|
| Halaman | tab tersendiri, **bukan** card di Overview |
| Transport | `webview_flutter`, `JavaScriptMode.unrestricted` |
| Autoplay | **tidak** — harus tekan `Play camera` |
| URL | `https://cctv.mbkm20262027.tech/stream.html?src=cam1` |
| Validasi URL | `parseAllowedCctvUrl` — https, host **persis** `cctv.mbkm20262027.tech`, port absen atau 443 |
| Navigasi | setiap URL di luar host yang diizinkan di-`prevent` |
| Status pill | `STANDBY` (amber) · `CONNECTING` (amber) · `LIVE` (hijau) · `OFFLINE` (merah) |
| Overlay | standby / connecting spinner / `Camera could not be loaded` + Retry + Back |
| Kontrol | Stop stream, Reload camera, Full screen — **hanya saat `LIVE`** |
| Fullscreen | route baru, `immersiveSticky`, orientasi landscape, tombol exit |
| Error handling | `isForMainFrame == true` saja yang dianggap gagal |
| Storage | `flutter_secure_storage` (bukan SharedPreferences) |

---

## 10. Alarm — mesin aturan

`lib/utils/alarm_rules.dart` — **satu-satunya definisi** dari apa yang dihitung
sebagai alarm. Dashboard dan modul native mengevaluasi daftar yang sama.

### Aturan yang bisa dibangun

| Grup | Aturan | Severity | Device | Kondisi |
|---|---|---|---|---|
| Energy | `low_soc` | critical | battery | `soc < lowSocThreshold` |
| Energy | `offline_<device>` | **critical** | semua 3 | diam > `offlineMinutes` |
| Energy | `stale_<device>` | warning | semua 3 | diam > `staleMinutes` |
| Environment | `environment_{sensor}_low` | warning | sensor | `value < min` |
| Environment | `environment_{sensor}_high` | warning | sensor | `value > max` |

Empat perangkat, jadi aturan energi adalah `low_soc` + satu pasang
`stale_`/`offline_` per perangkat. Yang terverifikasi di perangkat pada
29 September 2026: **19 aturan ter-push untuk 4 perangkat** — 9 energi
(`low_soc` + 4 × 2) dan 10 batas lingkungan. Angka itu bergantung pada limit
yang benar-benar tersimpan, bukan pada kode: lihat §18.7, di mana satu batas
ternyata tidak pernah ter-arm.

`offline` dan `stale` sengaja dua kondisi berbeda: 10 menit sunyi adalah hiccup,
satu jam adalah sensor mati. Default `offlineMinutes` 60, sengaja jauh di atas
`staleMinutes` 10, supaya jeda singkat tidak dengan sendirinya naik level.

Aturan lingkungan **tidak pernah dibangun kalau limit null**. TDS sengaja **tidak
punya batas atas** — air tawar tidak punya plafon.

### Semantik evaluasi

| Keputusan | Alasan |
|---|---|
| Device **tidak menghasilkan pembacaan** → **tidak ada alarm sama sekali** | Kegagalan jaringan adalah data hilang, bukan kondisi. Menganggapnya sebagai stale pernah mengubah satu outage menjadi tiga alarm menyesatkan. |
| `stale` / `offline` → cek umur telemetry | Bukan karena nilainya di luar batas, tapi karena tidak ada nilai baru. |
| Limit = batasnya → **tidak** alarm | Pembanding `<` dan `>` ketat. |
| Sensor environment **stale** → aturan environment **tidak dievaluasi** | Aturan yang menyala karena sensor sudah tidak fresh menggambarkan kondisi yang sudah berakhir. |
| Aturan pertama yang cocok menang | Satu sinyal per aturan. |

### Pesan

```
low_soc    : Battery charge low: {value}%
stale     : No fresh data from {label}
offline   : {label} has stopped reporting
rangeLow  : {label} too low: {value} {unit} (limit {limit} {unit})
rangeHigh : {label} too high: {value} {unit} (limit {limit} {unit})
```

**Pesan ini diduplikasi di dua bahasa** — Dart (`formatAlarmMessage`) dan Kotlin
(`AlarmMessageFormat.kt`) — karena notifikasi dibangun saat Dart tidak berjalan.
Keduanya dipin oleh `android/app/src/test/resources/alarm_parity_vectors.json`
(23 skenario), yang diputar ulang oleh `test/alarm_parity_test.dart` **dan**
`AlarmParityTest.kt`. Regenerate dengan
`dart run tool/generate_alarm_parity_fixture.dart`.

### Satu daftar aktif, bukan penghitung waktu

Notifikasi dikirim **hanya untuk alarm yang baru aktif**. Set ID alarm aktif
disimpan dan dibagi antara aplikasi dan modul native, jadi kondisi yang masih
berlaku tidak mengulang notifikasi tiap menit.

Implementasi sebelumnya memakai penghitung waktu lima menit — **yang lebih lama
daripada interval pengecekan, jadi tidak pernah mencegah pengulangan.**

`_activeAlertsPrimed`: dashboard **menahan** pengumuman sampai daftar aktif dari
modul native terbaca, supaya cold start tidak mengulang yang sudah dilaporkan.

### Tanpa SnackBar

Pesan yang sama pernah muncul dua kali — banner yang sudah dibaca user, dan
SnackBar di bawah layar yang menutupi kartu energi. SnackBar juga menyala ulang
setiap kali *kumpulan pesan berubah*, bukan setiap alarm baru, sehingga
pembacaan yang naik-turun di batas memunculkan bar setiap beberapa detik.

---

## 11. Alarm background native

13 file Kotlin di `android/app/src/main/kotlin/tech/mbkm/energrow/alarm/`.
**Tidak ada Flutter engine di jalur ini.**

### Penjadwalan

| Konstanta | Nilai |
|---|---|
| `INTERVAL_MINUTES` | `1L` |
| `REQUEST_CADENCE` | `71_025` |
| `REQUEST_IDLE` | `71_026` |
| `ACTION_CHECK` | `tech.mbkm.energrow.action.CHECK_ALARMS` |
| `BUDGET_MS` | `8_000L` |

**Dua alarm**, keduanya `RTC_WAKEUP`:

1. `setInexactRepeating` untuk ritme
2. `setAndAllowWhileIdle` satu kali, di-arm ulang oleh `AlarmScheduler.rearm()`
   di **baris pertama** `runGuarded`

Kenapa dua: alarm berulang adalah hal pertama yang dibuang vendor power manager.
Di perangkat uji MIUI/HyperOS, alarm berulang berjalan enam kali lalu hilang
diam-diam dari `dumpsys alarm`, dengan `com.miui.powerkeeper` di output yang
sama. Yang kedua bebas dari Doze batching.

Alarm persis **tidak dipakai**: butuh `SCHEDULE_EXACT_ALARM` yang harus diberikan
pengguna lewat pengaturan sistem, dan `USE_EXACT_ALARM` hanya untuk aplikasi jam
dan kalender.

### Manifest

| Komponen | Manifest | exported |
|---|---|---|
| `AlarmCheckReceiver` | main | `false` |
| `AlarmBootReceiver` | main | `false` |
| `AlarmDebugReceiver` | **debug saja** | `true`, **dan menolak** kecuali app debuggable |
| `MainActivity` | main | `true`, `launchMode="singleTop"` |

Permissions: `INTERNET` · `USE_BIOMETRIC` · `POST_NOTIFICATIONS` · `VIBRATE` ·
`REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` · `RECEIVE_BOOT_COMPLETED` ·
`ACCESS_FINE_LOCATION` · `ACCESS_COARSE_LOCATION`.

Tidak ada `<service>`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `WAKE_LOCK`,
`FOREGROUND_SERVICE`, atau `ACCESS_BACKGROUND_LOCATION`.

### Pipeline pengecekan

Tiga entry point — `AlarmCheckReceiver`, tombol `Check now`, dan trigger debug —
semuanya melewati **satu `AtomicBoolean` process-wide**.

| # | Langkah | Keluaran awal |
|---|---|---|
| 1 | `running.compareAndSet(false, true)` | `a check is already running; skipping` |
| 2 | log `check started` | — |
| 3 | `AlarmScheduler.rearm()` | — |
| 4 | stand down kalau foreground dan bukan force | `app is in the foreground; standing down` |
| 5 | config / rules / kredensial | `no alarm config stored` · `no rules armed` · `no credentials stored` |
| 6 | baca device **paralel**, satu thread per device | — |
| 7 | 401 → **satu** refresh, lalu retry hanya device yang 401, **seri** | — |
| 8 | evaluasi | — |
| 9 | tulis histori + notifikasi untuk yang baru aktif | — |
| 10 | simpan daftar aktif | — |
| 11 | `finish(...)` | `ok, no alarms` atau `N active (M new): <ids>` |

`M new` adalah angka yang menentukan apakah notifikasi dikirim — baris pertama
yang dibaca saat mendiagnosis.

Budget 8 detik ditegakkan di tiga titik: sebelum refresh, per iterasi retry, dan
per `future.get(remainingMs(deadline))`. `executor.shutdownNow()` di `finally`.

### Token

| Aspek | Detail |
|---|---|
| Serah terima | `accessToken` dan `refreshToken` sebagai **argumen terpisah** dari `config` — file config JSON di disk tidak pernah memuat kredensial |
| Enkripsi | AES-256-GCM di bawah kunci hardware-backed AndroidKeyStore (`"AndroidKeyStore"`, `PURPOSE_ENCRYPT or PURPOSE_DECRYPT`) |
| Penyimpanan | prefs privat `energrow_alarm_credentials`, IV dan ciphertext terpisah, `Base64.NO_WRAP` |
| 401 | refresh sekali; token baru ditulis; refresh token lama dipertahankan kalau server tidak merotasi |
| Refresh ditolak | 401 **atau 403** → modul membongkar dirinya sendiri: ciphertext dihapus, config dihapus, daftar aktif dikosongkan, kedua alarm dibatalkan |
| Yang keluar lewat channel | hanya **bool** `hasCredentials`. Tidak ada method yang mengembalikan token. |

Dart tetap memegang salinan otoritatif dan mendorong ulang saat launch maupun
setelah login.

### Store

| Store | File prefs | Isi |
|---|---|---|
| `AlarmTokenStore` | `energrow_alarm_credentials` | ciphertext access + refresh |
| `AlarmStateStore` | `energrow_alarm_state` | config, daftar aktif, histori, flag foreground, diagnostik |
| `AlarmScheduler` | `energrow_alarm_state` (file yang sama) | `check_scheduled` |

Sengaja **tidak** memakai `FlutterSharedPreferences`: `shared_preferences`
meng-encode `List<String>` sebagai blob Java-serialized Base64, yang harus
direproduksi byte per byte di Kotlin. Semuanya JSON biasa di file privat.

Skema record:

```json
{ "id": "<epochMs>_<ruleId>", "timestamp": "yyyy-MM-dd'T'HH:mm:ss.SSS",
  "type": "<Dart AlarmType>", "severity": "<Dart AlarmSeverity>",
  "message": "<rendered>", "value": <number>,
  "acknowledged": false, "resolved": false }
```

Retensi 100 record per sisi. `type` dan `severity` ditulis sebagai **nama enum
Dart** supaya histori selamat dari refactor Kotlin.

### Notifikasi

| | Warning | Critical |
|---|---|---|
| Channel id | `energrow_alarms` | `energrow_critical_alarms` |
| Judul | `EnerGrow: Warning alarm` | `EnerGrow: Critical alarm` |
| Penting | `HIGH` | `HIGH` |
| Notification id | `alarmId.hashCode()` — replace, bukan stack | idem |

Pemisahan channel ada karena **importance channel terkunci saat pembuatan** —
dengan satu channel, pengguna tidak bisa mematikan warning tanpa mematikan
peringatan baterai juga. Ketiga `PendingIntent` memakai `FLAG_IMMUTABLE`.

### Stand down saat foreground

Disimpan di `energrow_alarm_state` / `app_foreground`, default `false`. Satu
tempat saja ditegakkan: setelah `rearm()`, `if (!force && state.isForeground())`.
Yang disembunyikan: config load, pembacaan token, seluruh HTTP, evaluasi,
penulisan histori, notifikasi. Yang **tidak** disembunyikan: `rearm()`, dan
diagnostik tidak diperbarui sehingga `Last outcome` tetap menampilkan run
background terakhir.

Dipanggil dari 4 tempat di `DashboardScreen`: `initState`, `dispose`, `resumed`,
dan `paused`/`inactive`/`hidden`. `force = true` melewati stand down.

### Permukaan method channel

Channel: `tech.mbkm.energrow/alarm`.

| Method | Argumen | Kembalian |
|---|---|---|
| `configure` | `config`, `accessToken?`, `refreshToken?`, `arm`, `clearCredentials` | — |
| `disable` | — | — |
| `activeAlerts` | — | `List<String>` |
| `setActiveAlerts` | `ids` | — |
| `history` | — | `List<Map>` |
| `acknowledge` | `id` | `Boolean` |
| `resolve` | `id` | `Boolean` |
| `clearHistory` | — | — |
| `isScheduled` | — | `Boolean` |
| `checkNow` | — | — (segera) |
| `status` | — | `Map` dengan `scheduled`, `intervalMinutes`, `configSavedAt`, `hasCredentials`, `lastCheckAt`, `lastOutcome` |
| `requestIgnoreBatteryOptimizations` | — | `Boolean` |
| `isIgnoringBatteryOptimizations` | — | `Boolean` |
| `setForeground` | `value` | — |
| `launchAlarmId` | — | `String?` |
| `ensureChannels` | — | — |

`MissingPluginException` → `_unavailable` di-latch, dan **semua panggilan
berikutnya jadi no-op tanpa menyentuh channel.** Di platform non-Android inilah
alasan modul alarm sepenuhnya diam.

### Allowlist host

```
https://dashboard.mbkm20262027.tech   ← satu-satunya yang diterima
```

`requireAllowedThingsBoardHost` adalah **perbandingan host persis**, bukan tes
prefix. Menolak: skema bukan https, `userInfo` ada, host berbeda, port selain 443,
path selain `/`. Menolak `dashboard.mbkm20262027.tech.evil.example` dan
`notdashboard.mbkm20262027.tech` — dua trik yang akan lolos tes prefix `https://`.
Dipin oleh 5 test Kotlin.

### Properti keamanan lain yang terverifikasi

| Properti | Status |
|---|---|
| Cleartext | `usesCleartextTraffic` tidak pernah diset; `networkSecurityConfig` tidak ada; tidak ada `TrustManager`/`HostnameVerifier` override |
| Backup | `allowBackup="false"` **dan** `data_extraction_rules.xml` + `backup_rules.xml` mengecualikan root, file, database, sharedpref, external dari **cloud-backup dan device-transfer** |
| Log token | hanya nama kelas exception, tidak pernah objeknya — error parse `org.json` pada jalur refresh memuat potongan respons, dan untuk request itu responsnya adalah JWT |
| Ekspor komponen | kedua receiver `exported="false"`; debug receiver hanya di debug **dan** menolak kecuali debuggable |
| Hygiene dependensi | `junit` dan `org.json` hanya `testImplementation`, tidak pernah masuk APK |

---

## 12. Pengaturan

**Dua level:** daftar 10 kategori, lalu satu section terbuka. **Tombol
`Save settings` hanya ada di daftar kategori** — untuk menyimpan, pengguna harus
kembali dulu.

### Dua model persistensi berbeda

| Section | Cara disimpan |
|---|---|
| Appearance, Performance | **langsung** lewat `AppThemeController`, tanpa tombol save |
| Semua lainnya | buffered di `SettingsController`, ditulis `save()` yang memvalidasi dulu lalu `Navigator.pop(context, true)` |

Dashboard hanya reload preferensi dan memanggil `AlarmNotificationService.sync()`
kalau Settings mengembalikan `changed == true`.

### Section dan kontrol

| Section | Kontrol | Key | Tipe | Default | Berdampak |
|---|---|---|---|---|---|
| **Appearance** | Theme mode | `theme_mode` | String | dark | ✅ |
| | Accent colour (4 pilihan) | `theme_seed` | int | `0xFF35A968` | ✅ |
| **Monitoring** | Auto refresh telemetry | `auto_refresh` | bool | on | ✅ |
| | Refresh interval | `refresh_seconds` | int | 10 s | ✅ |
| **Energy alerts** | Enable energy alerts | `energy_alerts_enabled` | bool | on | ✅ |
| | Warn when battery SOC falls below | `low_soc_threshold` | int | 20 % | ✅ |
| | Warn when telemetry is older than | `stale_telemetry_minutes` | int | 10 mnt | ✅ |
| | Report a device as stopped after | `offline_telemetry_minutes` | int | 60 mnt | ✅ |
| | Daily production target | `daily_production_target_kwh` | **String** | — | ✅ |
| **Environment alerts** | Enable environment alerts | `environment_alerts_enabled` | bool | on | ✅ untuk alarm dan warna grid |
| | Temperature min / max | `environment_temp_min` / `_max` | String | 15 / 35 | ✅ |
| | Humidity min / max | `environment_humidity_min` / `_max` | String | 40 / 85 | ✅ |
| | Water TDS min / max | `environment_tds_min` / `_max` | String | 800 / — | ✅ |
| **Fish tank alerts** | Enable fish tank alerts | `fish_alerts_enabled` | bool | on | ✅ untuk alarm dan warna grid |
| | pH min / max | `fish_ph_min` / `_max` | String | 6 / 8.5 | ✅ |
| | Water temperature min / max | `fish_temp_min` / `_max` | String | 20 / 30 | ✅ |
| | Turbidity max (tanpa batas bawah, **tanpa default**) | `fish_turbidity_max` | String | **kosong** | ✅ |
| ~~Weather~~ | ~~OpenWeatherMap API key~~ | ~~`weather_api_key`~~ | — | — | **⛔ dihapus** |
| **CCTV source** | Hydroponics / Fish stream URL | `cctv_url` / `cctv_url_fish` (**secure storage**) | String | URL camera | ✅ |
| ~~Performance~~ | ~~Liquid glass blur~~ | ~~`performance_mode`~~ | — | — | **⛔ dihapus 1.7.0** — kunci tetap di SharedPreferences, tidak dibaca siapa pun |
| **Background checks** | 5 baris status + Check now + Battery settings | — | read-only | — | ✅ |
| **About** | App version | — | read-only | dari `pubspec.yaml` (`1.6.1+13`) | ✅ |
| **Account** | Logout | — | tombol | — | ✅ |

Default limit lingkungan: suhu 15–35 °C · kelembapan 40–85 % · TDS ≥ 800 ppm ·
stale 10 mnt · offline 60 mnt · SOC 20 %.
Default limit ikan: pH 6–8.5 · suhu air 20–30 °C. **Turbidity tidak punya default
sama sekali** — bukan karena batas bawahnya tidak bermakna, melainkan karena
sensor di perangkat uji membaca 2396 lalu 3000 NTU sementara panduan
akuakultur menyebut 100 NTU sudah keruh, jadi skalanya bukan skala yang
diasumsikan dan belum ada yang memastikan apa yang diukur. Field-nya kosong
dan tidak dipantau sampai user mengisinya; lihat §18.7.

### Validasi

**Menolak, tidak mengoreksi diam-diam** — pesan error pertama menghentikan save:

- `The production target must be a number greater than 0.`
- `{Label} must be a valid number.`
- `{Label} cannot be lower than {min}.` / `cannot be higher than {max}.`
- `The minimum {Label} limit must be lower than the maximum limit.` (sama juga ditolak)
- `Set at least one sensor limit to enable alerts.`
- `The CCTV URL must be HTTPS and use an approved host`

Batas sensor: suhu −40…100 °C, kelembapan 0…100 %, TDS ≥ 0 dengan **tanpa batas
atas** — konsisten dengan air tawar yang memang tidak punya plafon.

### Section Background checks

Lima baris read-only — `Scheduled` · `Credentials stored` · `Last check` ·
`Last outcome` · `Battery optimisation` — plus `Check now` dan pintasan `Battery
settings` (hanya tampil saat belum exempt). Statusnya **poll-once**, bukan live.
`Check now` melewati foreground stand-down dan menampilkan `Checking…` selama
tiga detik tetap, bukan sampai selesai. Di platform tanpa modul native, section
menampilkan satu kalimat: *"This platform has no native background alarm module,
so alarms are only reported while the app is open."*

---

## 13. Alarm history

| Aspek | Detail |
|---|---|
| Entry | ikon `Alarm History` di app bar |
| Sumber | **digabung**: SharedPreferences Dart (100) + store JSON native (100), kunci `id`, **Dart menang** bila bentrok, lalu diurutkan terbaru dulu |
| Refresh | **hanya saat layar dibuka.** Tidak ada pull-to-refresh, tidak ada auto-refresh |
| Baris | ikon tipe dalam lingkaran severity, pesan, timestamp, badge status, menu aksi |
| Expand | tap baris → `Value: N.NN` dan `Type: {label}` |
| Timestamp | `26 Sep 2026, 14:03` — waktu lokal, 24 jam |
| Filter | `All` · `Active` · `Acknowledged` · `Resolved` · `Critical` · `Warning` |
| Badge | `Resolved` hijau · `Acknowledged` biru · `Critical`/`Warning` warna severity |
| Aksi | `Acknowledge` · `Resolve` · `Reopen` — kondisional, sesuai status |
| Hapus | **hanya delete-all**, dialog konfirmasi, mengosongkan kedua store |

---

## 14. Tema dan visual

**Sistem permukaan soft-UI, opaque, satu arah cahaya.** Ini menggantikan
"liquid glass" yang ada sampai rilis 1.6.1. Alasan dan sejarah
keputusannya ada di `AGENTS.md` §"Soft-UI surfaces" dan di `CHANGELOG.md`
1.7.0.

| Fitur | Detail |
|---|---|
| Mode | System / Light / Dark, `ColorScheme.fromSeed` |
| Accent | 4 pilihan: EnerGrow green · Solar amber · Ocean cyan · Forest teal — **tidak pernah diubah otomatis** |
| Token layer | `dashboard/utils/design_tokens.dart`: `AppSurfaces`, `AppRadius`, `AppElevation`, `appDivider`, `AppMotion`. Satu-satunya tempat fill, radius, pasangan bayangan, dan durasi ditulis |
| Primitif | `AppCard` (+`inset` / `pressed`), `AppTile`, `AppBadge`, `AppDivider`, `DateStripChip`, `AppBackground` — semuanya di `widgets/liquid_glass.dart` (nama file tidak lagi akurat) |
| Fill | **Opaque.** Kartu = warna halaman. Kelembaman dibawa pasangan bayangan, bukan transparansi |
| Bayangan raised | **Tiga**, bukan dua: `contact` (offset 3, blur 6) + `ambient` (offset 9, blur 22) + `bounce` putih (offset −6, blur 14) |
| Tekan | **Dua state, bukan satu.** `pressed` = blok yang meng-*flatten*; `insetDeep` = teluk yang masuk lebih dalam. `AppCard.pressed` sudah ada sejak migrasi soft-UI dan **tidak ada pun call site yang memakainya** sampai 1.7.0 |
| Halaman light | **Mid-tone `#E1E7E4`**, bukan putih. Hampir putih membuat separuh bayangan tidak punya tempat untuk menjadi lebih terang, dan hasilnya terbaca Material, bukan soft-UI |
| Arah cahaya | Dari kiri-atas, seluruh aplikasi. `AppElevation.raised` / `.inset` |
| Radius | Satu skala: `card 16` · `pill 22` · `tile 14` · `inset 12` · `badge 10` · `bar 4`. Sebelumnya 12 nilai dari 3 sampai 28 |
| Border | Netral, sangat tipis — **bukan** accent. Border berwarna adalah tepi yang digambar, dan tepi yang digagradalah yang harus digantikan gaya ini |
| Tombol | `filledButtonTheme` diturunkan dari seed pengguna. Fill + label dihitung per mode, bukan diwarisi dari `ColorScheme.fromSeed` |
| Blur | **Tidak ada.** `BackdropFilter` dan orb gradient dihapus; section Performance dihapus |
| Rebuild granular | `Bound` dengan token. Punya test pertamanya di `test/bound_test.dart` (13 kasus) |
| Aksesibilitas | `faintColor` dan `statusOk/Warn/Bad` diukur terhadap permukaan opaque nyata; `test/color_helpers_test.dart` menjaga klaim itu |

**Aturan warna yang berlaku di seluruh aplikasi:**

1. **Warna tidak pernah berubah otomatis.** `metricColor` menerima `index` dan
   **sengaja mengabaikannya**. Rotasi hue pernah dicoba dan dibatalkan.
2. **Hijau bukan untuk kondisi baik.** Hanya pelanggaran yang diberi warna.
3. **Seri chart: triad merah/hijau/biru untuk grup multi-seri, accent untuk
   grup satu-seri.** Pengecualian yang didokumentasikan di `AGENTS.md` tetap berlaku untuk
   tegangan/arus/daya. Kartu satu-seri memakai accent karena tidak ada yang perlu
   dibedakan — dan warna merah di sana akan punya dua arti dalam satu app.
4. **Triad dipakai ulang, bukan diperluas.** Menambah hue baru untuk
   accommodate chip baru adalah kesalahan yang sama dengan rotasi hue, terbalik.

### Mengapa kedalaman ada di bayangan, bukan di fill

Ini aturan, bukan selera, dan angka-angkanya diukur.

`BoxShadow` hanya digambar **di luar** rect dekorasi, jadi mustahil ia
menggelapkan interior kartu — tempat semua caption di aplikasi digambar. Gradien
melintasi fill berbeda sifatnya dan sudah diukur lalu **ditolak**:

| Gradien fill | Light mode worst case |
|---|---|
| 0 % (kondisi sekarang) | 4.56:1 |
| 4 % | 4.15:1 |
| 10 % | 3.69:1 |
| 15 % | 3.34:1 |

AA 4.5. Maka deepen = properti bayangan.

**Light mode butuh dua putaran, dan pengukuran pikselnya yang jadi argumen.** Pada
`0x4D`/`0x33` separuh gelap hanya mencapai luminansi 219 terhadap halaman 229.5 —
turun 4,6 %, yang blur buat setipis itu sehingga separuh kerja dibawa bounce
dan kartu terbaca *terang*, bukan berdiri di permukaan. Sekarang `0x66`/`0x40`.
Dark mode tidak perlu padanan dan tidak diubah: sudah 17,6 terhadap 31,4, karena
bayangan hitam di permukaan hampir-hitam tetap gerakan relatif yang besar.

Terukur di perangkat (Xiaomi, kedua mode, via scanline brightness):

```
dark  : kartu 31.4 → contact 17.6, pulih ~35px   (turun 44 %)
light : halaman 229.5 → contact 213              (turun 7,2 %)
```

### Yang dihapus dan tidak ada lagi

- `LiquidGlassCard`, `AmbientBackground`, `GlassDateChip`, `GlassNavBar` (nama)
- `_AmbientOrbsPainter` dan tiga gradient radial — cat full-screen termahal di
  app, dan tidak di-gate oleh toggle Performance yang subjudulnya menjanjikan
  "flat cards, smoother scrolling"
- Section **Performance** di Settings, beserta `performanceMode` di
  `AppThemeController`. Kunci `performance_mode` **tetap** di SharedPreferences
  dan tidak dibaca siapa pun
- `filledButtonTheme` yang tidak pernah ada — itu sebabnya tombol di dark mode
  pernah menampilkan label putih di atas hijau terang (~1,5:1)

---

## 15. Data layer

### Device ThingsBoard

| Device | UUID | Key |
|---|---|---|
| Battery | `9465cf90-b264-11f1-9294-d92385142e6d` | `current` `power` `soc` `voltage` `cycles` `remain_capacity_ah` `full_capacity_ah` |
| PZEM | `af9531a0-ac44-11f1-841c-f5914d050259` | `voltage_ac` `voltage_dc` `current_ac` `current_dc` `power_ac` `power_dc` `energy_ac` `energy_dc` `frequency_ac` `pf_ac` |
| Sensor | `2e1b25c0-af33-11f1-8455-0717167ff6c3` | `humidity_dht` `lux` `tds_ppm` `temp_dht` `temp_ds18b20` |

Key set ini adalah **sumber tunggal** yang dipakai bersama oleh polling REST,
subscribe WebSocket, dan pemecah cache offline — supaya key yang ditambahkan ke
satu sisi tidak bisa diam-diam hilang dari sisi lain.

### Realtime

| Aspek | Detail |
|---|---|
| URL | `wss://dashboard.mbkm20262027.tech/api/ws/plugins/telemetry?token=<jwt>` |
| Topik | 3 subscribe `LATEST_TELEMETRY`, satu per device |
| Backoff reconnect | 1s → 2s → 4s → 8s, **di-cap 8s**, tanpa jitter; reset tiap handshake sukses |
| Payload | hanya `rawPoints.first`, dua bentuk diterima: map `{ts, value}` atau list `[ts, value]` |
| Ping | **tidak pernah dikirim** — ThingsBoard mengharapkan `{"28": "ping"}` |
| Interaksi dengan polling | **saling bebas** — tidak ada suppression, tidak ada budget bersama |

### Retry

`_fetchWithRetry` hanya untuk `fetchLatestTelemetry`: 3 retry, delay 1s / 2s / 4s.
401 dan 4xx selain 5xx **tidak** di-retry. `fetchHistoryForKeys` dan
`fetchDisplayName` **tidak punya retry sama sekali.**

### Cache offline

| Aspek | Detail |
|---|---|
| Key | `cached_telemetry` — satu peta rata semua device |
| Isi | `{latestValues, lastUpdate}` |
| Pecah | `splitCachedTelemetry` memetakan key ke device lewat key set yang sama |
| Dipakai | **hanya saat cold start** — kalau ada data live, cache tidak disentuh |
| Ditulis | hanya oleh polling REST, **tidak** oleh WebSocket |
| Best-effort | seluruh jalur tulis dan baca dibungkus `try/catch` yang menelan |

### Dependensi

| Paket | Dipakai untuk |
|---|---|
| `provider` | **tidak pernah di-import** |
| `fl_chart` | chart telemetry + bar chart laporan |
| `webview_flutter` | CCTV |
| ~~`geolocator`~~ | **⛔ dihapus** bersama integrasi OpenWeatherMap; `ACCESS_FINE_LOCATION` dan `ACCESS_COARSE_LOCATION` juga dicabut dari manifest |
| `local_auth` | login biometrik |
| `package_info_plus` | versi aplikasi di About |
| `flutter_secure_storage` | JWT ThingsBoard + URL CCTV |
| `flutter_local_notifications` | channel notifikasi alarm |
| `shared_preferences` | semua preferensi non-rahasia |
| `http` | REST ThingsBoard |
| `share_plus` | ekspor CSV |
| `intl` / `flutter_localizations` | format tanggal, locale |
| `path_provider` | **tidak dipakai** — CSV dibagikan dari memori, dan `path_provider_android` di-pin ke 2.2.23 agar tidak menarik NDK |
| `csv`, `geocoding`, `cupertino_icons` | dihapus, tidak pernah di-import |

### Startup

`runApp` → `AlarmNotificationService.initialize()` (request permission) →
`sync()` (push rules + token) → `SplashRouter` → cek token tersimpan → biometric
atau Login → `DashboardScreen.initState` → muat preferensi → set
foreground(true) → alarm sync → fetch pertama.

---

## 16. Integrasi

| Sistem | Status | Detail |
|---|---|---|
| ThingsBoard REST | ✅ | login, token refresh, timeseries, history |
| ThingsBoard WebSocket | ✅ | subscribe `LATEST_TELEMETRY` per device, backoff capped 8 s |
| ThingsBoard push | ❌ | butuh event rule + Push Gateway |
| FNN / XAI | ❌ | menunggu model & format output stabil |
| `share_plus` | ✅ | ekspor CSV energy report |
| `package_info_plus` | ✅ | versi di About, **tidak pernah hardcode** |
| `flutter_secure_storage` | ✅ | token ThingsBoard + URL CCTV |
| `local_auth` | ✅ | login biometrik |
| ~~`geolocator`~~ | **⛔** | tidak ada lagi; tidak ada permission lokasi di manifest |
| `webview_flutter` | ✅ | CCTV |

---

## 17. Yang bukan fitur / di luar cakupan

| Item | Alasan |
|---|---|
| Register / lupa password | dikelola di ThingsBoard |
| Multi-user / role | hanya jika kebutuhan operasional bertambah |
| Cache offline lengkap | hanya ada snapshot last-known, ditandai stale |
| Push dari server | butuh jalur server dulu |
| Alarm **tepat waktu** | butuh `SCHEDULE_EXACT_ALARM`, dan greenhouse tidak membutuhkannya |
| iOS / desktop / web | `AlarmBridge` jadi no-op di sana — background alarm adalah fitur Android saja, dan **`status` mengembalikan null** sehingga tidak ada yang menandainya |
| Widget / notifikasi iOS | tidak ada |
| Multi-chart | satu grafik per halaman |
| Table view energy report | hanya bar chart |

---

## 18. Celah yang diketahui

Semua **terverifikasi dengan membaca kode** pada 28 September 2026, dan
diperbarui pada 30 September 2026 setelah restyle soft-UI dan penambahan chart.
Dari versi sebelumnya, delapan celah fungsional sudah diperbaiki — tujuh pada
rilis 1.6.0, satu pada 1.6.1, dan §18.1 butir 2 pada 1.7.0 — dan satu terbukti
bukan celah; semuanya dikeluarkan dari daftar ini, bersama simbol-simbol mati
yang sudah dihapus. Riwayat perbaikannya ada di `CHANGELOG.md`. Yang belum
diverifikasi di perangkat ada di §18.5.

### 18.0 Celah yang dibuat oleh 1.7.0 dan masih terbuka

> **Yang ditutup 30 September malam (enam agent paralel, file terpisah):**
> butir 1 (sumbu Y pH), butir 2 (range picker), butir 3 (`FilledButton` — tetap),
> butir 5 (test kontras), plus **dua bug baru yang ditemukan di sesi ini** dan
> satu yang Found oleh agent: badge "Resolved" hijau, `AppTile` di bawah AA, dan
> margin halaman yang memotong bayangan. Detail di bawah.

> **Yang sudah tertutup sejak ditulis:** butir 5 (test kontras mengukur
> permukaan basi) dan butir 6 (`Bound` tanpa test) sudah diperbaiki. Butir 5
> adalah bug aksesibilitas yang menumpuk: ia bertahan dua commit karena
> daftar surface di test lebih terang dari yang dirender, jadi suite hijau
> sementara tiga warna di bawah AA. Butir 6 sudah tertutup di `0678be4`.

1. ~~**Sumbu Y pH terpatok ke nol.**~~ **Diperbaiki.** `minY` sekarang dihitung
   oleh `chartLowerBound`, dan grup yang indeks memakai flag `zeroAnchored: false`
   di `chart_groups.dart` — satu tempat yang sudah mendeklarasikan apa yang tiap
   halaman gambar. Batas bawahnya `minimum − 0,25 × rentang`, lalu di-*snap* ke
   kelipatan interval. Untuk jendela pH asli (6,37–7,75) hasilnya **sumbu 6,0–8,5**
   dengan gridline 6,0/6,5/7,0/7,5/8,0/8,5 — semua nilai pH nyata. Data mengisi
   55 % plot, sebelumnya 14 %.
   **Turbidity tidak dapat flag**, dan itu atas bukti bukan tebakan:
   `settings_validation_test.dart` merekam sensornya membaca 2396 NTU, dan itu
   justru alasan `maxAllowed`-nya `null`. NTU adalah besaran dengan nol nyata
   (air jernih), dan pembacanya ratusan–ribuan unit dari nol, jadi nol tidak
   memakan apa pun. Nol pH adalah angka di penggaris; nol turbidity adalah
   keadaan airnya.
2. ~~**Range picker kustom tidak terjangkau.**~~ **Diperbaiki, dan diagnosed
   ulang.** Klaim lamanya separuh benar: `DateStrip` masih punya tombol kalender
   28dp yang memanggil `_pickDateFromCalendar`, **tapi `DateStrip` hanya ada di
   Overview** — jadi di Power, Hydroponics dan Fish tidak ada cara sama sekali
   mengubah tanggal kecuali kembali ke Overview, memilih range, lalu swipe lagi.
   Sekarang ada kontrol di **app bar**, tersedia di keempat tab. Ikon berganti
   `calendar_month_outlined` ↔ `date_range_outlined` menurut apakah rentang
   aktif, dan tooltip dibangun dari `describeHistoryRange` yang sama dengan
   header chart, jadi tooltip dan header tidak bisa berbeda.
3. **`FilledButton` masih blok accent rata.** Bentuk dan kontrasnya sudah benar,
   tapi neumorphism yang ketat akan membuatnya raised atau inset. **Sengaja tidak
   diubah** — ia satu-satunya kontrol yang fill-nya adalah accent, dan
   membalikinya membuat accent berhenti terbaca sebagai aksi.
4. **Kotak hitam CCTV di light mode** masih menusuk di halaman neumorphic terang.
   `0xFF080D0A` adalah permukaan di belakang video, bukan permukaan bertema, dan
   belum diputuskan apa yang benar di sana.
5. ~~**Bayangan kanan kartu terpotong tepi layar.**~~ **Diperbaiki: margin
   halaman 16 → 24 dp.** Aritmetikanya: `BoxShadow` digambar sebagai mask blur
   `sigma = blurRadius / 2`, jadi contact (offset 3, blur 6) menjangkau 9 dp dan
   ambient (offset 9, blur 22) menjangkau **20 dp pada 1σ** — bagian yang benar-benar
   menggambar edge — dan 31 dp pada 2σ. Margin lama 16 dp, jadi ambient terpotong
   **tepat di tengah bagian yang penting**. 24 dp menampilkan seluruh 1σ dengan
   sisa 4 dp. 32 dp juga akan menampilkan ekor 2σ, tetapi memakan 16 dp dari plot
   chart di viewport 381 dp — tradeoff buruk untuk 3 % alpha.
   **Tidak** diperbaiki dengan mengecilkan `AppElevation.raised`: contact sudah
   muat dan Ambient-lah yang butuh ruang, dan kebalikannya mengubah ambient
   kembali menjadi contact kedua — persis "bevel CSS neumorphism 1990s" yang
   komentar file token sendiri ada untuk cegah. Margin navbar dinaikkan 14 → 24 dp
   pada saat yang sama; kalau tidak, pil akan menonjol 10 dp dari kolom konten
   dan setiap halaman akan memperlihatkan langkah di bawah.
6. **`energy_report_screen.dart` punya `_pickPeriod()` dengan nol call site.**
   Found oleh agent, di luar file yang dia miliki jadi tidak disentuh. Laporan
   energinya terkunci ke tanggal `_selectedDate` diinisialisasi, dengan **tidak
   ada cara mengubahnya** — dead code plus kontrol yang hilang, bukan sekadar
   pemindahan tempat. Lebih buruk daripada gap range picker di dashboard.

### 18.0b Dua bug yang ditemukan sesi ini, keduanya kelas yang sama

**`AppTile` di bawah WCAG AA, dan test yang mengukurnya salah mengecualikannya.**
`AppTile` mengisi dengan `AppSurfaces.track` = `#CFD6D2`, dan teks digambar di
atasnya. Terukur di light mode: `faintColor` 3,85 · `statusOk` 3,85 ·
`statusWarn` 3,87 · `statusBad` 3,86 · `statusAlert` 3,86 — semuanya di bawah
4,5. Yang besar (11,09:1) aman; yang gagal adalah **caption**-nya, persis yang
kecil dan abu-abu.

Yang membuatnya membingungkan adalah test-nya **sengaja mengecualikannya**, dengan
alasan tertulis: *"no text is ever drawn on one"*. Alasan itu **benar untuk progress bar
6–8 dp dan salah untuk `AppTile`**, kotak ~190 dp yang isinya teks.
`AppSurfaces.track` punya dua konsumen, dan pengecualian yang ditulis untuk satu
diterapkan ke keduanya. Pola yang sama persis dengan bug daftar surface kemarin.

Perbaikannya dua bagian, bukan satu: fill → `AppSurfaces.input` (4,99–5,02:1) **dan**
`AppElevation.inset` — karena tile sebelumnya **tidak punya inner shadow sama
sekali**, dan kesan inset-nya datang 100 % dari fill yang lebih gelap. Mengganti
fill tanpa shadow akan meratakan tile. Guard-nya diuji dengan membalik tiap
bagian secara terpisah: fill saja → 2 test gagal, shadow saja → 1 test gagal.

**Badge "Resolved" hijau melanggar aturan warna app sendiri.** Agent menemukan
argumen yang lebih kuat dari yang saya tulis di `AGENTS.md`: ini bukan soal hue,
tapi soal **tense**. `statusOk` adalah warna *status*, dan di layar itu hanya
berarti satu hal — kondisi yang ada **sekarang**. `Critical` / `Warning` /
`Acknowledged` memang kondisi hidup. `Resolved` adalah fakta tentang sebuah
baris di riwayat, dan menghijaukannya berarti mengatakan "tidak ada masalah
sekarang" satu baris di sebelah alarm merah yang masih hidup. Satu warna
melakukan dua pekerjaan yang berlawanan di satu layar.
Perbaikannya: hijau dihapus **dan pilnya**, karena wash `AppBadge` adalah bentuk
"ini punya status, lihat ini" — resolved adalah satu-satunya state di daftar itu
yang tidak bisa ditindaklanjuti user. Kata "Resolved" tetap ada, teks biasa.

### 18.1 Celah fungsional

1. ~~**Energi report memakai kebijakan perbandingan berbeda** dari Energy
   analytics.~~ **Perbaiki di 1.6.1.** `comparisonLabel` tidak punya ambang
   0,1 kWh, jadi `-100% from the previous period` muncul di sana untuk masalah
   yang sudah diperbaiki di kartu. Sekarang keduanya mengimpor
   `kMeaningfulEnergyKwh` dari `lib/utils/energy_comparison.dart`; sebelumnya itu
   dua literal di dua file, dan yang tidak pernah diperbaiki justru yang di
   report. Wording tetap berbeda per permukaan dan itu disengaja.
2. ~~**Halaman Hydroponics dan Fish tidak punya grafik.**~~ **Perbaiki.** Tiga
   hal menghalanginya sekaligus dan ketiganya harus dibongkar bersama:
   `HistoryKeys` adalah record tiga field (`voltage`/`current`/`power`) dan
   `TelemetryChartCard` menyusun kuncinya sebagai
   `'${prefix}_${suffixes[index]}'` dari `const suffixes` yang juga berisi tiga
   nama — **dua daftar fixed-length yang paralel**, dengan tidak ada yang
   memastikan keduanya tetap sepadan; `_prefixForPage` mengembalikan `null` untuk
   kedua halaman, dan prefix null berarti tidak ada request; dan
   `historyDeviceForPrefix` mengirim semua yang bukan battery ke PZEM, jadi
   request `ph` akan diterbitkan ke device yang tidak mempublikasikannya — itu
   sebab kedua greenhouse tidak pernah bisa di-chart, dan sebabnya ia akan
   gagal senyap. Sekarang ketiganya satu deklarasi di `chart_groups.dart`.
   Tujuh chart, diverifikasi di perangkat — lihat §3.
3. **Sensor turbidity membaca 2396 lalu 3000 NTU.** Untuk akuikultur, air jernih
   ada di bawah 30 NTU, jadi sensor ini jelas bukan pada skala yang diasumsikan —
   selisihnya sekitar 30 kali. Kemungkinan besar belum dikalibrasi atau satuannya
   berbeda, dan **belum ada yang memastikan apa yang diukur**. Konsekuensinya
   nyata: default lama 100 NTU pernah ter-arm dan menghasilkan "Turbidity too
   high: 3000.0 NTU (limit 100.0 NTU)" setiap menit tanpa pernah bisa bersih.
   Defaultnya sudah dihapus di 1.6.1 dan batas atasnya juga, jadi user bisa
   memilih sendiri begitu skalanya diketahui. Sisa masalahnya adalah pertanyaan
   perangkat keras, bukan kode.
4. **OpenWeatherMap sudah dihapus, jadi tidak ada lagi prakiraan ke depan.**
    `power_dc` dan `lux` adalah pengukuran, bukan prediksi. Yang hilang adalah
    suhu dan kelembapan luar, angin, tutupan awan, serta forecast. Kalau
    prakiraan dibutuhkan lagi, jalurnya bukan API cuaca melainkan backend push
    atau prediksi FNN-XAI — `PRD_PLTS_Monitoring_App.md` §7.4 sudah menandai arah
    itu, dan keduanya butuh jalur yang belum ada.

### 18.2 Kode mati / tidak terjangkau

| Simbol | Status |
|---|---|
| `ConnectionHealth.statusMessage` (label ketiga) | **tidak terjangkau** — banner hanya dirender di cabang `failed` atau `stale` |
| `_cctvKeepAlive` | tidak pernah ditulis, jadi CCTV tidak rebuild |
| `EnergyForecastResult`: `peakUsageAt`, `batteryStateOfCharge`, `sampleStart`, `sampleEnd`, `hasPeakUsage`, `hasBatteryEstimate` | dihitung, tidak pernah dipakai |

Belasan entri tabel versi sebelumnya sudah tertutup pada rilis 1.6.0 dan tidak
lagi dicatat di sini: `fetchHistory`, `clearCctvUrl` dan `launchAlarmId` kini
punya pemanggil; `SeriesStats.average`, `batteryCapacityKwh`,
`ExportButton.onShare`/`.isDark`, `recordReconnect`/`.reset`,
`updateAccessToken`, `isScheduled`, `configSavedAt`,
`_connectionStatusVisible`/`_connectionStatusTimer`, `solarProductionFactor`/
`solarIrradiance`, status `error`, `full_capacity_ah` decimals, dan baris
48+48 entri `/onecall` semuanya sudah dihapus dari kode.

### 18.3 Perilaku yang counter-intuitive

Bukan bug, tapi mudah disalahpahami:

- Timeout per-request kini bisa diturunkan dari `deadline` (`_timeoutFor` di
  `thingsboard_api.dart`), tapi tidak ada pemanggil production yang mengirim
  nilai selain null — sisa budget poll belum benar-benar di-*share* ke tiap
  request dan tetap berhenti di cap bawaan.
- `readDevices` tidak pernah mengembalikan null, jadi cabang
  `"session ended; background check disabled"` tidak terjangkau, dan refresh yang
  ditolak menghasilkan **dua** `finish()` dengan pesan kedua yang menang di
  `lastOutcome`.
- `_fetchWithRetry` melewati refresh token juga, jadi saat jaringan mati satu batch
  bisa menghasilkan 8 request per device.
- WebSocket tidak mengirim ping — koneksi idle yang tutup hanya ketahuan lewat
  `onDone`. (Tulisan cache offline-nya sudah ada sejak rilis 1.6.0.)
- Channel importance terkunci saat pembuatan, jadi `importance:` dari Dart tidak
  pernah berlaku untuk channel yang sudah ada.
- `AlarmStateStore.records()` mengurutkan dengan `optLong` pada nilai yang
  sebenarnya string ISO-8601, jadi pengurutannya no-op. Tidak terlihat oleh
  pengguna karena `AlarmHistoryService` mengurutkan ulang setelah merge.

### 18.4 Celah test

- `EnergySummaryCard` belum punya widget test — dan tiga regresi label di sesi
  27 Sep lolos seluruh gate tanpa ada satu pun widget test UI yang menangkapnya.
  `LivePowerCard` dan `MetricGrid` kini sudah punya.
- `SettingsScreen` tidak punya widget test; `settings_screen_test.dart` memeriksa
  9 dari 10 judul kategori, tanpa `Background checks`.
- `AlarmCheckRunner` tidak punya test JVM; butuh perangkat.
- `AlarmParityTest.kt` tidak punya kasus `lastUpdate == null` (hanya
  `readings: []`).
- `ChartBounds.maxY` tidak punya test untuk cabang `maximum <= 0`.
- ~~`test/color_helpers_test.dart` mengukur permukaan yang sudah tidak dipakai.~~
  Diperbaiki. Enam dari enam hex di list-nya basi, dan list basi itu lebih terang
  dari yang sebenarnya, jadi tiga warna di bawah AA lolos. Guard sekarang
  membacanya dari `AppSurfaces`.
- ~~Token bayangan belum punya test.~~ Diperbaiki:
  `test/design_tokens_test.dart`, 12 kasus, tiap guard diverifikasi dengan
  **mematahkan bug-nya di file token lalu memastikan test gagal** — one-axis
  shadow, single blur radius, pressed yang membesar, `insetDeep` yang dangkal,
  fill yang beda dari page. Kelimanya tertangkap. Guard yang tidak bisa gagal
  bukan guard.

### 18.5 Yang belum diverifikasi di perangkat

- **Nilai bertanda negatif di hero card.** Saat screenshot terakhir baterai standby
  0 W, jadi hanya `Standby` yang terlihat. Kodenya mencetak nilai mentah, tapi belum
  pernah dilihat di layar.
- **Layout di ukuran layar selain 1220×2712 @ density 520.** Tiga tempat paling
  mungkin pecah: bar tiga item power flow, legenda chart tiga seri, dua tile
  Energy analytics.
- **~~Tekan pada kontrol.~~ Terverifikasi 30 September 2026** untuk date strip
  chip dan navbar; `Pressable` belum dipasang di tombol `FilledButton` (lihat
  §18.0 butir 3) atau di kartu mana pun yang bisa ditekan. Yang benar-benar
  belum dilihat: **state `insetDeep`** pada well, karena butuh jari yang menahan
  di atas screenshot, dan `AppMotion.press` yang diukur — 150 ms turun, 120 ms
  naik, asimetri itu disengaja tapi belum pernah terasa di tangan.
- **~~State tekan navbar.~~ Terverifikasi** secara geometri, bukan visual: pair
  `pressed` dan `insetDeep` ada dan keduanya dipakai, tapi animasi itu sendiri
  baru satu siklus dan belum dinilai apakah terasa fisik atau hanya bergerak.
- **Stream CCTV end-to-end** di URL produksi, dan stream kedua `?src=cam2`.
- ~~**Halaman Fish dan Hydroponics belum pernah dibuka di perangkat.**~~
  **Terverifikasi 29 September 2026.** Keduanya dirender di Xiaomi 24090RA29G:
  Hydroponics menampilkan grid 3+2 (Temperature, Humidity, PV Temp, Light, TDS)
  lalu kartu CCTV; Fish menampilkan Water Quality 2×2 (pH, Temperature,
  Turbidity, Water Level) lalu kartu CCTV. Grid Environment menampilkan tag
  `1 out of range` dan hanya Humidity yang diberi border merah, sesuai aturan
  "hanya pelanggaran yang berwarna". Card CCTV menunjukkan `STANDBY` dan
  `Camera ready` tanpa autoplay, di kedua halaman. Yang **masih** belum terbukti:
  `itemCount: 6` hanya relevan bila halaman digulir sampai bawah — kedua
  screenshot menunjukkan konten penuh tanpa perlu menggulir.
- **Dua WebView bisa hidup bersamaan.** `CctvScreen` embedded tidak membuat
  `WebViewController` sampai `_startStream()` dipanggil, yaitu sampai user menekan
  tombol play — jadi halaman yang tidak dipakai tidak memakai bandwidth. Tapi kalau
  user memutar cam1 di Hydroponics lalu cam2 di Fish, keduanya tetap mounted
  karena `PageView` mempertahankan halaman tetangga. Dua WebView Android pada satu
  perangkat adalah beban memori yang nyata, dan ini belum diukur.
- **Pembacaan turbidity 2395 NTU** belum ditelusuri. Kalau sensor memang
  setelompong, halaman ini menampilkan angka yang salah secara absolut dan tidak
  ada yang bisa memperingatkaninya.
- **Energy report dengan data bulan penuh** — window selalu ~2 bulan dan ThingsBoard
  membatasi query agregat di bawah 31 hari.
- **ThingsBoard sekarang menjalankan 4 device, bukan 3.** App sudah menyebut semuanya, tapi hanya ketiga device lama yang pernah diverifikasi di perangkat.

### 18.6 Konvensi tanda sensor

BMS pada perangkat uji **berganti konvensi saat hardware diganti**, dan kedua
konvensi terukur pada 27 September 2026:

- **BMS sebelumnya:** halaman Battery menampilkan `Power -12.92 W` sementara SOC
  *naik* di 69 % — negatif berarti charging.
- **BMS sekarang:** `Power -22 W` sementara SOC *turun* — negatif berarti
  discharging.

Tanda itu sendiri tidak bisa memutuskan arah; hanya tren SOC yang bisa. Karena itu
pemetaan terpusat di `batteryChargeState` (`lib/utils/battery_sign.dart`) dan
dipin oleh `battery_sign_convention_test.dart` — persis karena klaim "negatif =
charging" pernah tertulis di dokumentasi ini dan bertahan setelah hardware yang
mendeskripsikannya sudah tidak ada.

Tiga aturan, semuanya sudah dilanggar sekali:

1. **Baca key `power` dari device. Jangan mengalikan `voltage * current`.** BMS
   mengirim ketiganya terpisah. Menghitung ulang menghasilkan nol persis saat
   `current` = 0.00 A, dan melenceng saat tegangan paket bukan nominal.
2. **Jangan balik tanda di call site.** Dua layar yang menampilkan angka berbeda
   untuk besaran yang sama lebih buruk daripada minus yang aneh kelihatan. Hero
   card mencetak angka mentah; labelnya yang membawa arah.
3. **Nol bukan arah.** Tiga status: charging, standby, discharging. Di bawah 1 W
   hasilnya noise, dan label dua-pilihan akan berkedip beberapa kali semenit.

Konvensi ini terukur di **satu** device per BMS. Ganti BMS tanpa mengukur ulang
akan membalik semua tampilan tanpa indikator error apa pun; caranya terdokumentasi
di komentar `battery_sign.dart` — amati tren SOC satu menit dengan tanda tetap,
lalu perbarui test dengan pengukuran di reason string-nya.

### 18.7 Default di Settings bukan limit yang tersimpan

Ditemukan di perangkat pada 29 September 2026, dan sudah diperbaiki — dicatat di
sini karena mekanismenya akan mendapat call site baru setiap rilis.

**Dua tahap, dan tahap kedua lebih serius dari yang pertama.** Yang pertama
ditemukan hanya dengan menghitung aturan: prefill di Settings terlihat identik
dengan nilai tersimpan, sehingga `Max (NTU) 100` bisa tampil sementara tidak ada
rule yang menegakkan apa pun (native mencatat 19 rule, bukan 20). Itu diperbaiki
dengan flag `minIsPrefill`/`maxIsPrefill`.

Yang kedua muncul setelah flag itu bekerja: begitu user **menyimpan**, batas 100
itu benar-benar ter-arm — dan sensor membaca 2396 lalu 3000 NTU, jadi hasilnya
`Turbidity too high: 3000.0 NTU (limit 100.0 NTU)` setiap menit, tanpa pernah
bisa bersih. **Memperbaiki penyesatan visual tidak memperbaiki defaultnya.**
lebih baik daripada menampilkan apa pun* adalah prinsip yang benar untuk sensor
yang **dikalibrasi**; di sini tidak ada angka yang bisa jujur, karena skala sensor
nya belum diketahui. Jadi default turbidity dihapus, batas atasnya juga, dan
user yang menentukan sendiri angkanya.

Pelajaran yang lebih luas: **mekanisme "default di-arm saat save" punya dua sisi
yang tidak selalu sama.** Untuk pH dan suhu air, prefill 6.5 dan 20 adalah tebakan
yang masuk akal. Untuk turbidity, prefill apa pun adalah tebakan tentang sensor
yang belum diukur. Penanda prefill membuat yang pertama jujur; hanya penghapusan
default yang membuat yang kedua jujur.

**Yang terjadi.** Fish tank alerts menampilkan `Max (NTU) 100` dengan sakelar
aktif, sementara turbidity terbaca 2396 NTU dan grid Fish tidak memberi warna
apa pun. Grid itu benar: tidak ada limit, jadi tidak ada yang dilanggar. Yang
berdusta adalah layar Settings. Field itu berisi **default yang belum
pernah disimpan** — `load()` mempertahankan prefill ketika key tidak ada, dan
prefill itu secara visual identik dengan nilai yang tersimpan. Native
konsekuennya mencatat `19 rule(s)`, bukan 20: batas turbidity memang tidak
pernah masuk ke preference store.

**Kenapa bisa terjadi.** Key `fish_turbidity_max` baru lahir di 1.6.0. Kalau
pengguna menyimpan Settings sebelum rilis itu, semua limit lain tersimpan dan
hanya yang baru ini yang tidak. Tidak ada yang rusak, tidak ada yang error, dan
tidak ada yang memberi tahu: field-nya diisi, sakelarnya nyala, dan grid-nya
diam.

**Perbaikannya** di `EnvRangeSetting`, bukan di parameter turbidity:
`minIsPrefill` / `maxIsPrefill` terisi true kalau ada default **dan** ada key,
`load()` membersihkannya hanya kalau key benar-benar ditemukan, `save()`
membersihkannya setelah berhasil. Di UI, angka prefill dirender miring-redup
dengan caption `Not saved yet`, dan tiap section menyebut jumlahnya sekali.
Pinned oleh `test/settings_prefill_test.dart`.

**Yang masih belum tertutup.** Kalau sebuah limit ditambahkan ke `defaults` dan
`*Ranges` tanpa satu baris pun, ia akan tampil sebagai prefill — itu memang
perilaku yang diinginkan sekarang. Risiko yang tersisa adalah limit yang
ditambahkan ke `AlarmThresholds.minFor`/`maxFor` tapi **tidak** punya
`defaultMin`/`defaultMax` di `SettingsController`: field-nya kosong, jadi tidak
ada penanda, dan tidak monitored — konsisten, tapi tidak terlihat. Menutup itu
berarti membuat daftar `minFor`/`maxFor` dan daftar field Settings diuji
saling cocok, dan itu belum ada.

---

## 19. Verifikasi

### Yang sudah terbukti di perangkat

| Yang | Cara dibuktikan |
|---|---|
| Modul alarm native berjalan | `logcat -s EnerGrowAlarmCheck:* EnerGrowAlarmSchedule:*` |
| Tidak ada notifikasi berulang | baris `(0 new)` pada pengecekan berikutnya |
| Dua trigger terpasang | `dumpsys alarm \| grep -A4 CHECK_ALARMS` |
| Stand down saat foreground | tidak ada `check started` saat app terbuka |
| Credential tidak bocor ke log | grep `logcat` untuk pola JWT |
| Release APK tidak punya debug receiver | `aapt2 dump xmltree app-release.apk --file AndroidManifest.xml \| grep AlarmDebugReceiver` → harus kosong |
| Alarm benar-benar sampai ke pengguna | notifikasi di lock screen, teks cocok dengan banner |
| Elemen benar-benar menggambar | **ukuran brightness piksel di screenshot** — bar yang "ada di kodenya" ternyata punya brightness sama dengan background |

### Gate wajib sebelum commit

```bash
flutter analyze                                 # harus: No issues found!
flutter test                                    # 372 test, jalankan PER-FILE (OOM)
cd android && ./gradlew :app:testDebugUnitTest  # 11 test
```

### Test yang menjadi regression guard

| Test | Pin yang dipegang |
|---|---|
| `cctv_test.dart` | allowlist host |
| `chart_bounds_test.dart` | pembulatan `niceStep` / `niceTimeStep` |
| `dashboard_helpers_test.dart` | `describeHistoryRange` harus sepakat dengan `historyTimeWindow` |
| `energy_forecast_service_test.dart` | konvensi tanda discharge baterai |
| `alarm_rules_test.dart` | device tanpa pembacaan bukan stale; TDS tanpa batas atas |
| `alarm_parity_test.dart` + `AlarmParityTest.kt` | evaluator Dart == evaluator Kotlin |
| `settings_validation_test.dart` | batas per sensor, termasuk TDS tanpa plafon |
| `settings_save_regression_test.dart` | save menulis semua key; field kosong menyimpan null, bukan default; error save terlihat |
| `alarm_path_thresholds_to_rules_test.dart` | threshold Settings → rules → JSON native, kelompok Environment dan Fish |
| `metric_grid_test.dart` | `showGridColors` mengunci tag breach; tag `Stale data` tetap tampil saat alerts mati |
| `live_power_card_test.dart` | konvensi tanda BMS: negatif = discharging, positif = charging |
| `color_helpers_test.dart` | tidak ada rotasi hue otomatis; setiap warna teks lolos AA pada permukaan nyata |
| `thingsboard_api_test.dart` | token/session, WebSocket URI, key set, cache offline |
| `thingsboard_realtime_service_test.dart` | lifecycle service, konfigurasi device, model telemetry |
