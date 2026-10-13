# 1.15.0

Asisten AI di dalam aplikasi. Bertanya soal pembacaan — "baterinya sedang
apa?", "hari ini sudah menghasilkan berapa?" — dan dijawab dari data yang
sekarang terlihat di layar.

Nomornya minor karena ada fitur dan ada permukaan baru: satu tombol, satu
layar, satu bagian Settings.

## Yang ditambahkan

- **Tombol mengambang di dashboard** membuka layar chat. Kosong, layar itu
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
- **Model default tebakan.** Provider sering mengganti nama model tanpa
  pemberitahuan. Namanya bisa diedit di Settings, jadi yang salah berjarak satu
  ketikan dari diperbaiki.
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
- 25 test baru di `test/ai_provider_test.dart` menutup sanitasi, batas panjang,
  pemangkasan riwayat, kedua dialek provider, dan parse balasan

## Yang belum pernah dilihat di perangkat

Layar chat dan bagian Settings **belum diuji di perangkat sungguhan** —
keduanya hanya lewat analyzer dan test. Belum terbukti: bubble benar-benar
tampil dengan tinggi yang wajar di layar sempit, keyboard tidak menutupi
composer, dan satu jawaban model nyata melewati parse untuk keenam provider.
Nomor model default juga belum pernah dicoba terhadap endpoint aslinya.

## Cara memasang

```bash
adb install -r app-release.apk
```

Gunakan `-r`, bukan uninstall. Build release-signed, jadi bisa dipasang di atas
build release sebelumnya tanpa kehilangan login. Build debug **tidak bisa**
dipasang di atas build release karena signing key-nya berbeda.