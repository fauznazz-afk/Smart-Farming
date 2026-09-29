# EnerGrow 1.6.1 (build 13)

Rilis perbaikan. Tidak ada fitur baru dan tidak ada perubahan yang bisa
membatalkan data — semua yang diperbaiki adalah sesuatu yang menampilkan
angka yang salah, atau menarmekan alarm yang tidak mungkin lagi terpenuhi.

## Yang diperbaiki

### Alarm turbidity yang tidak pernah bisa bersih

Ini satu-satunya perubahan yang benar-benar penderita. Batas turbidity 100 NTU
pernah menjadi default aplikasi, dipilih dari panduan akuakultur yang menyatakan
air di atas 100 NTU sudah keruh. Sensor di perangkat uji ternyata membaca **2396
lalu 3000 NTU** untuk tangki yang sama — sekitar 30 kali di atas angka mana pun
yang menggerakkan panduan itu, jadi sensor ini jelas bukan pada skala yang
diasumsikan, dan belum ada yang memastikan apa yang diukur.

Begitu batas itu tersimpan, ia menjadi aturan yang hidup, dan ponsel mulai
memposting:

```
EnerGrow: Warning alarm
Turbidity too high: 3000.0 NTU (limit 100.0 NTU)
```

setiap menit, tanpa henti, karena tidak ada konfigurasi yang bisa
memenuhinya. Dua perbaikan:

- **Batas atas dihapus.** Sebelumnya 1000 NTU, jadi field menolak apa pun di
  atasnya — padahal sensor membaca 3000. Tidak ada lagi plafon; nilainya bisa
  sesuka Anda sekarang juga.
- **Defaultnya dihapus.** Tidak ada angka lain yang bisa jujur di sini, dan
  tebakan yang meleset ke atas lebih buruk daripada tidak punya batas sama
  sekali, karena itu menciptakan alarm yang mustahil selesai. Field-nya mulai
  kosong, dan subtitle section yang sudah ada — *"Blank limits are not
  monitored"* — sekarang menjadi satu-satunya penjelasannya.

Efek sampingnya bagus: halaman Fish sekarang benar-benar menampilkan
turbidity sebagai pelanggaran — border merah, caption `≤ 100`, tag
**1 out of range** — dan untuk pertama kalinya grid dan notifikasi sepakat
tentang kondisi yang sama, dengan teks yang persis sama di keduanya.

### Pager yang berjalan melewati ujungnya

Delapan geser ke kiri di tab Overview mendarat di **halaman sembilan** dari
pager yang hanya punya empat halaman. Penyebabnya kelas fisika yang menahan
gestur chart agar tidak sekaligus mengganti halaman: ia memutuskan apakah
gestur **diterima**, tapi tidak pernah memutuskan apa yang terjadi saat gestur
**dilepas**. Fling-nya jatuh ke simulasi gesekan biasa, bukan pegas
`PageScrollPhysics`, sehingga halaman meluncur ke mana pun gesekan berhenti
sambil terus mengambil kecepatan melewati ujung konten.

Efek samping kedua yang lebih halus ikut hilang: halaman mati total setelah
chart disentuh, sampai rebuild tak terduga datang — sampai sepuluh detik di
dashboard yang polling tiap sepuluh detik.

### Kartu dan laporan beda pendapat

Energy report menampilkan `-100% from the previous period` untuk periode
sebelumnya yang hanya menghasilkan 0,01 kWh, sementara kartu di dashboard
menampilkan `Nothing to compare yet` untuk **angka yang sama** di sesi yang
sama. Ambang 0,1 kWh itu sudah ada di kartu dan tidak pernah ada di laporan —
dan keduanya adalah dua literal terpisah, jadi tinggal satu edit yang terlupa
untuk membuat mereka makin beda.

Keduanya sekarang mengimpor `kMeaningfulEnergyKwh` dari
`lib/utils/energy_comparison.dart`. Kalimatnya tetap berbeda per permukaan,
dan itu disengaja: dua tile di kartu membungkus secara independen, sedangkan
label laporan punya satu baris penuh.

### Oktober, Desember

`_monthNames` mencantumkan `Oktober` dan `Desember` di antara sepuluh nama
bahasa Inggris, di aplikasi ber-locale `en_US`. Berbeda dari cacat di atas,
yang ini **sampai ke file yang Anda ekspor** — `csv_builder.dart` menulis
`formatMonthLabel` ke baris `Period`. `formatMonthLabel` belum punya test
sama sekali; sekarang ada dua belas assertion.

## Yang ditambahkan

- **`EnergySummaryCard` punya widget test untuk pertama kalinya.** Widget
  339 baris di tab Overview yang tidak pernah dilihat test mana pun, di repo
  yang pernah punya tiga regresi label lolos analyze, lolos release build, dan
  lolos seluruh test. Delapan belas test sekarang mengunci judul, pemilih
  periode, catatan metode, kedua tile, blok forecast, empty state, dan ambang
  perbandingan 0,1 kWh — dengan setiap string yang diassert membawa baris
  widget asal-usulnya, jadi rename gagal di sini dan bukan di tangan pengguna.
- **Batas turbidity bisa di mana saja.** Cap 1000 NTU dihapus, dan grup test
  baru `fish sensor bounds` menutup jebakan yang membuatnya lolos: test batas
  sensor yang ada hanya pernah menyentuh `envRanges`, tidak pernah
  `fishRanges`.
- **`ChartBounds.maxY` tercover untuk peak non-positif.** Cabang yang harus
  menjaga `maxY` di atas `minY`, kalau tidak fl_chart menggambar sumbu
  terbalik. Dan test daftar kategori Settings ternyata mengassert delapan dari
  sepuluh judul, kurang "Fish tank alerts" **dan** "Background checks".

## Batasan yang diketahui

- **Skala sensor turbidity belum diketahui.** Apa pun yang Anda masukkan
  sebagai batas adalah pilihan Anda, bukan nilai yang benar. Sekitar 30 NTU
  dianggap air jernih, jadi 3000 berarti sensor ini kemungkinan besar belum
  dikalibrasi atau satuannya berbeda. Ini pertanyaan perangkat keras, bukan
  kode.
- **Halaman Hydroponics dan Fish belum punya grafik.** pH dan turbidity tidak
  bisa di-chart tanpa generalisasi `TelemetryChartCard` dulu, karena daftar
  sufiksnya masih `voltage`/`current`/`power` dan `HistoryKeys` masih tiga
  field. Ini pekerjaan refactor, bukan tambahan.
- **Tidak ada prakiraan apa pun.** OpenWeatherMap dicabut di 1.6.0. `power_dc`
  dan `lux` adalah pengukuran, bukan prediksi — keduanya tahu apa yang terjadi
  sekarang, tidak tahu besok.
- **Alarm background adalah fitur Android saja.** Di iOS, desktop, dan web
  `AlarmBridge` jadi no-op.
- **Nama Oktober dan Desember belum dilihat di perangkat.** Date picker
  laporan energi tidak bergerak melewati bulan berjalan, jadi perbaikan itu
  hanya bertumpu pada test.

## Pemasangan

| | |
|---|---|
| Berkas | `EnerGrow-v1.6.1.apk` |
| Ukuran | 57,5 MB |
| `versionName` | 1.6.1 |
| `versionCode` | 13 |
| `minSdk` / `targetSdk` | 24 / 36 |
| Sidik jari signing | SHA-256 `504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5` |

Naik dari 1.6.0 dengan **signature yang sama**, jadi `adb install -r` atau
pemasangan di atas 1.6.0 bekerja tanpa kehilangan sesi ThingsBoard. Unggahan
melalui Android juga harus diterima dari sumber tak dikenal.

Menaikkan build number atau mengganti rilis: uninstall dulu, dan itu menghapus
sesi ThingsBoard — harus login ulang.

## Hasil verifikasi

| Yang | Hasil |
|---|---|
| `flutter analyze` | No issues found! |
| `flutter test` | **320 lulus** di 23 file, dalam delapan batch (mesin 7 GB OOM kalau sekali jalan) |
| `gradlew :app:testDebugUnitTest` | 11 lulus, fixture paritas tidak berubah |
| Signature release | Terverifikasi, cocok dengan sidik jari proyek |
| Komponen debug di APK release | Tidak ada `AlarmDebugReceiver` |

**Di perangkat** (Xiaomi 24090RA29G, Android 16 / API 36): delapan geser ke
kiri berhenti di Fish Tank; grid Fish menampilkan turbidity merah dengan
caption `≤ 100` dan tag "1 out of range"; limit yang tersimpan tampil tanpa
penanda "defaults"; banner Dart dan notifikasi native memakai kalimat yang
identik; energy report menampilkan "+1% from the previous period" dan
"−30% from the previous period"; label `Discharging −28 W` tampil di hero card.

Setelah batas turbidity dikosongkan, `SystemStatusStrip` membaca **"No
alarms"** dan banner turbidity hilang.

**Belum terbukti:** nama Oktober dan Desember di perangkat, stream CCTV
end-to-end, dan layout di ukuran layar selain 1220×2712.
