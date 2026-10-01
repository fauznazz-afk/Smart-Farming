# EnerGrow 1.7.1

Patch. Tiga puluh item, dan sebagian besarnya bukan "optimasi" — adalah
tampilan yang berbohong, atau widget yang tidak punya feedback sama sekali.

Bagian yang paling penting untuk dibaca adalah **tampilan yang dulu salah dan
sekarang benar**, karena itu yang tidak bisa tangkap alat mana pun.

---

## Ringkasan

| | |
|---|---|
| Versi | 1.7.1 (build 15) |
| Tag | `v1.7.1` |
| APK | `EnerGrow-v1.7.1.apk` |
| Dihapus | 1 (biometrik) |
| Diperbaiki | 26 |
| Ditambah | 4 file test baru, 108 test baru |
| Gerbang | `flutter analyze` bersih · 38 file / **581 test** · `gradlew :app:testDebugUnitTest` 11 lulus |

---

## Yang paling penting

### Kartu Dracula terbaca rata, dan derivasi yang menghasilkan angka itu salah 1,9 kali

Ini satu-satunya item 1.7.0 yang belum pernah dilihat di perangkat, dan
ternyata alasan ia belum pernah dilihat adalah bahwa ia **tidak akan bertahan
kalau dilihat**.

Alpha bayangan Dracula diselesaikan supaya *langkah luminansi terkomposisi* di
`#282A36` sama dengan langkah yang membuat bayangan sama di halaman dark. Itu
klaim tentang `Color.lerp`, dan `design_tokens_test.dart` mengunci klaim itu
sampai 0,0007 dan lulus.

Terukur di Xiaomi, build yang sama, kartu yang sama, tepi kanan, scanline
luminansi 8-bit:

| | halaman | contact | ΔL terukur | sebagai pecahan halaman |
|---|---|---|---|---|
| dark `#1A211F` | 31,4 | 15,5 | **15,9** | 51 % |
| dracula, seperti dikirim di 1.7.0 | 42,4 | 34,2 | **8,2** | 19 % |

Dracula hanya menghasilkan **52 %** dari penurunan tema dark. Lima puluh dua
persen, dengan seluruh suite hijau.

Koreksinya **dua titik terukur, bukan solve baru**. Hubungan alpha dan ΔL
terukur bersifat cembung — blur memakan sebagian besar puncak bayangan lemah dan
hampir tidak menyentuh yang kuat — jadi pengali seragam akan Tudor jauh.
Kekurangan 1,9× diperbaiki dengan interpolasi antara dua titik terukur.

**Hanya separuh gelap yang bergerak.** Setiap `0x??000000`across `raised`,
`inset`, `insetDeep` dan `pressed` dikoreksi; setiap `0x??FFFFFF` masih nilai
hasil solve asli. Separuh gelap satu-satunya yang pernah disampel dan satu-satunya
yang gagal, jadi satu-satunya yang ada buktinya untuk digeser.

Dampaknya terlihat: hubungan terang-gelap Dracula **terbalik**. Guard rasio di
`design_tokens_test.dart` turun dari pita 10 % ke pita 40 %. Itu kehilangan presisi
yang disengaja, dan dicatat sebagai demikian di dalam test itu sendiri.

### Garis rambut adalah hal paling terang di tepi kartu, di kedua tema gelap

Penyebabnya tidak terlihat dari file token. Putih punya 255 ruang di atas
setiap halaman, tapi halaman di 229,5 hanya bisa-naik 25,5 unit dengan menuju
putih murni, sedangkan halaman di 31,4 punya 223,6 tersedia. Satu alpha
karena itu punya bobot perseptual yang berbeda sembilan kali. **Alpha bukan
kuantitas perseptual.**

| | halaman | bounce | hairline | sebagai pecahan halaman |
|---|---|---|---|---|
| light `#E1E7E4` | 229,5 | — | 244,5 (+15,0) | +6,5 % |
| dark `#1A211F` | 31,4 | 51,6 (+20,2) | 48,7 (+17,3) | +55 % |
| dracula `#282A36` | 42,4 | 58,4 (+16,0) | 59,4 (+17,0) | +40 % |

Tema gelap turun dari `0x14` ke `0x0A`. Terukur sesudahnya: hairline +9,0 di dark
dan +8,0 di Dracula,against bounce +20,2 dan +16,0 — jadi bayangan jelas yang
paling terang di tepi terang, yang memang seharusnya begitu.

### Tiga widget mengarang nol untuk telemetry yang belum pernah datang

`acPower`, `batteryPower`, `soc`, `voltage` dan `frequency` dulu non-nullable
dan diisi `?? 0.0` di titik pemanggilan. Jadi BMS yang belum pernah melapor
tampil sebagai **0 %** merah di sebelah `min 20 %` dengan glyph
`battery_alert`, dan meter yang absen sebagai **Unstable 0 V · 0 Hz** merah.
Kedua verdict gagal di nol, jadi ketiadaan menjadi gangguan.

Bagian yang paling jauh jangkauannya adalah **dalam kalimat, bukan angka**. Dengan
angka solar asli dan draw rumah fabricated nol, kalimat penutup
`LivePowerCard` telah menjadi **"The array covers the house load"** — klaim
percaya diri tentang rumah pengguna sendiri, diturunkan dari data yang tidak
pernah datang, dan tanpa tanda minus yang membuat pembaca curiga.

---

## Yang tidak bisa dilihat alat mana pun

Empat bug di bawah ini sekarang **terverifikasi bukan vakum**, dan tiga di
antaranya menangkap bug-nya sendiri saat dipulihkan ke keadaan rusak.

### Strip tanggal tampil `S, M, W, T, T, F, S`

Di skala font 2,0 tiap nama hari terpotong jadi **satu huruf**. Itu deret
inisial, dan yang ambigu — Sabtu dan Minggu berbagi huruf, begitu pula Selasa dan
Kamis.

Komentar yang dikirim bersama perbaikan pertama mengklaim "nama hari yang
terbaca 'Mo' alih-alih 'Mon' tetap nama hari". Klaim itu **salah**, dan hanya
layar yang bisa menunjukkannya: di 2x bahkan dua huruf tidak muat chip 42 dp.

Chip sekarang mengambil lebar yang memang dibutuhkan teksnya, diukur dengan
`TextPainter` terhadap skala teks pengguna, dan strip-nya bergulir horizontal
alih-alih memotong.

### Label arah baterai tampil `Dischar…`

Ini yang paling tidak boleh di APK ini. Arah pack harus dibawa oleh label,
karena tanda minus bukan arah, dan keduanya sengaja tidak bisa saling
ditukar — sekali BMS pernah membalik semua tampilan baterai tanpa satu pun indikator
merah.

Membungkus saja ditolak, karena `Row`-nya `CrossAxisAlignment.start`, jadi label
dua baris akan menurunkan angka *Discharging* satu baris di bawah angka Solar
dan House dan terbaca sebagai kegagalan render. Ketiga blok label kini
membagikan satu tinggi terukur, sehingga angkanya tetap sejajar di semua skala.

### Empat bug pengukuran di satu widget

Semuanya kesalahan yang sama: **pengukuran yang menulis ulang nilai yang
diukurnya**.

- Pengukuran nama hari memakai `TextStyle` tulis-tangan, sedangkan theme
  memasok `family: Roboto` dan `letterSpacing: 0,3`. Tiga karakter dikali 0,3
  adalah 0,9 px kurang — chip 0,75 px terlalu sempit **terpotong**.
- `Flexible` rbagi baris sebanding dengan nilai flex-nya, jadi ketika tiga
  label mau lebih banyak ruang daripada yang ada, **semua** slot menyusut
  proporsional — termasuk yang terpanjang, yang tetap tidak muat.
- Blok label 45 % terlalu pendek **di semua skala**, termasuk 1,0. Probe
  tinggi barisnya juga memakai `TextStyle` tulis-tangan: theme menyetel
  `height: 1,4`, jadi probe menjawab 11 px sementara paragraf yang benar-benar
  dicat butuh 16. `SizedBox` yang terlalu pendek tidak overflow — ia **diam-diam
  gagal menggambar sisanya**, tanpa stripe dan tanpa exception.
- Baris charge overflow 38 px di 320 dp pada skala 3,0, karena `Charge` dan
  `80%` adalah anak `Text` biasa dan masing-masing dapat lebar tak terbatas.
  Yang ini sudah lama ada dan tidak terkait skala font.

---

## Yang hilang: gerbang biometrik

Dihapus sepenuhnya. `_SplashRouter` sekarang langsung ke dashboard bila ada
sesi, dan langsung ke `LoginScreen` bila tidak. Tidak ada lock screen, tidak ada
tombol sidik jari, tidak ada faktor kedua.

Bersama-nya: dependensi `local_auth`, izin `USE_BIOMETRIC`, dan kunci
`NSFaceIDUsageDescription` di `ios/Runner/Info.plist` — yang mengirim string
Face ID ke pengguna untuk fitur yang sudah tidak ada, dan ditemukan hanya karena
penghapusan diaudit dan tidak diasumsikan lengkap.

**`MainActivity` kini `FlutterActivity` biasa.** Ia mewarisi
`FlutterFragmentActivity` untuk tepat satu alasan: `local_auth` butuh Fragment
untuk menampung `BiometricPrompt`. Alasan itu hilang, jadi superclass-nya ikut
 hilang. Ini dinyatakan eksplisit karena "kenapa ini bukan
`FlutterFragmentActivity`?" adalah pertanyaan yang akan ditanyakan pembaca
nanti, dan grep repo sekarang tidak menemukan apa pun.

**Apa yang dikorbankan:** lock screen adalah satu-satunya hal yang memisahkan
seseorang yang memegang HP terbuka dari telemetry app ini. JWT di
`flutter_secure_storage` tidak terpengaruh, dan seluruh postur keamanan lain di
`AGENTS.md` tidak pernah bergantung pada gerbang biometrik.

---

## Data hilang yang tidak terlihat

- **Riwayat alarm kehilangan rekaman.** `addAlarm` adalah read-modify-write
  tanpa serialisasi, dan dashboard memanggilnya `unawaited` sekali per sinyal
  baru dalam satu loop sinkron. Empat alarm simultan — pemicunya realistis
  adalah soket MQTT putus, sehingga semua `stale_*` aktif bersamaan — menjalankan
  empat siklus bertumpuk yang membaca snapshot sama, dan hanya tulisan terakhir
  yang selamat. Banner dashboard menampilkan keempatnya sementara riwayat yang
  dibuka pengguna untuk mencari tahu apa yang terjadi menampilkan satu.
- **Cache telemetry offline bisa menyusut.** Dua penulis berbagi
  `cached_telemetry` dan jangkauan mereka tidak sama: poll REST punya keempat
  perangkat, layanan WebSocket hanya yang pernah didengarnya. Satu frame socket
  dari satu perangkat menghapus tiga lainnya. Tulisan sekarang merge dengan
  yang ada, **baru di atas lama**.
- **Payload telemetry `null` menjadi nol yang percaya diri, dan mencapai mesin
  alarm.** `soc` null menghasilkan `Battery charge low: 0%` pada severity
  **critical**, dipersistensi dan dinotifikasi.

---

## Yang tidak punya feedback sama sekali

- **Empat kontrol.** `Material` tunggal milik `Scaffold` mengecat fitur ink-nya
  *di bawah* subtree anaknya sendiri, dan badan dashboard adalah `ColoredBox`
  yang opaque — sehingga splash tombol retry dan tombol kalender hilang, tak
  terlihat, bukan redup. Di app yang kosakatanya justru "no ripple, tekan
  geometris", keempatnya adalah satu-satunya kontrol tanpa feedback dari kedua
  jenis. Perbaikan sama seperti `AppCard`: `Material` transparan di antara kotak
  dan konten.
- **Indikator Live/Polling membeku di dua tab.** `_realtimeConnected` berubah
  hanya lewat `setState` biasa, jadi `Bound` yang tokennya melompatinya
  menyimpan anaknya. delapan header grafik beku, dan sama sekali tidak terlihat
  sampai ganti halaman, ganti tanggal, atau tarik-torefresh.

---

## Yang lebih jujur, bukan lebih ampliando

- **Kegagalan permintaan grafik dilaporkan "No data for this range".** Satu
  kalimat yang tidak netral: ia memberi tahu pengguna greenhouse tidak
  menghasilkan apa-apa, yang mengirim mereka keluar melihat tanaman, untuk apa
  yang hampir selalu masalah jaringan.
- **Hitungan "unsaved defaults" menghitung range, bukan limit.** Tertulis
  "3 limits" tepat di bawah lima field bertanda "Not saved yet".
- **Layar CCTV idle mengulang hal yang sama empat kali** — termasuk banner
  permanent yang menempati ruang yang justru dibutuhkan peringatan nyata.
- **Skala font 2,0 pernah membuat empat widget memotong dirinya sendiri.**
  Strip tanggal, label arah baterai, readout laporan energi, dan grid metrik.

---

## Yang perlu Anda putuskan

**Halaman listrik masih menempatkan tegangan, arus, dan daya pada satu sumbu Y
yang sama**, dengan alasan "satu sistem listrik dengan besaran sebanding". Itu
**terbukti salah**: di halaman AC ketiganya membaca 220 V, 0,11 A, dan 18,5 W —
tiga orde besaran — dan ketiga kurvanya tergambar sebagai garis horizontal.
Sumbu, dan karena itu bentuk setiap kurva di atasnya, adalah sifat satuan, bukan
sifat listrik. persis hal yang aturan file itu sendiri larang.

Memecahnya per satuan sudah diimplementasikan dan diukur, tapi **sengaja tidak
dimasukkan**, karena tiga biayanya hanya bisa Anda nilai: kehilangan hubungan
tegangan/arus/daya yang dibaca teknisi inverter dari inverter, ruang vertikal
tiga kali lipat pada tiga halaman paling sering dipakai, dan setiap grup
berseri tunggal kehilangan trid merah/hijau/biru demi aksen pengguna.

Yang **ada** di kode: klaim salahnya dikoreksi di tempatnya, dan test baru
mengunci daftar key history tiap halaman sehingga regrouping terbukti tidak
bisa mengubah apa yang diminta ke ThingsBoard. Perubahannya reversibel di satu
list.

---

## Yang masih belum terverifikasi

- Scanline melintasi **tepi atas** kartu. Separuh terang pasangan Dracula belum
  pernah disampel.
- Tidak ada telemetry frame-time yang pernah diambil.
- Rute `LoginScreen` setelah penghapusan gerbang biometrik belum dilihat di layar.
- Pengelompokan grafik di atas — satu-satunya perubahan yang benar-benar
  membutuhkan mata Anda.

---

## Gerbang

`flutter analyze` bersih · 38 file test hijau, **581 test**, dijalankan per file ·
`gradlew :app:testDebugUnitTest` BUILD SUCCESSFUL.

## Build

```
flutter build apk --release
```

Sertifikat tetap sama seperti 1.7.0, diverifikasi SHA-256:

```
504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5
```

`versionName=1.7.1`, `versionCode=15`, APK Signature Scheme v2 `true`.
Tidak ada perubahan signing.