# 1.14.1

Angka-angka pindah ke tepi kanan, langit jadi gambar, ada widget di layar
utama, dan sekarang aplikasi bisa memberi tahu kalau ada versi baru.

## Yang diperbaiki

- **Setiap angka duduk 208 dp dari tepi kanan kartu.** `Flexible` default-nya
  `FlexFit.loose`, jadi `FittedBox` di setiap nilai menyusut ke lebar glyph-nya
  sendiri dan `RenderFlex` merapikan baris dari kiri — sisa ruang jatuh di ujung.
  `AC_LOAD  26 W` terukur: angka 12 dp dari labelnya sendiri, dan 208 dp kartu
  kosong di sebelah kanannya. `tight` di kedua box.
- **Caption rentang tercetak 6.8 dp dari nama slot** — terbaca sebagai bagian dari
  label, bukan sebagai catatan tentang angkanya. Dipindah ke tepi kanan.
- **Caption membungkus empat baris di skala font 2.0** — `15-50`, lima karakter,
  setinggi 120 dp.
- **Ganti light/dark meninggalkan semua panel di palet lama sampai 10 detik.**
  `_visualToken` tidak punya entri palette, jadi setiap `Bound` melihat token
  yang tidak berubah dan menahan child-nya. Gejalanya: aplikasi satu warna, satu
  panel warna lain.

## Yang ditambahkan

- **Langit sebagai dot matrix** di baris `SKY_STATE`, digambar dari lux yang sama
  dengan kata di sebelahnya. Empat kondisi: cerah, cerah berawan, mendung, malam.
  44 dp di tepi kanan baris.
- **Widget layar utama**: produksi PV, beban AC, SOC, dan lux, beserta **usia
  datanya**.
- **Pemberitahuan versi baru**: sekali sehari membandingkan rilis GitHub terbaru
  dengan versi terpasang. Membuka halaman rilis di browser — **tidak mengunduh atau
  memasang apa pun**. Settings → About → **Check for updates** melewati gate harian.
- **Ekspor chart PNG 1920×1080** dengan judul dan keterangan rentang.

## Batasan yang perlu diketahui

- **Widget tidak polling.** Ia membaca cache yang sudah ditulis aplikasi, jadi
  dengan aplikasi tertutup angkanya setua saat aplikasi terakhir dibuka. Karena itu
  widget menampilkan **usia datanya** (`never updated` sebelum pembacaan pertama).
  Mengubahnya jadi live butuh penjadwal dan HTTP client native kedua.
- **Widget gelap di kedua tema.** `RemoteViews` tidak bisa membaca `Theme.of`.
- **Cek update butuh GitHub bisa dihubungi.** Offline, kena rate limit, atau
  bentuk respons yang tak terduga: tidak ada banner dan tidak ada error — dan
  tidak ada yang gagal diam-diam.
- **Widget memakai palet dark yang disalin** ke `widget_energy.xml`, karena
  `design_tokens.dart` adalah Dart dan proses widget tidak menjalankan Dart.

## Verifikasi

- `flutter analyze` bersih
- **775 test Dart / 61 file**, plus 11 test Kotlin (`AlarmParityTest`,
  `requireAllowedThingsBoardHost`) — BUILD SUCCESSFUL
- Fingerprint signing build ini **cocok** dengan `PRD_GitHub_Release_Process.md` §3:
  `504d13ee…64b5`
- `aapt2 dump xmltree` atas APK release: **tidak ada** `AlarmDebugReceiver`
- Dipasang di Xiaomi 24090RA29G (Android 16, API 36) di atas build sebelumnya
  dengan `adb install -r`, token ThingsBoard dan preferensi bertahan

## Cara memasang

```bash
adb install -r app-release.apk
```

Gunakan `-r`, bukan uninstall. Build release-signed, jadi装有 di atas build
release sebelumnya tanpa kehilangan login. Build debug **tidak bisa** dipasang di
atas build release karena signing key-nya berbeda.