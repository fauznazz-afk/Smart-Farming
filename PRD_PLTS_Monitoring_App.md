# PRD — EnerGrow: Aplikasi Mobile Monitoring PLTS

**Project:** FNN-XAI-IoT — Smart Farming Energy Monitoring
**Platform:** Flutter (target utama Android)
**Versi aplikasi saat ini:** 1.4.0 (build 10; sudah diterbitkan, tag `v1.4.0`)
**Versi dokumen:** 1.4
**Status:** Rilis 1.4.0 terbit 26 September 2026. Build pertamanya dari Linux,
tanpa NDK dan CMake. Sesi 27 September 2026 thereafter: modul alarm background
ditulis ulang menjadi Kotlin native, antarmuka diratakan ke bahasa Inggris
sepenuhnya, dan UI dashboard disederhanakan. Detail di `progress.md` §10.5 dan
§10.7.

---

## 1. Ringkasan

EnerGrow adalah aplikasi mobile untuk memantau sistem energi hybrid di lahan pertanian/hidroponik. Aplikasi mengambil telemetry dari tiga perangkat ThingsBoard: baterai, PZEM (PV dan AC), serta sensor lingkungan. Aplikasi juga menyediakan histori grafik, ringkasan energi, laporan, pengaturan, dan halaman CCTV.

Aplikasi merupakan client untuk infrastruktur IoT yang sudah berjalan. Backend utama adalah ThingsBoard CE; aplikasi tidak memiliki backend bisnis tersendiri. Dokumen ini mencatat perilaku produk pada kode 1.4.0 dan pekerjaan lanjutan yang disarankan.

## 2. Pengguna dan tujuan

Pengguna utama adalah pengelola lahan yang perlu melihat kondisi energi dari ponsel tanpa membuka dashboard web ThingsBoard.

Tujuan produk:

- Memperlihatkan telemetry terbaru dari Battery, PV, AC, dan lingkungan.
- Membantu pengguna melihat perubahan historis serta ringkasan pemakaian/produksi energi.
- Menjelaskan kapan telemetry terakhir diterima dan memberi peringatan lokal yang relevan.
- Menyediakan akses sesi ThingsBoard yang praktis dengan logout yang jelas.

## 3. Infrastruktur dan batasan

| Komponen | Peran/status |
|---|---|
| ESP32 dan sensor | Mengirim data melalui ESP-NOW/MQTT; laju dan kualitas data bergantung pada perangkat/firmware. |
| Mosquitto | Broker MQTT pada infrastruktur Orange Pi. |
| ThingsBoard CE | Backend utama untuk autentikasi, REST API, dan penyimpanan/akses telemetry. |
| PostgreSQL | Penyimpanan yang dikelola ThingsBoard. |
| Orange Pi + Cloudflare Tunnel | Hosting self-hosted; ketersediaan aplikasi bergantung pada perangkat, jaringan, dan tunnel. |
| go2rtc/CCTV | Aplikasi memiliki halaman WebView untuk URL CCTV HTTPS yang diizinkan. Ketersediaan live stream tetap bergantung pada konfigurasi layanan CCTV. |

Aplikasi mengakses ThingsBoard melalui HTTPS. Tidak ada backend/API kustom, push service, atau subscription telemetry WebSocket di versi ini.

## 4. Fitur dan status implementasi versi 1.4.0

### 4.1 Autentikasi dan sesi

**Status: Diimplementasikan.**

- Login menggunakan username dan password akun ThingsBoard.
- JWT dan refresh token disimpan menggunakan secure storage. Ada migrasi token lama dari SharedPreferences.
- Sesi tersimpan dimuat saat aplikasi dibuka. Jika ada token tersimpan, pengguna dapat membuka sesi dengan biometrik atau memilih login ThingsBoard.
- Request API mencoba memperbarui access token menggunakan refresh token. Jika sesi ditolak, dashboard menghapus sesi dan mengarahkan pengguna ke Login.
- Logout manual tersedia melalui Settings.
- Tidak ada Register atau Lupa Password; akun dibuat/dikelola di ThingsBoard.

### 4.2 Dashboard dan telemetry

**Status: Diimplementasikan dengan susunan UI berbeda dari konsep awal PRD.**

- Navigasi utama berisi Overview, PV, AC, Battery, CCTV, dan Settings.
- Overview merangkum status energi dan lingkungan; halaman PV, AC, dan Battery menampilkan metrik perangkat serta grafik.
- Data Battery, PZEM (PV/AC), dan sensor lingkungan diminta dari ThingsBoard REST API.
- Polling otomatis aktif secara default setiap 10 detik. Pengguna dapat mengubah interval atau mematikannya di Settings.
- Pull-to-refresh memperbarui telemetry dan histori halaman aktif.
- Dashboard menghindari rebuild saat hasil telemetry tidak berubah. Perubahan
  telemetri diumumkan lewat penghitung revisi, bukan `setState`, agar pohon
  widget tidak dibangun ulang.
- Tampilan mendukung tema gelap dan terang serta pilihan warna aksen.
- **Overview merangkum sebagai strip verdict, bukan sebagai barisan angka.** Strip
  itu mencetak satu verdict untuk baterai, satu untuk jaringan AC, dan jumlah
  alarm aktif, jadi pertanyaannya "apakah aman" dijawab tanpa membaca angka.
- **Hero card menampilkan arah daya**, bukan hanya besarannya: solar, beban
  rumah, dan baterai, beserta proporsi beban terhadap produksi solar. Tiga
  capsule shortcut (PV output, beban AC, isi baterai) dihapus karena ketiganya
  sudah ada di kartu yang sama, dan sebagai navigasi hanya mengulang bottom bar.
- **Alarm banner hanya muncul di halaman Overview.** Pelanggaran ambang adalah
  fakta tentang kebun, bukan tentang tab yang sedang dibuka.
- Antarmuka sepenuhnya berbahasa Inggris.

**Perbedaan dari konsep awal:** PRD versi 1.0 mengusulkan tiga card grouped-list di satu dashboard. Implementasi saat ini memakai Overview dan halaman/tab detail terpisah. Bentuk navigasi tab ini menjadi baseline produk.

### 4.3 Grafik historis

**Status: Diimplementasikan.**

- Grafik telemetry tersedia pada halaman PV, AC, dan Battery.
- Data dibaca melalui endpoint time-series ThingsBoard dengan agregasi AVG.
- Tampilan grafik mengikuti tanggal yang dipilih; tersedia pemilih tanggal untuk meninjau hari lain.
- Rentang dan resolusi mengikuti implementasi query aplikasi. Ketersediaan titik data bergantung pada telemetry dan retensi ThingsBoard.
- **Tiga seri digambar bersama: tegangan, arus, dan daya, dengan warna merah, hijau,
  dan biru, garis solid, dan sumbu Y yang dinamis.** Sumbu Y berisi nilai
  sebenarnya. Menormalkan tiap seri ke 0-100% rentangnya sendiri supaya ketiganya
  sama-sama terlihat pernah dicoba dan ditolak: pembaca yang melihat
  "0%, 50%, 100%" harus mencari tiga skala berbeda di legenda, sementara sumbu
  mentah bisa langsung dibaca. Pada halaman AC dayanya dua orde di atas arus, dan
  trace yang rata di sana itu jujur, bukan rusak.
- Di bawah plot, tiap seri menampilkan latest, average, min, dan max, masing-masing
  satu baris agar tidak terpotong.

### 4.4 Ringkasan dan laporan energi

**Status: Diimplementasikan.**

- Overview menampilkan estimasi produksi PV dan konsumsi AC untuk periode harian atau tujuh hari, dengan perbandingan periode sebelumnya.
- Halaman laporan menyediakan analisis energi pada rentang harian/bulanan dan ekspor CSV.
- Perhitungan merupakan estimasi berbasis histori daya; hasil bergantung pada kelengkapan dan interval telemetry.
- Laporan memperbarui datanya secara berkala saat halaman laporan terbuka dan mendukung refresh manual.

### 4.5 Peringatan lokal dan data stale

**Status: Diimplementasikan secara lokal.**

- Peringatan lokal muncul untuk SOC baterai rendah dan telemetry yang melewati ambang usia.
- Pengguna dapat mengaktifkan/menonaktifkan peringatan dan mengatur ambang SOC serta usia telemetry di Settings.
- Kartu telemetry menampilkan usia update saat stale.
- Pengguna dapat menentukan batas minimum dan/atau maksimum suhu lingkungan, kelembapan, dan TDS air. Batas kosong diabaikan; alert lingkungan hanya mengevaluasi data sensor yang masih segar.
- Pengecekan juga berjalan saat aplikasi ditutup (Android). Modul Kotlin native dibaca lewat `AlarmManager`, sehingga tidak ada Flutter engine yang dibangun di latar belakang; satu pengecekan hanya handful MB RAM dan sekitar 0,45 detik, bukan puluhan MB dan beberapa detik seperti isolate Flutter. Pengecekan dijadwalkan **setiap satu menit** dan mengirim notifikasi lokal, sehingga alarm tidak perlu membuka aplikasi. Cakupannya sama dengan alert dalam aplikasi: SOC rendah, telemetry stale, batas suhu, kelembapan, dan TDS.
- Pengecekan **berhenti berdiri** (stand down) selama aplikasi terbuka di depan, karena dashboard sudah mengevaluasi aturan yang sama setiap 10 detik; melanjutkan polling ThingsBoard dua kali hanya pekerjaan ganda dan berisiko kedua sisi berbeda pendapat tentang alarm aktif.
- Tombol "Check now" di Settings menjalankan satu pengecekan tanpa hormat pada foreground stand-down, karena itulah yang dimaksud pengguna saat menekan.
- Bagian "Background checks" di Settings menampilkan apakah pengecekan terpasang, apakah kredensial tersimpan, kapan terakhir berjalan, dan apa hasilnya, plus pintasan ke layar optimasi baterai. Bagian ini ada karena kegagalan ini mustahil terlihat: alarm yang hilang terlihat persis seperti "tidak ada yang perlu dilaporkan".
- **Push notification dari server belum tersedia.** Yang ada adalah pengecekan lokal terjadwal, yang hanya bisa melaporkan kondisi yang sudah tercatat di ThingsBoard.

Ambang stale yang disimpan pengguna dipakai untuk evaluasi peringatan, label pada kartu telemetry, dan ringkasan Overview. Aturan yang sama dipakai oleh aplikasi dan oleh pengecekan latar belakang, sehingga mengubah ambang di Settings langsung mengubah keduanya.

Catatan: karena pengecekan terjadwal memakai `setInexactRepeating`, Android dapat menundanya, kadang lama, saat perangkat dalam mode hemat baterai. Keterlambatan ini disengaja. Alarm persis memerlukan izin `SCHEDULE_EXACT_ALARM` yang harus diberikan pengguna lewat pengaturan sistem, dan `USE_EXACT_ALARM` hanya untuk aplikasi jam dan kalender.

Karena itu ada **dua** trigger, bukan satu: satu `setInexactRepeating` untuk ritme, dan satu `setAndAllowWhileIdle` satu kali yang di-arm ulang setiap kali dijalankan. Alarm berulang adalah hal pertama yang dibuang vendor power manager — di perangkat uji MIUI/HyperOS, alarm berulang berjalan enam kali lalu hilang diam-diam dari `dumpsys alarm`, dengan `com.miui.powerkeeper` terlihat di output yang sama. Yang kedua bebas dari Doze, jadi keduanya bertahan terhadap sebagian besar perilaku perangkat nyata. Konsekuensinya, pengecekan membaca **umur telemetry**, bukan mengasumsikan satu tick sudah terjadi.

### 4.6 CCTV

**Status: Integrasi UI diimplementasikan; ketersediaan stream perlu diverifikasi di lingkungan deploy.**

- CCTV tersedia sebagai halaman/tab tersendiri dan dimulai dalam keadaan standby.
- Pengguna menekan Play untuk memuat halaman stream melalui WebView; tersedia status, stop, retry, dan reload.
- URL harus HTTPS dan memakai host yang diizinkan.
- Tombol layar penuh membuka stream dalam orientasi landscape dengan kontrol untuk keluar. CCTV bukan card pada Overview.

### 4.7 Pengaturan dan tampilan

**Status: Diimplementasikan.**

- Preferensi tema (System/Light/Dark), warna aksen, polling, peringatan energi/lingkungan, ambang stale/SOC, batas sensor, dan URL CCTV disimpan lokal.
- Batas lingkungan punya default yang bekerja: suhu 15-35 °C, kelembapan 40-85 %,
  TDS >= 800 ppm, dan alert lingkungan aktif secara default.
- Pengguna dapat melihat versi aplikasi yang dibaca dari metadata paket, serta melakukan logout.
- Pengaturan mengoptimalkan efek visual untuk performa.

## 5. Kebutuhan nonfungsional

| Aspek | Baseline/target |
|---|---|
| Keamanan transport | HTTPS untuk ThingsBoard dan URL CCTV yang diizinkan. Token sesi disimpan dengan secure storage. |
| Kinerja | Polling tidak boleh menumpuk request; UI menghindari rebuild ketika data tidak berubah. Satu cold launch APK 1.2.3 pada perangkat uji tercatat 930 ms; perlu pengukuran berulang dan perangkat lain untuk memastikan konsistensi target <2 detik. |
| Responsif | Pada satu perangkat Android 1220×2712, halaman Overview dapat digulir dan konten terlihat. Ukuran layar lain belum diuji. |
| Beban latar belakang | Satu pengecekan alarm native sekitar 0,45 detik dan handful MB RAM, tanpa membangun Flutter engine. Pengecekan berhenti berdiri selama aplikasi terbuka, jadi tidak ada polling ganda. |
| Ketersediaan | Tidak ada SLA formal; bergantung pada Orange Pi, ThingsBoard, tunnel, jaringan, dan perangkat IoT. |
| Akurasi | Nilai dan estimasi hanya seakurat telemetry yang dikirim perangkat dan histori yang tersedia. |

## 6. Di luar cakupan versi saat ini

- Push notification dari server. (Pengecekan lokal terjadwal saat aplikasi tertutup sudah ada sejak modul alarm diganti ke native; lihat §4.5. Yang belum ada adalah alert berbasis event yang dikirim server.)
- Mode offline dengan cache telemetry lengkap.
- Subscription WebSocket untuk menggantikan polling REST. (WebSocket realtime sudah ada sejak 1.3.1, untuk pembaruan selama aplikasi terbuka.)
- Register dan reset password dari aplikasi.
- Pengelolaan banyak pengguna/role di aplikasi.
- Prediksi FNN dan penjelasan XAI di aplikasi.
- Backend/API kustom.
- Status kesehatan stream yang diverifikasi end-to-end.

## 7. Saran pengembangan

> Inventaris fitur yang benar-benar ada, beserta celah yang diketahui, ada di
> FEATURE.md. Dokumen ini hanya membahas arah produk, bukan inventaris.

Diurutkan menurut apa yang paling mungkin menyesatkan kalau ditunda, bukan
menurut apa yang paling menarik untuk dikerjakan. Catatan teknis yang lebih
panjang ada di `progress.md` §10.8.

### 7.1 Yang paling murah dan paling mencegah kerusakan berulang

1. **Tutup celah test yang masih ada.** `energy_report_service.dart` dan
   `alarm_notification_service.dart` baru punya test untuk helper-nya; yang belum
   tercover adalah pemanggilan method channel dan lifecycle scheduling.
   `weather_card.dart` (331 baris) dan `energy_report/widgets/chart_card.dart`
   (297 baris) belum pernah di-refactor dan belum punya test widget.
   **Prioritas khusus: widget test untuk `LivePowerCard` dan `EnvironmentGrid`.**
   Pada sesi 27 September 2026, tiga regresi label ditemukan **hanya dengan melihat
   layar** — `PV Output` yang muncul tiga kali di satu kartu, satuan yang
   terpotong jadi `109....`, dan label yang ellipsised hanya saat verdict muncul.
   Semuanya lolos `flutter analyze`, lolos build, dan lolos test yang ada.
2. **Kunci konvensi tanda baterai dengan test, bukan dengan catatan.** BMS ini
   dilaporkan minus saat charging, terukur di satu perangkat. Belum diketahui
   apakah device yang sama memakai konvensi yang sama, dan apakah
   `energy_forecast_service.dart` yang memakai `.abs()` sudah benar untuk semua
   kasus. Ganti BMS tanpa test ini akan membalik semua tampilan tanpa satu pun
   indikator yang merah.

### 7.2 Verifikasi yang belum pernah dilakukan

3. **Backfill `offline_*` di riwayat alarm.** `AlarmRule.kt` punya
   `AlarmComparison.offline` dan Dart punya tipe untuknya, tapi belum jelas apakah
   record itu pernah benar-benar tertulis di store native atau hanya muncul di
   banner. Kalau belum, alarm "perangkat berhenti" — yang justru paling perlu
   dibuktikan ke pengguna — tidak pernah muncul di riwayat.
4. **Ukur layout di lebih dari satu ukuran layar.** Semua verifikasi optimist ini
   di satu Xiaomi 24090RA29G, 1220x2712, density 520. Tiga tempat yang paling
   mungkin pecah di layar kecil: bar tiga item power flow di hero card, legenda
   chart tiga seri, dan dua tile Energy analytics. `flutter test` tidak bisa
   menangkap ini.

### 7.3 Yang perlu keputusan, bukan sekadar pengerjaan

5. **`package_info_plus` / `share_plus` / `flutter_secure_storage`.** Coordinated
   upgrade, sudah dicoba dan gagal karena konflik `win32` (lihat `progress.md`
   §10.6b). Jangan dicoba piecemeal, dan jangan sebelum butir 1 dan 2 selesai
   karena keduanya menyentuh penyimpanan sesi.
6. **Cold start.** Target `<2 detik` belum diukur ulang sejak 1.2.3, dan
   pengukuran itu tunggal di satu perangkat.

### 7.4 Yang perlu ada jalurnya lebih dulu

7. **Push notification dari server** belum punya jalur. Alert lokal yang ada hanya
   bisa melaporkan kondisi yang sudah tercatat di ThingsBoard, dan hanya dengan
   aplikasi yang sudah pernah dibuka setidaknya sekali. Sumber aturan dan layanan
   pengiriman harus ditentukan dulu.
8. **Platform kedua.** `AlarmBridge` melihat `MissingPluginException`, latch
   `isUnavailable`, dan jadi no-op di iOS, desktop, dan web. Aman, tapi berarti
   background alarm adalah fitur Android tanpa padanan, dan `status` untuk
   diagnostik mengembalikan null di sana. Kalau aplikasi direncanakan ship di
   platform kedua, ketidakfungsiannya harus disurface di UI lebih dulu, bukan
   diam-diam tidak berfungsi.

## 8. Kriteria penerimaan baseline

- Login ThingsBoard berhasil; sesi bertahan setelah aplikasi ditutup dan dibuka kembali.
- Token yang ditolak menghapus sesi dan mengarahkan pengguna ke Login.
- Overview dan halaman PV, AC, Battery menampilkan data sesuai device/key ThingsBoard yang dikonfigurasi.
- Polling default 10 detik dan pull-to-refresh berfungsi; interval dapat diubah di Settings.
- Grafik historis menampilkan data yang tersedia untuk tanggal terpilih.
- Pengguna dapat melakukan logout manual.
- Stale telemetry dan alert SOC rendah ditampilkan saat aplikasi berjalan sesuai konfigurasi.
- Alert suhu lingkungan, kelembapan, dan TDS mengikuti batas yang diisi pengguna dan hanya menggunakan telemetry segar.
- Status ThingsBoard membedakan fetch gagal dari telemetry perangkat yang stale.
- Ringkasan/laporan energi menyatakan hasilnya sebagai estimasi dari data histori.
- Halaman CCTV memvalidasi URL, menyediakan kontrol playback dan fullscreen, serta menampilkan kegagalan stream dengan jelas.
- APK release tersedia sebagai artefak build. Instalasi dan uji pada perangkat fisik harus dicatat terpisah; keberadaan file APK saja bukan bukti uji perangkat.

**Ditambahkan 27 September 2026, setelah sesi alarm native dan perapian UI:**

- Satu notifikasi alarm muncul saat aplikasi ditutup, dengan teks yang persis sama
  dengan yang dihitung oleh evaluator di dalam aplikasi.
- Alarm yang masih berlaku tidak mengulang notifikasi pada pengecekan berikutnya.
  Controleksinya bukan "notifikasi kedua tidak muncul dalam 24 jam", melainkan set
  id alarm aktif yang dibagi.
- Teks pesan alarm identik antara `formatAlarmMessage` (Dart) dan
  `AlarmMessageFormat.kt`, dipin oleh fixture yang sama untuk kedua sisi.
- Ambang yang diubah di Settings mengubah perilaku notifikasi latar belakang pada
  tick berikutnya, bukan hanya tampilan di dalam aplikasi.
- `dumpsys alarm` menunjukkan **dua** trigger, bukan satu.
- Seluruh antarmuka berbahasa Inggris, termasuk chrome date range picker dan
  nama file CSV yang muncul di share sheet.
- Nilai baterai ditampilkan dengan tanda yang sama seperti yang dilaporkan device,
  sehingga halaman Battery dan hero card tidak mengukur besaran yang sama dengan
  angka berbeda.
- Banner alarm menyusut dengan animasi, bukan hilang dalam satu frame.

## 9. Roadmap

- **Prioritas perbaikan:** widget test untuk `LivePowerCard` dan `EnvironmentGrid`,
  kunci konvensi tanda baterai dengan test, backfill `offline_*` di riwayat, dan
  ukur layout di lebih dari satu ukuran layar. Semuanya murah, dan ketiganya
  berasal dari kegagalan yang lolos `flutter analyze`, build, dan test yang ada.
- **Peningkatan monitoring:** pertimbangkan WebSocket, cache ringan untuk tampilan
  terakhir, dan push notification berbasis server.
- **Riset produk:** integrasi hasil FNN-XAI setelah model dan format output stabil.
- **Skala pengguna:** evaluasi role/multi-user dan backend perantara hanya jika
  kebutuhan operasional bertambah.

## 10. Hasil verifikasi

### 10.1 Rilis 1.2.3 (historis)

- `flutter analyze`: lulus tanpa temuan.
- `flutter test`: lulus (2 test).
- APK release 1.2.3 build 7 berhasil dibuat.
- APK release 1.2.3 build 7 berhasil dipasang dan dibuka pada perangkat Android
  24090RA29G dengan resolusi 1220x2712. Package Manager melaporkan versionName
  1.2.3 dan versionCode 7.
- Layar Login tampil normal setelah instalasi baru. Sesi dan preferensi lokal lama
  terhapus saat paket sebelumnya di-uninstall; login ThingsBoard belum dilakukan.
- Cold launch awal APK 1.2.3 tercatat 930 ms (`adb am start -W`), memenuhi target
  <2 detik pada pengukuran tunggal ini.
- Pengukuran sebelum penggantian APK pada 1.2.2 sempat mencatat 2417-3339 ms; hasil
  lama itu tidak mewakili build 1.2.3 dan menunjukkan hasil startup perlu diuji
  berulang.

### 10.2 1.4.0 dan sesi 27 September 2026

**Otomatis:**

- `flutter analyze`: lulus tanpa temuan.
- `flutter test`: lulus, 227 test.
- `./gradlew :app:testDebugUnitTest`: lulus, 11 unit test (parity alarm dan host
  allowlist).

**Di perangkat — Xiaomi 24090RA29G, Android 16, 1220x2712, density 520:**

- Login ThingsBoard berhasil, sesi bertahan setelah aplikasi ditutup dan dibuka
  kembali.
- Modul alarm native terbukti berjalan: satu checks lithiumional berjalan dengan
  aplikasi ditutup, dan notifikasi muncul di lock screen dengan teks
  `Kelembapan tinggi: 91.0 % (batas 85.0 %)` pada build pertama, sebelum antarmuka
  diratakan ke bahasa Inggris.
- Pengecekan berulang pada menit berikutnya melaporkan `0 new`, jadi set alarm aktif
  mencegah notifikasi berulang seperti yang dimaksud.
- `dumpsys alarm` menunjukkan kedua trigger: `repeatInterval=60000` untuk ritme dan
  `flags=0x8` (`ALLOW_WHILE_IDLE`) untuk cadangan.
- 13 aturan ter-push ke modul native, dan ambang yang diubah di Settings terlihat
  dipakai oleh kedua sisi.
- APK release terpasang dan dibangun ulang beberapa kali dalam sesi ini; setiap
  perubahan UI diverifikasi lewat screenshot.

**Yang diverifikasi lewat screenshot, bukan lewat log:** seluruh perapian UI sesi
ini. Empat dari temuan tersebut adalah kegagalan senyap — tidak ada exception,
`flutter analyze` bersih, build sukses, test lulus — dan tidak satu pun bisa
dilihat tanpa menjalankan aplikasi. Dua di antaranya bahkan tidak terlihat
dengan mata pada ukuran screenshot penuh; bar split power flow baru
ketahuan setelah brightness tiap baris piksel diukur.

**Yang belum diverifikasi:**

- Tampilan tanda minus pada hero card. Saat verifikasi terakhir baterai sedang
  standby pada 0 W, jadi hanya label `Standby` yang terlihat. Kodenya mencetak
  nilai mentah dari device, dan ini akan terlihat begitu pack masuk charging.
- Layout pada ukuran layar selain 1220x2712.
- Stream CCTV end-to-end di URL produksi.
- Cold start pada build terkini; pengukuran terakhir masih dari 1.2.3.

### 10.3 Konvensi tanda baterai, terukur

BMS pada perangkat uji melaporkan **arus dan daya negatif saat charging**: halaman
Battery menampilkan `Current -0.97 A` dan `Power -12.92 W` sementara state of
charge naik di 69%. Ini berlawanan dengan asumsi yang paling umum, dan sudah
menyebabkan dua kesalahan terpisah yang keduanya terlihat seperti perbaikan.
Rinciannya di `progress.md` §10.7 butir 7, aturannya di `AGENTS.md`.
