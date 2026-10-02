# EnerGrow 1.7.2 (build 16)

Rilis perbaikan. Tidak ada fitur baru dan tidak ada perubahan yang memutus
kompatibilitas, jadi nomornya patch.

**Untuk pengguna yang hanya perlu tahu kesimpulannya:** dashboard kini tidak lagi menampilkan
peringatan palsu setiap sore, dan aplikasi ini dapat dibaca pada font sistem
yang besar. Dua-duanya adalah cacat yang lolos build rilis sebelumnya.

---

## Yang diperbaiki

### 1. Kartu daya tidak lagi memberi peringatan palsu setiap malam

Di sore hari, ketika matahari terbenam dan baterai mulaiitempty, kartu
"Live power" menampilkan **"The array is not covering the house load right now"**
dalam warna **amber**.

Kalimatnya benar secara harfiah —array memang tidak menghasilkan cukup — tapi
rumah ini justru **dibayar oleh baterai**, dan kartu itu tidak tahu itu. Worse,
kondisi itu **secara struktural pasti terjadi setiap sore**, bukan tanda
kesenjangan. Warning yang tidak pernah bisa berhenti benar adalah false alarm,
dan warna amber berarti "peringatan".

Sekarang, ketika baterai yang menutup selisihnya:

- `"The array is short, and the battery adds 30 W"` dalam teks biasa
- **Shortfall dengan baterai di *standby* tetap dapat amber** — karena saat itu
  memang tidak ada yang menutup selisih, dan itu peringatan yang benar

Presisi yang dijaga: nilai baterai ditampilkan **apa adanya seperti yang
dilaporkan perangkat** — bisa negatif, dan labelnya yang membawa arah. Aplikasi
ini sudah pernah mencoba "memperbaiki" tanda itu di satu layar saja dan
menariknya kembali, karena dua layar yang menampilkan angka berbeda untuk satu
pengukuran lebih buruk daripada minus yang aneh.

### 2. Tulisan pada kartu analitik energi tidak lagi terpotong

Pada layar 320 dp, satuan **`kWh` terpotong dari angkanya sendiri**: `1.53 kWh`
tergambar menjadi `1.53 k…`. Ini adalah regresi `109....` yang pernah terjadi di
27 September 2026, dengan angka berbeda, di ukuran layar yang belum pernah
diperiksa.

Kartu ini juga **meluap di setiap ukuran layar** pada font sistem 1.5 ke atas —
termasuk di ponsel 411 dp. Jadi ini bukan masalah layar kecil: **ini cacat
aksesibilitas yang dialami pengguna yang memperbesar
font-nya supaya bisa membaca angka.** Sekarang tidak ada lagi strip overflow
yang muncul di setiap frame.

### 3. Strip status sistem tidak lagi menjadi pecahan kata

Pada font sistem 2.0, strip `Battery / AC grid / Alarm` menampilkan:

```text
Bat...      AC ...      Ala...
99%         Sta...      1
min 1...    221 V ...   active
```

`Sta...` adalah yang paling serius: itu kata **`Stable`**, dan itu **seluruh
klaim** yang dibawa strip itu. `Sta...` tidak bisa dibedakan dari `Standby`.
Widget ini **tidak punya satu pun test** sebelumnya.

### 4. Judul kartu dan satuan watt tidak lagi terpotong

`Live power` menjadi `Live po…`, dan satuan `W` meluap keluar barisnya pada
skala 2.5 ke atas.

---

## Akar masalahnya, dan ini yang lebih penting

Test lebar yang sudah ada **sudah** memarametrisasi lebar dan skala — dan
**lulus**. Tapi ia mengukur widget yang **48 dp lebih lebar** daripada yang
benar-benar tampil di layar, karena merender kartu tanpa margin halaman 24 dp
yang dipakai aplikasi. Jadi di ponsel 320 dp, test mengukur kartu 320 dp
sementara yang di layar adalah 272 dp.

Bentuk kegagalan ini senyap: tidak ada assertion yang melemah, assertion-nya
hanya sedikit lebih longgar dari yang tertulis, dan tidak ada yang melapor.
Setelah marginnya diperbaiki, **dua cacat tambahan langsung muncul** yang
tidak ada sebelumnya.

Perbaikan harness ini lebih berharga daripada empat cacat di atas, karena tanpa
ia test yang sama akan terus lulus untuk alasan yang salah.

---

## Yang diverifikasi

- `flutter analyze` bersih
- `flutter test` **625 lulus** di 40 file
- Setiap guard baru diuji dengan **dapat gagal lebih dulu** — margin halaman
  memunculkan overflow 3,7 px, pemeriksaan horizontal memunculkan
  `{Live power: Live po…}`, dan test strip gagal 7 dari 16 terhadap widget asli
- `flutter build apk --release` berhasil
- 1.7.0: fingerprint sertifikat, `versionName`/`versionCode`, dan scheme v2
  diperiksa pada build yang dilepas

## Yang TIDAK terverifikasi — dan ini penting

- **Tiga perbaikan terakhir ini belum pernah dilihat di perangkat.** Perangkat
  uji terputus dari ADB sebelum APK-nya sempat terpasang. Cacatnya **ditemukan**
  di perangkat nyata pada font 2.0, dan perbaikannya dipin oleh test pada lebar
  yang benar — tapi "test lulus" adalah klaim yang lebih lemah dari "layarnya
  benar", dan yang kedua belum diperoleh untuk rilis ini.
- Langkah `adb install -r` untuk menguji upgrade **dilewati**, karena tidak ada
  perangkat. Jalur upgrade antar-rilis yang terakhir benar-benar berjalan masih
  1.5.0 dari 1.4.0.
- `.\gradlew.bat :app:testDebugUnitTest` **tidak dijalankan** pada sesi ini:
  tidak ada aturan alarm atau `AlarmMessageFormat.kt` yang berubah, jadi
  paritas Dart↔Kotlin tidak tersentuh.

---

## Pemasangan

Unduh `EnerGrow-v1.7.2.apk` dari halaman rilis dan pasang seperti biasa
(izinkan "install dari sumber tidak dikenal" jika diminta). APK ditandatangani
dengan kunci rilis yang sama, jadi **memperbarui di atas 1.7.1** dan sesi
ThingsBoard Anda akan tetap ada.

Butuh logout/login ulang hanya jika Android menolak tanda tangan — yang
seharusnya tidak terjadi. **Jangan uninstall lebih dulu**: uninstall menghapus
token ThingsBoard dan preferensi lokal.

## Batasan yang diketahui

- Sensor turbidity masih terbaca 2396 lalu 3000 NTU, yang bukan skala
  akuakultur (air jernih ada di bawah 30 NTU). Kemungkinan besar belum
  dikalibrasi. Default lamanya sudah dihapus di 1.6.1 agar tidak alarmed terus.
- Tidak ada prakiraan cuaca — integrasi OpenWeatherMap dicabut di 1.6.0.
- Alarm background adalah fitur Android. Di platform lain modulnya menjadi
  no-op yang aman, tanpa padanan.
- ThingsBoard sekarang menjalankan 4 device; hanya tiga yang pernah
  diverifikasi di perangkat.
