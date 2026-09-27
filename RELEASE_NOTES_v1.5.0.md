# EnerGrow 1.5.0 (build 11)

**Rilis:** 27 September 2026
**Tag:** `v1.5.0`
**APK:** `EnerGrow-v1.5.0.apk`
**Perubahan sejak 1.4.0:** 87 entri di `CHANGELOG.md`

Ini adalah rilis besar: sejak 1.4.0, aplikasi **tidak bisa memberi tahu
user apa pun saat aplikasi ditutup** — dan itu ternyata tidak hanya tidak
terbukti, tapi benar-benar rusak. Modul alarm-nya sekarang ditulis ulang dari
nasional dalam Kotlin, dan antarmuka diratakan ke bahasa Inggris sepenuhnya.

---

## Yang paling berubah

### Alarm bekerja saat aplikasi ditutup

Ini yang paling penting, dan perlu dijelaskan karena UI-nya tidak berubah sama
sekali — yang berubah adalah apa yang terjadi ketika layar mati.

**Dulu:** alarm hanya dicek saat aplikasi terbuka. Titik. Tidak ada notifikasi
jika HP ada di dalam tas.

**Sekarang:** modul Kotlin native (`AlarmManager` → `BroadcastReceiver`) waking
dari belakang, membaca ThingsBoard, dan mem-posting notifikasi. Alarm dijadwalkan
**setiap menit** dan berdiri sendiri selama aplikasi terbuka di depan, jadi tidak
ada polling ganda.

Yang membuat ini mungkin: `android_alarm_manager_plus` yang pernah dipakai
**tidak pernah benar-benar jalan**. Ia mewajibkan `<service>` dan `<receiver>` di
manifest dan keduanya tidak pernah ada, jadi alarm terdaftar tapi tidak pernah
diberikan. Ia sudah diganti.

**Dua trigger, bukan satu.** `setInexactRepeating` untuk ritme, dan satu
`setAndAllowWhileIdle` yang di-arm ulang setiap run. Alasannya: di perangkat uji
MIUI/HyperOS, alarm berulang berjalan enam kali lalu **hilang diam-diam** dari
`dumpsys alarm`, dengan `com.miui.powerkeeper` terlihat di output yang sama.
Yang kedua bebas dari Doze batching.

Alarm persis **tidak dipakai** — butuh `SCHEDULE_EXACT_ALARM` yang harus diberikan
pengguna lewat pengaturan sistem, dan greenhouse tidak membutuhkannya. Karena
jadwalnya bisa tertunda, pengecekan membaca **umur telemetry**, bukan
mengasumsikan satu tick sudah terjadi.

### Alarm baru: perangkat yang berhenti mengirim

Untuk setiap device, terpisah dari "stale". Sepuluh menit sunyi di pipeline MQTT
adalah hiccup; satu jam adalah sensor atau gateway yang mati, dan keduanya
menuntut respons berbeda. Default 60 menit, bisa diatur di Settings.

### Notifikasi satu kali per kemunculan

Set ID alarm aktif dibagi antara aplikasi dan modul native, jadi kondisi yang
masih berlaku tidak mengulang notifikasi tiap menit. Implementasi sebelumnya
memakai penghitung waktu lima menit — **lebih lama dari interval pengecekan, jadi
tidak pernah mencegah apa pun**.

###_one rule list, dua evaluator

`lib/utils/alarm_rules.dart` adalah satu-satunya definisi apa yang Counts sebagai
alarm. Dashboard dan modul native mengevaluasi daftar yang sama, jadi mengubah
ambang di Settings langsung mengubah banner **dan** notifikasi latar belakang.
Teks pesan ada di dua bahasa — Dart dan Kotlin — karena notifikasi dibangun saat
Dart tidak berjalan; keduanya dipin oleh satu fixture yang diputar ulang oleh test
di kedua sisi, jadi tidak bisa berbeda diam-diam.

### Antarmuka penuh bahasa Inggris

Sebelumnya campuran: pesan alarm, kartu energi, strip status, dan grid
environment berbahasa Indonesia, sementara halaman detail dan metric label berbahasa
Inggris — jadi satu layar bisa membaca dua bahasa.

### Batas lingkungan yang bekerja sejak awal

Terakhir ketika fitur ini dikirim kosong, jadi grid menampilkan lima angka tanpa
acuan. Sekarang: suhu 15–35 °C, kelembapan 40–85 %, TDS ≥ 800 ppm, dan alert
lingkungan aktif secara default. TDS sengaja **tanpa batas atas** — air tawar
memang tidak punya plafon.

### Panel statuslatar di Settings

Bagian "Background checks" menampilkan apakah pengecekan terpasang, apakah
kredensial tersimpan, kapan terakhir berjalan, dan apa hasilnya, plus tombol
"Check now" dan pintasan ke layar optimasi baterai. Bagian ini ada karena
kegagalan ini mustahil terlihat: alarm yang hilang terlihat persis seperti
"tidak ada yang perlu dilaporkan".

---

## Perbaikan yang mungkin AndaFwitness

- **Banner alarm menyusut, bukan hilang dalam satu frame.** Sebelumnya alarm yang
  selesai membuat seluruh Overview melompat naik setinggi kartu.
- **Tidak ada notifikasi ganda.** Pesan yang sama pernah muncul di banner **dan**
  SnackBar di bawah layar, dan SnackBar itu menyala ulang setiap kali kumpulan
  pesan berubah — bukan setiap alarm baru.
- **Alarm banner hanya di halaman Overview.** Pelanggaran ambang adalah fakta
  tentang kebun, bukan tentang tab yang sedang dibuka.
- **Chart masih menampilkan tegangan, arus, dan daya bersama**, dengan warna
  merah/hijau/biru, garis solid, dan sumbu Y **dinamis** — bukan 0–100%.
- **Angka min/maks pada chart tidak lagi terpotong** jadi `109....`.
- **Outline kartu mengikuti warna tema**, dan tidak ada lagi teks hijau di kondisi
  yang normal.
- **Aksesibilitas:** warna teks kecil sekarang benar-benar lolos WCAG AA. Klaim
  sebelumnya diukur terhadap permukaan yang salah; amber ada di 4,02:1.
- **Konvensi tanda baterai dikoreksi.** BMS ini melaporkan **minus saat charging**,
  dan hero card sekarang menampilkan angka mentah device supaya tidak berbeda
  dengan halaman Battery.

---

## Batasan yang diketahui

Bacalah ini sebelum Supported. Ada di `FEATURE.md` §18 dengan bukti lengkap.

- **Tidak ada push notification dari server.** Yang ada hanya pengecekan lokal
  terjadwal, yang hanya bisa melaporkan kondisi yang sudah tercatat di ThingsBoard.
- **Alarm background adalah fitur Android saja.** Di iOS, desktop, dan web modul
  native tidak ada dan semuanya menjadi no-op. Tidak ada yang menandakannya di UI.
- **Cold start belum diukur ulang sejak 1.2.3.**
- **Layout belum diuji di ukuran layar selain 1220×2712.**
- **Stream CCTV belum diverifikasi end-to-end** di URL produksi.
- **Produksi harian adalah estimasi,** bukan pengukuran. Produksi dianggap merata
  sepanjang hari yang sudah lewat, jadi angkanya meleset pada pagi cerah mendung
  siang. UI menyatakan ini, tapi tidak menjelaskan seberapa melesetnya.
- **Laporan energi mengintegrasi ulang daya rata,** bukan membaca energy counter
  ThingsBoard, jadi tidak akan sama dengan penghitung energi di ThingsBoard.
- **Mengosongkan batas lingkungan mengembalikan default,** bukan mematikan sisi
  itu — untuk lima dari enam field. Hanya batas atas TDS yang benar-benar kosong.
- **Field kota di pengaturan cuaca tidak berefek**; lokasi dari GPS.

## Yang belum pernah dilihat di perangkat

- Tanda minus di hero card — hanya terlihat saat baterai charging, dan saat
  verifikasi terakhir justru standby.
- Layout di density lain.
- Laporan energi dengan data bulan penuh.
- Alur notifikasi di device yang datanya belum pernah dibaca, yang tidak bisa
  di-reproduce tanpa logout.

---

## Pemasangan

```bash
# upgrade dari 1.4.0 — pertahankan data dan sesi ThingsBoard
adb install -r EnerGrow-v1.5.0.apk

# atau pasang manual: unduh, izinkan dari sumber tidak dikenal, install
```

**Jangan uninstall versi lama kecuali perlu.** Uninstall menghapus sesi
ThingsBoard dan semua preferensi lokal, dan Anda harus login lagi. Jika Android
menolak upgrade dengan pesan signature berbeda, **periksa dulu** — jangan
dihapus langsung.

Signature yang diharapkan (SHA-256):
`504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5`

---

## Hasil verifikasi

Semua pemeriksaan dijalankan pada commit rilis, di mesin build yang sama dengan
release sebelumnya.

| Pemeriksaan | Hasil |
|---|---|
| `flutter pub get` | 35 paket punya versi lebih baru di luar constraint — tidak blocking |
| `flutter analyze` | **No issues found!** |
| `flutter test` | **227 lulus** |
| `cd android && ./gradlew :app:testDebugUnitTest` | **11 lulus** (parity alarm + host allowlist) |
| `flutter build apk --release` | sukses, 60,8 MB |
| `apksigner verify` | signature valid, **v2 `true`**, 1 signer |
| Fingerprint SHA-256 | `504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5` — **cocok** dengan PRD §3 |
| `apkanalyzer` versionName / versionCode | **1.5.0 / 11** |
| `applicationId` | `tech.mbkm.energrow` |
| `AlarmDebugReceiver` di release APK | **0 kemunculan** (komponen debug tidak ikut) |
| Upgrade di perangkat | `adb install -r` dari 1.4.0 (build 10) → **Success**, tanpa `INSTALL_FAILED_UPDATE_INCOMPATIBLE` |
| Data setelah upgrade | sesi ThingsBoard dan preferensi **utuh** (`-r`, tanpa uninstall) |
| Launcher | terbuka normal, Overview tampil dengan data live |
| Alarm native | `dumpsys alarm` menunjukkan **dua** trigger: `repeatInterval=60000` (ritme) dan satu one-shot dengan flag non-nol (cadangan Doze) |

**Yang tidak diuji untuk artefak ini:** alur notifikasi alarm yang sebenarnya
memicu (butuh kondisi yang benar-benar terjadi, atau debug build yang tidak bisa
mengganti build release yang sudah terpasang). Uji notifikasi dilakukan pada 1.4.0 dengan
kode alarm yang sama.

Detail lengkap ada di `CHANGELOG.md`.
