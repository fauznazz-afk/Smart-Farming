# EnerGrow 1.7.0 (build 14)

Rilis 30 September – 1 Oktober 2026. Enam hari, tiga puluh commit, dan satu
refactor arsitektur yangmenyeluruhi seluruh aplikasi.

## Yang berubah secara mendasar

**Permukaan sekarang soft-UI opaque, bukan "liquid glass".** Kartu berwarna sama
dengan halaman dan semua kedalamannya datang dari sepasang bayangan: satu
contact yang rapat di titik kontak, satu ambient yang lebar, satu bounce putih di
sisi berlawanan arah cahaya. Ada token layer — `design_tokens.dart` adalah satu-
satunya tempat fill, radius, pasangan bayangan, dan durasi ditulis. Sebelumnya
sejumlah: satu primitif, tiga puluh lima `BoxDecoration` tulis tangan,
enam perlakuan kartu, dan dua belas nilai radius.

**Halaman Greenhouse dan Fish Tank sekarang punya grafik.** Tujuh total, semua
dengan data nyata. beforehand kedua halaman tidak punya satu pun, dan sebabnya
struktural — bukan pekerjaan yang hilang.

**Umur chart, sumbu waktu, dan jarak antar kartu mengikuti datanya.** Jarak 20dp
karena ambient bayangan menjangkau 20dp pada 1σ; di 10dp bayangannya terpotong
tepat di tengah bagian yang menggambar edge.

**Dracula.** Satu preset lengkap di Settings: mengubah permukaan dan aksen
sekaligus, dan aksen yang tersimpan kembali saat pengguna meninggalkannya.

## Yang ditemukan dan diperbaiki sepanjang jalan

Tiga di antaranya adalah cacat aksesibilitas yang sudah ada dan tidak terlihat
oleh `flutter analyze` maupun test mana pun:

- **`AppTile` di bawah WCAG AA** — 3,85:1 di light mode, dan test yang mengukurnya
  **sengaja mengecualikannya** dengan alasan yang benar untuk progress bar dan
  salah untuk tile.
- **`metricColor` tidak mencapai 1.4.11 sebagai elemen grafis** — 2,16–2,88:1 untuk
  tiga dari empat aksen di light mode. Setiap ikon dan titik di light page
 kurang. Diperbaiki dengan `metricGraphic`, bukan dengan menggelapkan
  `metricColor`, karena yang terakhir akan mengubah setiap nilai metrik.
- **Tombol "Play camera" putih di atas aksen Dracula** — 2,16:1 di `#C1A3EB`.

Dan satu yang systemik: **`test/color_helpers_test.dart` mengukur permukaan yang
sudah tidak dipakai.** Enam dari enam hex basi, lebih terang dari kenyataan,
sehingga suite hijau sementara tiga warna di bawah AA.

## Batasan yang diketahui

**Dracula belum pernah dilihat di perangkat.** Alpha bayangannya dihitung dengan
menyamakan ΔLuminance absolut tiap bayangan terhadap apa yang bayangan sama
lakukan di halaman gelap — klaim aritmetika tentang hubungan dengan tema yang
sudah diketahui bagus. Itu **bukan** klaim bahwa kartu terbaca terangkat di
`#282A36`, dan belum ada yang melihatnya. **Periksa ini lebih dulu kalau preset
itu terasa salah.**

Lainnya, tercatat di `FEATURE.md` §18:

- `_pickPeriod()` di energy report punya nol call site — tanggal laporan terkunci.
  (Catatan: ini pernah dilaporkan sebagai "dead code" dan **salah**; ia punya
  pemanggil. Dua klaim dead-code confident di repo ini terbukti keliru.)
- Cincin ikon pada baris resolved yang masih merah `severityColor`.
- Kotak hitam CCTV di light mode.
- Turbidity sensor membaca 2396–3000 NTU; ini pertanyaan perangkat keras, bukan
  kode.

## Verifikasi

```
flutter analyze                        bersih
flutter test                           452 lulus, 32 file
./gradlew :app:testDebugUnitTest       11 lulus
apksigner SHA-256                       504d13ee…564b5 (cocok dengan yang tercatat)
```

**Tidak diverifikasi di perangkat untuk build ini.** Layar terkunci selama
pekerjaan Dracula dan tidak ada telemetry frame-rate yang pernah diambil — laporan
120 fps adalah pengamatan pemilik perangkat, bukan hasil pengukuran. Pengukuran
kedalaman yang dilakukan adalah scanline brightness piksel pada build sebelumnya,
pada light dan dark mode.

## Pemasangan

```powershell
adb install -r build/app/outputs/flutter-apk/EnerGrow-v1.7.0.apk
```

Bertanda tangan dengan kunci yang sama seperti rilis sebelumnya, jadi ini
pemasangan upgrade — token ThingsBoard dan preferensi lokal tidak hilang. Jangan
copot aplicação lama kecuali signature benar-benar berbeda; penghapusan menghapus
sesi.