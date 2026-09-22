# PRD — Aplikasi Mobile Monitoring PLTS

**Project:** FNN-XAI-IoT — Smart Farming Energy Monitoring
**Platform:** Android (Flutter)
**Versi dokumen:** 1.0
**Status:** Draft untuk MVP

---

## 1. Overview

Aplikasi mobile untuk memantau kondisi kelistrikan pada lahan pertanian secara *real-time*, mencakup tiga sumber energi: **baterai aki**, **listrik AC (PZEM)**, dan **listrik panel surya (PV)**. Ditujukan untuk pengelola lahan pertanian/hidroponik yang mengandalkan sistem energi hybrid untuk pompa air, sensor, dan perangkat pendukung lainnya.

Aplikasi ini adalah **lapisan mobile di atas infrastruktur IoT yang sudah berjalan** (ESP32 sensor → ThingsBoard dashboard), bukan sistem backend baru. Fokus utama adalah pengalaman monitoring yang ringan, cepat diakses, dan nyaman digunakan di lapangan — dengan UI fluid bergaya *grouped list* (terinspirasi navigasi iOS) dan tema gelap sebagai default.

---

## 2. Infrastruktur yang Sudah Tersedia (Constraint & Fondasi)

PRD ini disusun dengan asumsi memanfaatkan penuh stack berikut, **bukan membangun ulang**:

| Komponen | Status |
|---|---|
| ESP32 #1/#2/#3 (sensor + gateway) | Sudah terpasang, mengirim data via ESP-NOW → MQTT |
| Mosquitto MQTT Broker | Sudah jalan di Orange Pi |
| ThingsBoard CE (dashboard, REST API, WebSocket, Auth/JWT) | Sudah terdeploy, jadi backend utama aplikasi |
| PostgreSQL | Sudah dipakai ThingsBoard untuk data time-series |
| Orange Pi 4 Pro + Cloudflare Tunnel (`mbkm20262027.tech`) | Sudah publish dashboard ke internet |
| go2rtc (rencana CCTV) | Direncanakan, belum live |

**Implikasi:** semua kebutuhan backend, auth, database, dan realtime messaging **sudah tersedia** dari ThingsBoard. Aplikasi Flutter murni bertindak sebagai *client* yang mengonsumsi REST API dan WebSocket ThingsBoard.

---

## 3. Tujuan MVP

Aplikasi versi pertama fokus menjawab satu kebutuhan inti: **memantau kondisi energi lahan dari HP, kapan saja, tanpa harus buka dashboard web ThingsBoard.**

Di luar itu (push notification, integrasi Google Sheets, mode offline penuh, biometric login) masuk kategori pengembangan lanjutan — dibahas di Bagian 7.

---

## 4. Kebutuhan Fungsional (MVP)

### 4.1 Autentikasi
- Login menggunakan akun ThingsBoard (Customer User atau Tenant Admin) — **bukan sistem auth baru**
- Token JWT disimpan lokal (`SharedPreferences`) agar tidak perlu login ulang setiap buka app
- Auto-redirect ke halaman Login jika token kedaluwarsa/invalid, dengan pesan singkat sebelum redirect
- Tidak ada fitur Register/Lupa Password di app — akun tetap di-*provision* manual oleh admin ThingsBoard (sesuai pola akses saat ini)

### 4.2 Dashboard Monitoring Real-time
- Tiga section utama: **Battery**, **Smart Meter PV & AC**, **Environment**
- Tiap section ditampilkan sebagai satu card berisi list metrik (bukan grid terpisah) — gaya *grouped list* fluid
- Data diperbarui berkala (polling tiap 10 detik sebagai baseline; upgrade ke WebSocket subscription dibahas di roadmap)
- Pull-to-refresh manual
- Skema warna semantik per section (teal untuk Battery, amber untuk PV/AC, biru untuk Environment)

### 4.3 Grafik Historis
- Chart tren untuk metrik kunci (SOC baterai, PV power, AC power) dalam rentang waktu (24 jam sebagai default MVP)
- Menggunakan endpoint `timeseries` ThingsBoard dengan agregasi (AVG)

### 4.4 CCTV Live View
- Card khusus di dashboard menampilkan live feed dari go2rtc
- Tap untuk memperbesar ke fullscreen
- *(Bergantung pada go2rtc yang masih dalam tahap setup — lihat catatan risiko di Bagian 6)*

### 4.5 Manajemen Sesi
- Auto logout saat token invalid
- Logout manual dari halaman Profil/Pengaturan

---

## 5. Kebutuhan Non-Fungsional

| Aspek | Target |
|---|---|
| Waktu loading awal | < 2 detik pada perangkat kelas menengah |
| Responsif | Menyesuaikan berbagai ukuran layar Android |
| Keamanan | Komunikasi API via HTTPS (sudah terjamin lewat Cloudflare Tunnel); token JWT dari ThingsBoard |
| Latency data | Selaras dengan siklus telemetry ESP32 (saat ini bergantung pada interval kirim MQTT masing-masing device) |
| Ketersediaan | Bergantung pada uptime Orange Pi + Cloudflare Tunnel — tidak ada SLA formal karena self-hosted |

---

## 6. Risiko & Catatan Realistis

- **CCTV**: fitur ini bergantung pada go2rtc yang belum live. Jangan dianggap "siap pakai" sebelum integrasi backend selesai.
- **Latency**: karena data PZEM-017 (DC) sempat mengalami *stale read* (tercatat di catatan project), grafik/nilai di app bisa saja menampilkan data usang jika masalah firmware itu belum sepenuhnya teratasi. App sebaiknya punya indikator "data terakhir diperbarui X menit lalu" untuk transparansi ke pengguna.
- **Single point of failure**: seluruh sistem (ThingsBoard, MQTT, Tunnel) berjalan di satu Orange Pi. Tidak ada redundansi — jika Orange Pi down, app otomatis tidak bisa menampilkan data apa pun.
- **Tanpa backend/API kustom**: karena app langsung bicara ke ThingsBoard, fitur yang butuh logika bisnis kompleks (misal agregasi custom, aturan notifikasi canggih) akan lebih sulit diimplementasikan dibanding jika ada backend perantara. Ini trade-off yang disadari demi kecepatan development di tahap MVP.

---

## 7. Roadmap Pengembangan Lanjutan (Di Luar MVP)

Fitur berikut **tidak dikerjakan di MVP**, dicatat sebagai arah pengembangan yang bisa dibicarakan lebih lanjut:

| Fitur | Catatan |
|---|---|
| Push notification (anomali baterai/listrik) | Butuh Firebase Cloud Messaging + logic threshold; bisa dibangun sebagai Python service terpisah yang subscribe ke MQTT dan trigger FCM |
| Integrasi Google Sheets | ESP32 sudah punya rencana logging HTTP POST ke Sheets secara terpisah dari app — sinkronisasi tampilan link di app bisa menyusul |
| Mode offline dengan cache lengkap | MVP hanya menampilkan status "gagal fetch" saat offline, bukan cache penuh |
| Biometric login (Face ID/Fingerprint) | Nice-to-have, tidak prioritas |
| WebSocket real-time (menggantikan polling) | ThingsBoard mendukung ini secara native; upgrade natural setelah MVP polling stabil |
| Prediksi FNN + XAI di dalam app | Menunggu model FNN selesai dikembangkan terlebih dahulu (masih tahap riset) |
| Multi-user/role management | Saat ini cukup 1-2 akun customer user; belum jadi kebutuhan mendesak |
| Backend/API kustom (Node.js dll) | Dipertimbangkan hanya jika kebutuhan logika bisnis melebihi kapasitas REST API ThingsBoard |

---

## 8. User Flow (MVP)

### Alur Autentikasi
1. Splash screen singkat (tema gelap)
2. Cek token tersimpan → jika valid, langsung ke Dashboard
3. Jika tidak ada token/invalid → halaman Login
4. Login sukses → token disimpan → redirect ke Dashboard
5. Token expired saat pemakaian → dialog singkat → redirect ke Login

### Alur Monitoring
1. Dashboard menampilkan 3 card section (Battery, Smart Meter PV & AC, Environment)
2. Pull-to-refresh untuk update manual, auto-refresh tiap 10 detik
3. *(Roadmap)* Tap section untuk lihat detail chart historis
4. *(Jika CCTV live)* Card CCTV terpisah, tap untuk fullscreen

### Alur Pengaturan
1. Tab/menu Profil menampilkan info akun
2. Tombol logout manual

---

## 9. Tech Stack (Aktual)

| Layer | Teknologi |
|---|---|
| Mobile Frontend | Flutter (Dart), Material 3 |
| State Management | `setState` / `StatefulWidget` (MVP) — evaluasi Provider/Riverpod jika kompleksitas naik |
| HTTP Client | package `http` |
| Local Storage | `shared_preferences` (token JWT) |
| Chart | `fl_chart` |
| CCTV Streaming | *(pending)* — kandidat: `flutter_vlc_player` untuk konsumsi stream go2rtc |
| Backend/API | ThingsBoard CE REST API + WebSocket (tidak ada backend kustom) |
| Auth | ThingsBoard JWT (built-in) |
| Message Broker | Mosquitto (device → ThingsBoard, sudah berjalan) |
| Database | PostgreSQL (dikelola ThingsBoard, sudah berjalan) |
| Hosting | Orange Pi 4 Pro (self-hosted) + Cloudflare Tunnel |

---

## 10. Definition of Done (MVP)

- [ ] Login berhasil menggunakan akun ThingsBoard, token tersimpan dan persist antar sesi
- [ ] Dashboard menampilkan data real-time dari 3 device (Battery, PZEM, Sensor) dengan auto-refresh
- [ ] UI menggunakan skema warna semantik per section + card grouped-list style
- [ ] Auto-redirect ke Login saat token expired
- [ ] Minimal 1 grafik historis (24 jam) untuk salah satu metrik kunci berhasil ditampilkan
- [ ] APK release berhasil di-build dan terinstall di perangkat fisik
- [ ] Indikator "data stale" muncul jika `lastUpdate` lebih dari threshold tertentu (mengantisipasi isu PZEM-017)
