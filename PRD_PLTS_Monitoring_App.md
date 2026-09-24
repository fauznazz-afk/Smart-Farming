# PRD — EnerGrow: Aplikasi Mobile Monitoring PLTS

**Project:** FNN-XAI-IoT — Smart Farming Energy Monitoring
**Platform:** Flutter (target utama Android)
**Versi aplikasi saat ini:** 1.3.0 (build 8; belum dirilis)
**Versi dokumen:** 1.2
**Status:** Implementasi lokal per 24 September 2026; rilis 1.3.0 belum diterbitkan

---

## 1. Ringkasan

EnerGrow adalah aplikasi mobile untuk memantau sistem energi hybrid di lahan pertanian/hidroponik. Aplikasi mengambil telemetry dari tiga perangkat ThingsBoard: baterai, PZEM (PV dan AC), serta sensor lingkungan. Aplikasi juga menyediakan histori grafik, ringkasan energi, laporan, pengaturan, dan halaman CCTV.

Aplikasi merupakan client untuk infrastruktur IoT yang sudah berjalan. Backend utama adalah ThingsBoard CE; aplikasi tidak memiliki backend bisnis tersendiri. Dokumen ini mencatat perilaku produk pada kode 1.3.0 yang belum dirilis dan pekerjaan lanjutan yang disarankan.

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

## 4. Fitur dan status implementasi versi 1.2.3

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
- Dashboard menghindari rebuild saat hasil telemetry tidak berubah.
- Tampilan mendukung tema gelap dan terang serta pilihan warna aksen.

**Perbedaan dari konsep awal:** PRD versi 1.0 mengusulkan tiga card grouped-list di satu dashboard. Implementasi saat ini memakai Overview dan halaman/tab detail terpisah. Bentuk navigasi tab ini menjadi baseline produk.

### 4.3 Grafik historis

**Status: Diimplementasikan.**

- Grafik telemetry tersedia pada halaman PV, AC, dan Battery.
- Data dibaca melalui endpoint time-series ThingsBoard dengan agregasi AVG.
- Tampilan grafik mengikuti tanggal yang dipilih; tersedia pemilih tanggal untuk meninjau hari lain.
- Rentang dan resolusi mengikuti implementasi query aplikasi. Ketersediaan titik data bergantung pada telemetry dan retensi ThingsBoard.

### 4.4 Ringkasan dan laporan energi

**Status: Diimplementasikan pada versi 1.2.3.**

- Overview menampilkan estimasi produksi PV dan konsumsi AC untuk periode harian atau tujuh hari, dengan perbandingan periode sebelumnya.
- Halaman laporan menyediakan analisis energi pada rentang harian/bulanan dan ekspor CSV.
- Perhitungan merupakan estimasi berbasis histori daya; hasil bergantung pada kelengkapan dan interval telemetry.
- Laporan memperbarui datanya secara berkala saat halaman laporan terbuka dan mendukung refresh manual.

### 4.5 Peringatan lokal dan data stale

**Status: Diimplementasikan secara lokal; perlu masuk release 1.3.0.**

- Peringatan lokal muncul untuk SOC baterai rendah dan telemetry yang melewati ambang usia.
- Pengguna dapat mengaktifkan/menonaktifkan peringatan dan mengatur ambang SOC serta usia telemetry di Settings.
- Kartu telemetry menampilkan usia update saat stale.
- Pengguna dapat menentukan batas minimum dan/atau maksimum suhu lingkungan, kelembapan, dan TDS air. Batas kosong diabaikan; alert lingkungan hanya mengevaluasi data sensor yang masih segar.
- Dashboard membedakan kegagalan fetch ThingsBoard dari perangkat yang telemetry-nya stale dan menunjukkan waktu fetch sukses terakhir.
- Peringatan tidak dikirim ketika aplikasi ditutup; push notification belum tersedia.

Ambang stale yang disimpan pengguna dipakai untuk evaluasi peringatan, label pada kartu telemetry, dan ringkasan Overview.

### 4.6 CCTV

**Status: Integrasi UI diimplementasikan; ketersediaan stream perlu diverifikasi di lingkungan deploy.**

- CCTV tersedia sebagai halaman/tab tersendiri dan dimulai dalam keadaan standby.
- Pengguna menekan Play untuk memuat halaman stream melalui WebView; tersedia status, stop, retry, dan reload.
- URL harus HTTPS dan memakai host yang diizinkan.
- Tombol layar penuh membuka stream dalam orientasi landscape dengan kontrol untuk keluar. CCTV bukan card pada Overview.

### 4.7 Pengaturan dan tampilan

**Status: Diimplementasikan.**

- Preferensi tema (System/Light/Dark), warna aksen, polling, peringatan energi/lingkungan, ambang stale/SOC, batas sensor, dan URL CCTV disimpan lokal.
- Pengguna dapat melihat versi aplikasi yang dibaca dari metadata paket, serta melakukan logout.
- Pengaturan mengoptimalkan efek visual untuk performa.

## 5. Kebutuhan nonfungsional

| Aspek | Baseline/target |
|---|---|
| Keamanan transport | HTTPS untuk ThingsBoard dan URL CCTV yang diizinkan. Token sesi disimpan dengan secure storage. |
| Kinerja | Polling tidak boleh menumpuk request; UI menghindari rebuild ketika data tidak berubah. Satu cold launch APK 1.2.3 pada perangkat uji tercatat 930 ms; perlu pengukuran berulang dan perangkat lain untuk memastikan konsistensi target <2 detik. |
| Responsif | Pada satu perangkat Android 1220×2712, halaman Overview dapat digulir dan konten terlihat. Ukuran layar lain belum diuji. |
| Ketahanan data | Jika fetch gagal, tampilkan status/error; MVP tidak menjanjikan cache offline lengkap. |
| Ketersediaan | Tidak ada SLA formal; bergantung pada Orange Pi, ThingsBoard, tunnel, jaringan, dan perangkat IoT. |
| Akurasi | Nilai dan estimasi hanya seakurat telemetry yang dikirim perangkat dan histori yang tersedia. |

## 6. Di luar cakupan versi saat ini

- Push notification saat aplikasi tertutup.
- Mode offline dengan cache telemetry lengkap.
- Subscription WebSocket untuk menggantikan polling REST.
- Register dan reset password dari aplikasi.
- Pengelolaan banyak pengguna/role di aplikasi.
- Prediksi FNN dan penjelasan XAI di aplikasi.
- Backend/API kustom.
- Status kesehatan stream yang diverifikasi end-to-end.

## 7. Saran pengembangan

Urutan berikut disarankan berdasarkan risiko dan kesesuaian terhadap implementasi sekarang:

1. **Kurangi waktu cold start.** Profilkan startup pada build release dan optimalkan bagian yang terbukti lambat; ukur ulang sampai target <2 detik tercapai.
2. **Verifikasi CCTV end-to-end.** Uji URL produksi, kontrol fullscreen, dan rotasi pada perangkat Android.
3. **Ukur layout pada beberapa ukuran perangkat Android** dan simpan hasil verifikasi APK/perangkat di catatan rilis.
4. **Perjelas status fetch dan usia data.** Tampilkan waktu pembaruan yang mudah ditemukan dan bedakan kegagalan koneksi dari telemetry yang stale.
5. **Pertimbangkan WebSocket setelah polling stabil.** Evaluasi dampaknya terhadap baterai, koneksi ThingsBoard, serta kompleksitas reconnect sebelum mengganti polling.
6. **Tambahkan push notification hanya dengan jalur server.** Tentukan sumber aturan/threshold dan layanan pengiriman terlebih dahulu; alert lokal yang ada hanya aktif saat aplikasi berjalan.

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

## 9. Roadmap

- **Prioritas perbaikan:** verifikasi CCTV dan APK pada perangkat; kurangi waktu cold start.
- **Peningkatan monitoring:** pertimbangkan WebSocket, cache ringan untuk tampilan terakhir, dan push notification berbasis server.
- **Riset produk:** integrasi hasil FNN-XAI setelah model dan format output stabil.
- **Skala pengguna:** evaluasi role/multi-user dan backend perantara hanya jika kebutuhan operasional bertambah.

## 10. Hasil verifikasi versi 1.2.3

- `flutter analyze`: lulus tanpa temuan.
- `flutter test`: lulus (2 test).
- APK release 1.2.3 build 7 berhasil dibuat.
- APK release 1.2.3 build 7 berhasil dipasang dan dibuka pada perangkat Android 24090RA29G dengan resolusi 1220×2712. Package Manager melaporkan versionName 1.2.3 dan versionCode 7.
- Layar Login tampil normal setelah instalasi baru. Sesi dan preferensi lokal lama terhapus saat paket sebelumnya di-uninstall; login ThingsBoard belum dilakukan.
- Cold launch awal APK 1.2.3 tercatat 930 ms (`adb am start -W`), memenuhi target <2 detik pada pengukuran tunggal ini.
- Pengukuran sebelum penggantian APK pada 1.2.2 sempat mencatat 2417–3339 ms; hasil lama itu tidak mewakili build 1.2.3 dan menunjukkan hasil startup perlu diuji berulang.
- Halaman monitoring setelah login, stream CCTV, dan tata letak pada ukuran perangkat lain belum diverifikasi langsung.
