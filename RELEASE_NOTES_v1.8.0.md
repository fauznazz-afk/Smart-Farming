# EnerGrow 1.8.0 (build 17)

Rilis kedua setelah 1.7.2. Dua arah: menutup temuan audit keamanan di seluruh
source, dan menambahkan layer antarmuka skeuomorphic beserta satu tema baru.

Tanggal: 7 Oktober 2026 · Tag: `v1.8.0` · Branch: `main`

---

## Yang berubah

### Keamanan — sepuluh temuan ditutup

Audit tingkat source di Dart, Kotlin, kedua manifest, aturan backup, dan
WebView. Tidak ada temuan Critical.

**Paling serius: token ThingsBoard bocor ke host mana pun yang ditunjuk
redirect.** `dart:io` membuang enam nama header pada redirect lintas origin —
`authorization`, `www-authenticate`, `proxy-authorization`, `proxy-authenticate`,
`cookie`, `cookie2` — dan `X-Authorization`, yang justru yang dibutuhkan API
ThingsBoard, **tidak termasuk di antaranya**. `package:http` mengikuti redirect
secara bawaan. Jadi satu `302` dari server memberi access token ke siapa pun yang
ditunjuk header tersebut. `POST` refresh lebih buruk lagi: bodinya berisi
refresh token dan diputar ulang pada `307`, yang mengubah kebocoran sesaat
menjadi sesi yang bisa diperpanjang.

Sisanya: logout tidak menyelesaikan teardown langkah-langkahnya; URL CCTV
mengizinkan `?src=` berupa URL sehingga kamera bisa dipakai sebagai relay;
`FLAG_SECURE` bocor dan membuat seluruh app tidak bisa di-screenshot; cache
telemetry tumbuh tanpa batas; dan delapan `debugPrint` tetap ada di build
release.

**Detail yang mudah terlewat:** `appLog` yang menggantikannya menerima argumen
berupa `String Function()`, bukan `String`. Dengan parameter `String`, pesan
diinterpolasi di call site sebelum helper-nya dipanggil — tidak ada guard di
dalam yang bisa mencegah kerjakanya, `join(',')` tetap jalan dan tetap
mengalokasikan memory di release meski tidak ada yang dicetak. Assert yang
menghapus panggilannya juga, bukan sekadar yang menghilangkan cetakannya.

### Perbaikan

- **`FLAG_SECURE` mengikuti route kamera, bukan visibilitasnya.** Dibuka dengan
  Settings dari tab Hydroponics, `dumpsys window` melaporkan `SECURE` di
  *dashboard*, dan setiap screenshot berikutnya di app mana pun menjadi bingkai
  hitam. Bukan keuntungan keamanan — aplikasi yang tidak bisa di-screenshot,
  tidak bisa melapor bug, dan tidak bisa diperiksa adalah aplikasi rusak.

  Ada **dua** sebab independen dan menutup yang pertama tidak menutup bugnya.
  Route yang menimpa layar tidak pernah `dispose`, jadi `SecureWindow.release()`
  tidak pernah berjalan; dan kedua kamera berada di dalam `IndexedStack` sehingga
  keduanya ter-mount di setiap tab, sementara `RouteAware` tidak bisa melihat
  perpindahan tab — route-nya tetap yang teratas tab mana pun yang terbuka.
  Keduanya tertangkap oleh `secure_window_test.dart`, termasuk bahwa percobaan
  pertama melepas flag di `didPush`, yang dipanggil `RouteObserver.subscribe`
  seketika, sehingga streamnya bisa difoto: itu lebih buruk daripada kebocoran
  yang digantikannya.

- **Kredensial plaintext warisan diverifikasi, bukan diasumsikan hilang.**
  `SharedPreferences.remove()` membuang kunci dari cache memori *sebelum*
  memanggil platform, jadi `remove()` lalu `getString()` melaporkan sukses untuk
  penghapusan yang tak pernah sampai ke disk. Hanya `reload()` yang bisa
  melihatnya. Kegagalan di sini berarti ada JWT plaintext basi di disk — bukan
  sesi hidup, tapi artefak kredensial nyata.

### Antarmuka

- **Layer skeuomorphic**: rim terukir yang diterangi dari kiri atas, isian
  bergradasi dari atas, dan gloss pada permukaan terang, lewat `AppCard`,
  `AppTile`, `AppBadge`, `DateStripChip` dan `SkeuoSurface` baru.

  **Token permukaan tidak bergerak.** Menuliskannya ulang dicoba dan
  dibatalkan: halaman light berubah jadi putih hampir penuh — nilai yang oleh
  catatan desain sebut paling menentukan di seluruh file token — dan tiga
  jaminan kontras serta tiga penjaga token gagal. Skeuomorfisme adalah soal
  *material*, dan tidak perlu permukaan itu sendiri bergerak.

  **Satu aturan membuat lapisan ini aman terhadap kontras: isian hanya boleh
  bergerak menjauh dari warna teksnya.** "Kedalaman milik bayangan, bukan isian"
  ditulis karena gradien yang menggelapkan kartu terang ikut menggelapkan
  latar teksnya. Batasnya tidak pernah pada gradiennya, melainkan pada
  *arahnya*. Karena token selalu menjadi stop terburuk, dan token itulah yang
  diukur `color_helpers_test.dart`, semua pembuktian yang sudah ada tetap berlaku
  tanpa satu pun perubahan. Aturan itu diuji sebagai *properti* di 68 kasus,
  bukan sebagai nilai hex, sehingga perubahan berikutnya tidak bisa membalik
  arahnya diam-diam.

  **Bevelled edge tidak bisa ditulis sebagai `Border`.** Flutter menolak border
  dengan sisi berbeda warna bila punya radius atau berbentuk lingkarang, dan
  `flutter analyze` tidak bisa melihatnya — empat layar persis begitu dan akan
  melempar pada setiap kartu di build debug. Rim-nya gradasi di belakang isian,
  dan `skeuo_paint_test.dart` memompa setiap permukaan untuk menjaganya.

- **Skeuo, tema keempat** dengan palet brief itu sendiri: amber `#F59E0B` dan
  lime `#C4F042` di atas halaman `#0A0A0C`.

  **Opsi keempat, bukan penggantian, dan itu seluruh keputusannya.** Brief
  mendeskripsikan palet dark-only, jadi mengambilnya sebagai satu-satunya theme
  akan menghapus tema light — halaman `#E1E7E4` yang oleh catatan desain sebut
  paling menentukan di seluruh file token, beserta tiga jaminan kontras yang
  diukur terhadapnya. Palet yang terdefinisi sama bernilai dengan palet yang lain
  di sebelahnya.

  **Amber adalah accent, lime adalah warna sinyal**, yang membalik pembacaan
  yang paling wajar. Lime punya kontras lebih tinggi di halaman nyaris hitam dan
  akan menjadi primer yang paling logis, tetapi brief menyebut amber sebagai
  `primary`, dan aplikasi ini sudah memakai kata "accent" untuk warna yang
  mewarnai kontrol. Lime dipakai untuk melaporkan *kondisi* — sengaja bukan hijau
  kedua, karena hijau di aplikasi ini sudah berarti "tidak ada masalah".

  Ramp shadow-nya **dibalik dari tema dark**, karena `#0A0A0C` lebih gelap dari
  `#1A211F` dan shadow hitam di halaman nyaris hitam tidak bisa melakukan
  pekerjaan itu; bounce kiri-atas yang memegang edge. **Ramp itu diturunkan dari
  luminansi halaman, bukan diukur** — satu-satunya angka di rilis ini yang akan
  diganti oleh scanline.

---

## Batasan yang diketahui

Hal berikut **sudah diuji dan belum terbukti di perangkat**, dan dinyatakan di
sini secara terbuka:

- **CCTV tidak diputar, dan belum diperbaiki.** Yang diperbaiki di rilis ini:
  validasi `?src=` yang terlalu ketat, cookie dan DOM storage kamera yang tidak
  dihapus saat logout, dan `FLAG_SECURE` itu sendiri. Status aplikasi berbunyi
  `live`, tetapi itu hanya berarti halaman WebView selesai dimuat — **nol
  aktivitas dekoder** (`MediaCodec`, `VideoTrack`, HLS/MSE) tercatat saat
  streaming, dan stream yang benar-benar berjalan pasti menghasilkan aktivitas
  itu. **Apakah ini regresi dari 1.7.2 belum diketahui.** Yang bisa disingkirkan:
  guard navigasi di `main` lebih ketat daripada yang sekarang, sehingga tidak
  mungkin menjadi penyebab; dan `cam1` cocok persis dengan pola yang diizinkan.
  Yang belum disingkirkan: file itu sendiri belum pernah terlihat bekerja.
- **Tema Skeuo belum pernah dilihat di layar.** Instalasi berhasil dan suite
  hijau — 46 kasus kontras di `skeuo_theme_test.dart` mengukur setiap warna
  caption dan status terhadap kelima permukaannya — tetapi port wireless debugging
  HP berputar sebelum tema bisa dipilih dan difoto. Penampilannya belum
  terverifikasi.
- **Ramp shadow Skeuo diturunkan, bukan diukur.** Scanline tepi-atas — pertanyaan
  terbuka `§18.5` — belum diambil untuk tema mana pun.
- **Ketidakseimbangan shadow tema light belum diatasi.** Pengukuran komposit
  memberi rasio light/dark **0.233** pada halaman light, terhadap **2.050** pada
  tema dark. Alpha tidak diubah: `Color.lerp` mengabaikan blur topeng, jadi
  angka itu batas atas langkah yang terlihat, bukan langkah yang dilihat kamera.
  Mengubah alpha dari angka seperti itu adalah menebak dengan langkah ekstra —
  dan koreksi sebelumnya justru overshoot ke 2.6× dengan cara persis sama.
- **Pemeriksaan alarm background belum pernah terlihat berjalan.** Nol log
  `EnerGrowAlarm*` selama 80 detik. Cocok dengan stand-down foreground yang
  terdokumentasi, tetapi stand-down itu sendiri tidak menlog, sehingga
  "berhenti karena aplikasi terbuka" dan "receiver mati" tidak dapat dibedakan.
  Itu celah diagnostik, bukan kerusakan yang terbukti.
- **`flutter test` penuh tidak selesai di mesin 7 GB ini**, dan itu Symptom OOM
  yang sudah terdokumentasi di `dart_test.yaml`, bukan kegagalan baru: file yang
  gagal berbeda tiap run, dan setiap file lulus ketika dijalankan sendiri.
  Karena itu seluruh suite dijalankan **per-file dengan jeda**, dan tidak ada
  klaim "suite penuh hijau" di dokumen ini.
- **`test/cctv_test.dart` kini melewati anggaran RAM** untuk satu run penuh
  (34 test, dan akan bertambah). Tiap grup lulus sendiri; filenya yang perlu
  dipecah, dan itu belum dikerjakan.

---

## Pemasangan

Unduh `EnerGrow-v1.8.0.apk` dari aset rilis. Android akan meminta izin
"Memasang aplikasi dari sumber tidak dikenal" untuk pemuat unduhan yang
digunakan — itu normal untuk APK di luar Play Store.

**Memasang di atas 1.7.2 mempertahankan sesi login Anda.** APK ditandatangani
dengan kunci yang sama, jadi `adb install -r` maupun pemasangan lewat pengelola
file tidak menghapus token ThingsBoard maupun preferensi lokal.

---

## Hasil verifikasi

| | |
|---|---|
| Fingerprint sertifikat | `504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5` — **cocok** dengan §3 |
| Scheme v2 | `true` |
| `versionName` / `versionCode` | `1.8.0` / `17` (dibaca dari APK dengan `aapt2 dump badging`) |
| SHA-256 APK rilis | `70C1A7BD34E01855D55AE04B398AA6992535EFA6C9736555E4AEF154F62F4FC6` |
| `flutter analyze` | bersih |
| `flutter test` | lihat tabel di bawah |
| Release APK menyertakan `AlarmDebugReceiver`? | **tidak** — hanya `AlarmCheckReceiver` dan `AlarmBootReceiver` |
| `android:debuggable` | tidak ada |
| Cleartext / `networkSecurityConfig` | tidak dideklarasikan |

_(tabel hasil `flutter test` diisi setelah sweep per-file selesai)_

**`flutter test`: 774 lulus di 50 file, 0 kegagalan.** Dijalankan **per-file dengan
jeda dan upto 3 percobaan**, karena satu run penuh tidak selesai di mesin 7 GB ini.
Empat file gagal atau dilaporkan kosong pada percobaan awal —
`date_strip_test`, `appearance_dracula_test`, `energy_report_chart_card_test`,
`secure_window_test` — dan **semuanya lulus begitu dijalankan sendiri** dengan RAM
tersedia; `date_strip_test` 36/36. Jadi nol kegagalan nyata, dan sekaligus nol
klaim "suite penuh hijau" juga.

---

## Rilis sebelumnya

`CHANGELOG.md` yang terlampir memuat riwayat seluruh versi.
