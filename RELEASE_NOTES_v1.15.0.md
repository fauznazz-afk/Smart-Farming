# 1.15.0

Asisten AI di dalam aplikasi. Bertanya soal pembacaan — "baterinya sedang
apa?", "hari ini sudah menghasilkan berapa?" — dan dijawab dari data yang
sekarang terlihat di layar.

Nomornya minor karena ada fitur dan ada permukaan baru: satu tombol, satu
layar, satu bagian Settings.

> **Rilis ini mengandung cacat, dan semuanya diperbaiki pada 13 Oktober 2026.**
> API key yang diketik **tidak tersimpan** kecuali tombol Enter keyboard
> ditekan; Gemini dan Groq **tidak bisa dipakai sama sekali** karena model
> default-nya sudah di-shut-down provider sebelum rilis; setiap permintaan
> OpenAI akan gagal 400; dan tombolnya **menutupi satu pembacaan**. Rilis ini mengandung
> sebaiknya diperlakukan sebagai percobaan pertama yang gagal — bukan fondasi
> untuk dibangun. Daftar perbaikannya ada di bagian [Yang diperbaiki] di bawah.

## Yang ditambahkan

- **Tombol di app bar dashboard** membuka layar chat. Kosong, layar itu
  menampilkan blok telemetry yang **persis sama** dengan yang dikirim ke model,
  jadi sebelum bertanya pertama kali user sudah bisa melihat sendiri apa yang
  aplikasi lihat.
- **Empat pertanyaan siap pakai** untuk tegangan, baterai, batas alarm, dan kWh
  harian — supaya tidak perlu mengetik dulu untuk melihat apakah ini bekerja.
- **Settings → AI assistant**: pilih provider, tempel API key, konfirmasi nama
  model. Provider: **OpenAI, Anthropic (Claude), Google Gemini, DeepSeek, Groq,
  OpenRouter**, atau endpoint apa pun yang kompatibel dengan OpenAI.
- **Provider ini memakai API key milik sendiri.** Aplikasi tidak membawa key
  apa pun dan tidak jatuh ke nilai apa pun: tanpa key, asisten mati, dan tetap
  mati setelah aplikasi ditutup. Key ditulis ke `flutter_secure_storage`,
  berdampingan dengan token ThingsBoard — **bukan** ke `SharedPreferences`.
- **Snapshot telemetri**, bukan isi aplikasi. Empat device (baterai, PZEM,
  sensor lingkungan, kolam ikan) plus total kWh hari ini, diformat jadi satu
  blok dan ditanam ke system prompt.

## Yang diperbaiki

Lima cacat, semuanya ditemukan di perangkat pada 13 Oktober 2026 — setelah
rilis ini, satu demi satu:

- **API key tidak tersimpan.** Section hanya menulis pada `onSubmitted`, yaitu
  tombol "done" di keyboard. Tempel key lalu tap back — yang dilakukan semua
  orang — tidak menulis apa pun. Sekarang writes di-debounce saat mengetik dan
  di-flush saat section ditutup, lewat jalur mana pun.
- **Layar asisten tidak membaca ulang key.** Buka Settings dari layar chat,
  tambah key, langsung kembali — dan layar yang sama masih menulis "No API key
  yet". Terlihat seperti save-nya gagal padahal tidak.
- **Dua dari enam model default sudah di-shut-down provider-nya.**
  `gemini-2.0-flash` di-retire Google pada 1 Juni 2026 dan
  `llama-3.3-70b-versatile` oleh Groq pada 16 Agustus 2026 — keduanya sudah
  mati **sebelum** rilis ini, jadi Gemini dan Groq menjawab 404 sejak awal.
  Semua default sekarang dibaca ulang dari daftar model provider, dan 404
  sekarang menyebut nama modelnya tidak dikenali, bukan sekadar angka status.
- **Setiap permintaan OpenAI akan gagal 400.** Body mengirim `temperature` dan
  `max_tokens`, dua parameter yang ditolak model reasoning OpenAI sekarang
  sebagai parameter tidak didukung. Keduanya tidak dikirim lagi; panjang jawaban
  dikendalikan lewat prompt.
- **Tombolnya menutupi satu pembacaan.** `FloatingActionButton` berada di atas
  kartu terakhir di setiap halaman. Sekarang ikon di app bar, sebelah Alarm
  History — tidak menutup apa pun, dan ada di keempat tab seperti yang lain.

## Sanitasi input

Tiga lapis, dan ketiganya perlu:

1. **Karakter kontrol dibuang.** Byte yang lolos dari copy-paste berarti
   sesuatu bagi pemformat di hilir dan tidak berarti apa-apa bagi pembaca.
2. **Whitespace dirapatkan.** 500 karakter, dipotong di batas kata — model
   tidak pernah menerima separuh kata dan memutuskan bahwa pemotongan itu
   layak dibicarakan.
3. **Prompt menyatakan cakupannya.** Jawab dari blok telemetry atau katakan
   angkanya tidak ada di sana; jangan pernah mengarang. Teks di dalam blok
   diperlakukan sebagai data yang dilaporkan, **bukan** perintah yang
   dijalankan — blok itu berisi data milik user, jadi baris prompt-injection
   bisa tiba di sana.

Yang ditampilkan di gelembung chat **adalah** teks yang dikirim, persis sama.
Mengirim satu dan menampilkan yang lain membuat pemotongan 500 karakter tidak
terlihat.

## Keamanan transport

- Endpoint harus **HTTPS**; ditolak kalau ada userinfo di URL-nya.
- **Redirect ditolak.** 307 akan mengirim ulang request — header ikut — ke host
  mana pun yang disebut redirect, dan di situlah key pengguna berada. Ini
  risiko yang sama dengan redirect token ThingsBoard yang sudah ditutup duluan.
- Key hanya pernah ada di header, tidak pernah di body request, tidak pernah di
  log, dan tidak pernah ikut ke pesan error.
- Batas baca 256 KB dan timeout 45 s; yang lebih besar berhenti dibaca.

## Batasan yang perlu diketahui

- **Tidak ada streaming.** Balasan muncul sekaligus setelah model selesai.
- **Riwayat hanya di memori.** Tutup layar, riwayat hilang. Maksimal enam turn
  terakhir ikut dikirim.
- **Yang dikirim adalah snapshot.** Blok itu berisi kondisi *sekarang*;
  pertanyaan tentang "kemarin" atau tren tidak ada isinya, dan model
  diarahkan untuk mengatakannya.
- **Nama model bisa basi tanpa pemberitahuan.** Dua dari enam default di rilis
  ini memang sudah mati waktu rilis itu terbit, jadi ini bukan risiko teoretis.
  Semuanya sekarang dibaca dari daftar model provider pada 13 Oktober 2026 dan
  bisa diedit di Settings, tapi tabel ini akan basi lagi — satu test menjaga
  supaya tidak ada nama yang **sudah** di-shut-down yang masuk ke sini.
- **Biaya dan privasi ada di tangan pengguna.** Provider yang dipilih adalah
  pihak ketiga; snapshot telemetri — termasuk SOC baterai dan kondisi kolam —
  terkirim ke sana setiap kali user bertanya.
- **Tidak ada uji widget untuk layar chat.** Butuh HTTP client tiruan; lebih
  besar daripada fiturnya sendiri.

## Verifikasi

- `flutter analyze` bersih
- **800 test Dart / 62 file**, plus 11 test Kotlin (`AlarmParityTest`,
  `requireAllowedThingsBoardHost`) — BUILD SUCCESSFUL
- Fingerprint signing build ini **cocok** dengan `PRD_GitHub_Release_Process.md` §3:
  `504d13ee…64b5`
- `versionName=1.15.0`, `versionCode=30`, scheme v2 `true`
- `aapt2 dump xmltree` atas APK release: **tidak ada** `AlarmDebugReceiver`
- 28 test di `test/ai_provider_test.dart` menutup sanitasi, batas panjang,
  pemangkasan riwayat, kedua dialek provider, parse balasan, dan — setelah dua
  default mati ditemukan — daftar nama model yang sudah di-shut-down
- 5 test di `test/ai_settings_test.dart` menutup "key tersimpan tanpa Enter dan
  tanpa tekan back", flush saat section ditutup, dan penghapusan key yang tidak
  dibatalkan oleh write yang masih tertunda

## Yang belum pernah dilihat di perangkat

Bagian ini berlaku untuk **rilis 1.15.0 apa adanya**. Setelah lima cacat di
atas diperbaiki, tiga hal sudah terbukti di perangkat: key tersimpan tanpa
tombol apa pun, 404 Google muncul sebagai pesan yang benar tentang nama
model, dan tombolnya tidak lagi menutupi pembacaan.

Yang **masih** belum terbukti:

- Satu jawaban model nyata melewati parse untuk keenam provider. Gemini sudah
  terbukti bisa menjawab (error-nya 404, artinya request-nya sampai), tapi belum
  ada satu balasan sukses pun yang terlihat di layar.
- Bubble chat tampil dengan tinggi yang wajar di layar sempit, dan keyboard
  tidak menutupi composer.
- Nama model default yang baru dibaca dari daftar provider — sudah dicocokkan ke
  dokumen resmi masing-masing, belum dicoba satu per satu terhadap endpoint
  aslinya memakai key milik orang.

## Cara memasang

```bash
adb install -r app-release.apk
```

Gunakan `-r`, bukan uninstall. Build release-signed, jadi bisa dipasang di atas
build release sebelumnya tanpa kehilangan login. Build debug **tidak bisa**
dipasang di atas build release karena signing key-nya berbeda.