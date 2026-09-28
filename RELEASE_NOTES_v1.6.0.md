# EnerGrow 1.6.0 (build 12)

**Rilis:** 28 September 2026
**Tag:** `v1.6.0`
**APK:** `EnerGrow-v1.6.0.apk`
**Perubahan sejak 1.5.0:** 35 entri di `CHANGELOG.md`

Rilis ini memperluas aplikasi dari tiga perangkat menjadi **empat**: selain
sistem PLTS, aplikasi kini punya halaman **Hydroponics** dan **Fish** yang
membaca sensor kualitas air dari device ThingsBoard keempat — dengan alarm,
batas, dan kamera masing-masing. Navigasi disusun ulang jadi empat tab, dan
integrasi cuaca yang tidak lagi terpakai dibuang beserta izin lokasinya.

---

## Yang paling berubah

### Halaman Hydroponics dan Fish

**Hydroponics** menggabungkan sensor greenhouse (suhu, kelembapan, TDS, cahaya)
dengan kamera yang dulu berdiri sendiri di tab CCTV. **Fish** adalah halaman
baru untuk device ikan: pH, suhu air, turbidity, dan tingkat air, plus kamera
kedua (`?src=cam2`) dengan pengaturan dan penyimpanan amannya sendiri.

Ikan bukan hanya tampilan. Device fish ikut serta penuh dalam modul alarm
native — "data segar berhenti" pada sepuluh menit dan "perangkat berhenti
melapor" pada enam puluh menit aktif sejak awal, tanpa perlu konfigurasi apa
pun. **Fish tank alerts** menambahkan batas yang bisa diatur: pH 6–8,5, suhu
air 20–30 °C, turbidity ≤ 100 NTU — masing-masing sisi bisa dikosongkan, dan
kosong berarti tidak dipantau. Grid Fish di dashboard dinilai terhadap batas
yang sama dengan yang dipakai alarm, jadi halaman dan notifikasi tidak bisa
berselisih soal apa batasnya.

### Navigasi bawah kini empat tab

PV, AC, dan Battery menjadi satu tab **Power** dengan pemilih bersegmen:
ketiganya adalah tiga tampilan dari satu sistem listrik. Enam tab tidak muat —
standar Material menyebut 80 dp sebagai lebar minimum per tujuan, dan ponsel
ini 380 dp; label "Hydroponics" terukur 62 dp di slot 60 dp dan memang
terpotong di layar. Masuk tab Power langsung mengambil ketiga sub-tampilan,
jadi berganti sub-tab tidak lagi menunggu request — dan pindah sub-tab tidak
lagi menampilkan angka layar sebelumnya.

### Cuaca (OpenWeatherMap) dihapus

Kartu cuaca menampilkan angka yang sudah terlihat dua kali: output PV di
Energy analytics dan cahaya di Hydroponics. Yang hilang adalah suhu luar,
angin, tutupan awan, dan prakiraan — `power_dc` dan `lux` adalah pengukuran,
bukan prediksi. Bersamaan dengan itu pergi `geolocator`, izin lokasi
(`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`), dan **API key — yang
merupakan satu-satunya kredensial aplikasi ini yang tersimpan di luar secure
storage**.

### Tanda baterai kembali benar, dan kini diungkit test

BMS diganti, dan konvensinya berbalik: paket lama melaporkan `Power -12.92 W`
saat isi baterai *naik*, paket baru melaporkan `Power -22 W` saat isi baterai
*turun*. Hero card sempat menampilkan "Charging" pada paket yang sedang
menguras. Pemetaan kini terpusat di satu fungsi dengan pengukurannya tercatat
di komentar, dan test gagal dengan pesan yang menyebut apa yang harus diukur
ulang — jadi pertukaran BMS berikutnya tidak bisa diam-diam membalik semua
tampilan.

---

## Perbaikan yang mungkin Anda rasakan

- **Menyimpan Pengaturan tidak lagi diam** ketika ada satu pun field batas yang
  dikosongkan. Dulu tombol Save seolah tidak berfungsi (tidak pop, tidak ada
  pesan), dan perubahan ambang tidak sampai ke pemeriksa latar sampai aplikasi
  dibuka ulang. Kini error pun ditampilkan, dan regression test mengunci
  gejalanya.
- **Mengosongkan sebuah batas benar-benar mematikan sisi itu**, bukan
  mengembalikan nilai default. Menyimpan pertama kali adalah saat default
  berlaku.
- **Menyentuh chart tidak lagi membangun seluruh halaman** dua kali per gestur —
  chart menutupi sebagian besar halaman Power, jadi dampaknya terasa di setiap
  scroll.
- **Toggle Environment alerts mematikan juga warna grid**, bukan hanya aturan
  latar. Tag "out of range" ikut; tag "Stale data" sengaja tetap tampil —
  sensor mati adalah fakta tentang data, bukan batas yang di-setel.
- **Tombol CSV menampilkan "Preparing CSV…"** saat bekerja, dan guard
  ketuk-ganda jadi terlihat, bukan hanya aktif.
- **Mengetuk notifikasi alarm membuka riwayat alarm.** *Perbaikan ini belum
  direproduksi di perangkat — perlu notifikasi yang benar-benar muncul.*
- Angka terakhir tidak lagi diumumkan ke pembaca layar sebagai
  `Instance of 'MetricDef'`.
- Overflow 12 px di Background checks dan label
  "Battery optimisationActive" (dua tombol dan satu kolom label yang terlalu
  sempit) diperbaiki.
- **Cache offline tidak lagi saling menimpa antar device** — empat device yang
  mengambil dalam satu poll terakhir menulis menimpa bucket satu sama lain,
  dan jalur offline pun datang kosong tanpa log apa pun.
- WebSocket tidak lagi menandai setiap frame sebagai perubahan, dan
  `ConnectionHealthService` tidak lagi memberi tahu UI puluhan kali per detik —
  dua penyebab rebuild besar yang tidak perlu.
- **Konvensi tanda** dibaca dari satu tempat oleh hero card dan strip status;
  dulu keduanya bisa bertengkar di layar yang sama (satu membaca `power`,
  satu membaca `current < 0` tanpa deadband).

---

## Batasan yang diketahui

Bacalah sebelum memutuskan ini memenuhi kebutuhan Anda. Rinci dan berbukti di
`FEATURE.md` §18.

- **Halaman Hydroponics dan Fish belum punya grafik riwayat.** Chart masih
  terikat tiga seri tegangan/arus/daya.
- **Prakiraan cuaca tidak ada lagi** (tergantung kebutuhan, lihat di atas).
- **Nilai turbidity terbaca 2396 NTU** — untuk air jernih ambangnya di bawah
  30 NTU. Kemungkinan sensor belum dikalibrasi; belum ditelusuri.
- **Laporan energi memakai kebijakan pembanding berbeda** dari Energy
  analytics (tanpa ambang 0,1 kWh), jadi perbandingan ekstrem masih bisa
  muncul di sana.
- **Alarm background adalah fitur Android saja.** Tidak ada push notification
  dari server; yang ada hanya pengecekan lokal terjadwal.
- **Produksi harian adalah estimasi,** bukan pengukuran, dan laporan energi
  mengintegrasi ulang daya rata — angkanya tidak akan sama dengan penghitung
  energi ThingsBoard.
- **Layout diuji di satu ukuran layar saja** (1220×2712 @ 520).

## Yang belum pernah dilihat di perangkat

- **Halaman Fish dan Hydroponics belum pernah dibuka di perangkat** — semuanya
  sudah lolos test, tapi belum pernah dilihat di layar.
- Nilai bertanda negatif di hero card (verifikasi terakhir baterai standby).
- Stream CCTV end-to-end di URL produksi, dan stream kedua `?src=cam2`.
- Dua WebView hidup bersamaan (cam1 di Hydroponics + cam2 di Fish) — beban
  memorinya belum diukur.
- Layout di density selain 520.
- Laporan energi dengan data bulan penuh.

---

## Pemasangan

```bash
# upgrade dari versi sebelumnya — pertahankan data dan sesi ThingsBoard
adb install -r EnerGrow-v1.6.0.apk

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
| `flutter analyze` | **No issues found!** |
| `flutter test` | **273 lulus** (19 file) |
| `cd android && ./gradlew :app:testDebugUnitTest` | **11 lulus** (parity alarm + host allowlist) |
| `flutter build apk --release` | sukses, **60,3 MB** (146 s) |
| `apksigner verify` | signature valid, 1 signer |
| Fingerprint SHA-256 | `504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5` — **cocok** dengan PRD §3 |
| `apkanalyzer` versionName / versionCode | **1.6.0 / 12** |
| `AlarmDebugReceiver` di release APK | **0 kemunculan** (komponen debug tidak ikut) |
| Uji install di perangkat | **tidak dijalankan untuk artefak ini** — perangkat uji memakai build debug, dan berpindah ke release berarti uninstall (sesi ThingsBoard hilang); keputusan dilewati pada 28 Sep 2026. Upgrade-in-place release-ke-release terakhir teruji di 1.5.0 (`adb install -r` dari 1.4.0, data utuh) |

Detail lengkap ada di `CHANGELOG.md`.