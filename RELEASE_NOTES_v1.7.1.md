# EnerGrow 1.7.1

Patch. Satu bug, dan bug itu adalah satu-satunya item 1.7.0 yang belum pernah
dilihat di perangkat.

## Yang diperbaiki

**Kartu Dracula terbaca rata, dan derivasi yang menghasilkan angka itu salah
1,9 kali.**

Ini item 1.7.0 yang belum pernah dilihat di perangkat, dan ternyata alasan ia
belum pernah dilihat adalah bahwa ia tidak akan bertahan kalau dilihat.

Alpha bayangan Dracula diselesaikan supaya *langkah luminansi terkomposisi* di
`#282A36` sama dengan langkah yang membuat bayangan sama di halaman dark. Itu
klaim tentang `Color.lerp`, dan `design_tokens_test.dart` mengunci klaim itu
sampai 0,0007 dan lulus. Klaim itu tidak mengatakan apa pun soal apa yang
sampai ke layar, karena mask blur memakan porsi berbeda dari tiap halaman.

Terukur di Xiaomi, build yang sama, kartu yang sama, tepi kanan, scanline
luminansi 8-bit:

| | halaman | contact | delta-L terukur | sebagai pecahan halaman |
|---|---|---|---|---|
| dark `#1A211F` | 31,4 | 15,5 | **15,9** | 51 % |
| dracula, seperti dikirim di 1.7.0 | 42,4 | 34,2 | **8,2** | 19 % |

Dracula hanya menghasilkan **52 %** dari penurunan tema dark. Lima puluh dua
persen, dengan seluruh suite hijau.

## Kenapa begitu

Bukan salah ketik. Mask blur mengambil porsi yang berbeda dari tiap halaman,
sehingga blur dan alpha yang sama mendarat pada langkah terlihat yang berbeda.
**Hubungan aritmetika dan sebuah piksel adalah klaim yang berbeda, dan hanya
salah satunya yang dilihat pengguna.**

Ini kali ketiga di repo ini guard yang mengunci hubungan aritmetika menjadi
pihak yang salah, setelah daftar surface basi di `color_helpers_test.dart`, dan
setelah `_history` dilaporkan mati.

Dua konsekuensi, keduanya tercatat di kode:

- **Hubungan alpha dan delta-L terukur adalah cembung.** Blur memakan sebagian
  besar puncak bayangan lemah dan hampir tidak menyentuh yang kuat, jadi pengali
  seragam akan Tudor jauh. Kekurangan 1,9 kali diperbaiki dengan mengalikan alpha
  1,9 kali menjadi kelebihan 2,6 kali. Diperbaiki dengan interpolasi antara dua
  titik terukur.
- **Hanya diperbaiki separuh yang terukur.** Separuh gelap Dracula bergerak,
  separuh terang tidak, karena hanya separuh gelap yang pernah disampel.
  Menaikkan keduanya dengan angka yang dipinjam dari salah satunya adalah
  kesalahan yang justru dikoreksi rilis ini, dan melakukannya akan terlihat lebih
  rapi.

## Dampak yang terlihat

Hubungan terang-gelap Dracula **terbalik**. Di tema dark separuh terang yang
menentukan edge, rasionya 3,80; di Dracula separuh gelap sekarang yang bekerja,
dan pasangannya 2,41. Guard rasio di `design_tokens_test.dart` turun dari pita
10 % ke pita 40 %. Itu kehilangan presisi yang disengaja, dan dicatat sebagai
demikian di dalam test itu sendiri.

## Yang masih belum terverifikasi

- **Scanline melintasi tepi atas kartu.** Separuh terang pasangan Dracula belum
  pernah disampel, dan itu satu-satunya pertanyaan terbuka yang ditinggalkan oleh
  koreksi ini.
- **Tidak ada telemetry frame-time** yang pernah diambil. Angka 120 fps adalah
  pengamatan pemilik perangkat, tidak pernah diukur alat mana pun.

## Gerbang

`flutter analyze` bersih · 32 file test hijau · `./gradlew :app:testDebugUnitTest`
11 lulus.

## Build

```
flutter build apk --release
```

Sertifikat tetap yang sama seperti 1.7.0. Tidak ada perubahan signing.
