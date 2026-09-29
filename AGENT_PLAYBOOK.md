# AGENT_PLAYBOOK.md — Cara Bekerja di Repo Ini

Dokumen ini menjawab satu pertanyaan: **bagaimana mengerjakan sesuatu di sini
dengan cepat, paralel, dan tanpa merusak apa yang sudah bekerja.**

`AGENTS.md` berisi *aturan dan alasan*. Dokumen ini berisi *cara kerjanya*.
Baca keduanya; kalau hanya bisa membaca satu, baca `AGENTS.md`, tapi kalau bisa dua,
baca keduanya karena keduanya saling melengkapi.

Untuk apa playbook ini ada: pekerjaan satu sesi selesai jauh lebih cepat daripada
perkiraan, dan hampir seluruh waktu itu habis di membaca kode secara paralel,
bukan di mengedit. Inventaris fitur yang jadi
`FEATURE.md` — 960 baris, 19 seksi — selesai dari empat pembaca paralel.

---

## 1. WAJIB: baca konteks di folder ini sebelum mulai

**Jangan mulai menulis kode sebelum lima file ini terbaca.** Semuanya pendek
kecuali dua, dan ketiganya menjawab pertanyaan yang berbeda.

| # | File | Yang harus Anda dapatkan dari sana |
|---|---|---|
| 1 | `AGENTS.md` | Aturan yang tidak boleh dilanggar **dan alasannya**. Termasuk §"Background alarms are native Kotlin", §"Security posture", §"Colour is never varied automatically", §"The battery sign convention", dan §"dl.google.com is throttled". |
| 2 | `FEATURE.md` | Apa yang **sudah ada**. §18 mencantumkan celah yang diketahui — 4 celah fungsional, 3 simbol mati, 6 perilaku counterintuitive, 5 celah test, dan 8 hal yang belum pernah dilihat di perangkat. |
| 3 | `progress.md` | Riwayat keputusan dan alasannya. §9A "Percobaan yang Gagal - Jangan Diulang" dan §11 "Gotcha" adalah bagian yang paling menyelamatkan waktu. |
| 4 | `CHANGELOG.md` | Section `[Unreleased]` — apa yang sudah dikerjakan tapi belum dirilis, supaya Anda tidak mengerjakannya dua kali. |
| 5 | `PRD_PLTS_Monitoring_App.md` | Arah produk. §7 memuat rekomendasi berikutnya yang **sudah diurutkan** — baca sebelum/usulan jangan membuat prioritas sendiri. |

### Lima pertanyaan yang harus bisa Anda jawab setelah membaca

Kalau ada yang belum bisa Anda jawab, **Anda belum cukup membaca**.

1. **Apakah fitur yang akan saya kerjakan sudah ada?** (`FEATURE.md`)
2. **Apakah pernah dicoba dan dibatalkan?** Kalau ya, apa alasannya? (`progress.md` §9A, `AGENTS.md`)
3. **Apakah ini menyentuh alarm?** Kalau ya, apakah saya menyentuh **kedua** sisi Dart dan Kotlin beserta fixture paritas? (§4 di bawah)
4. **Apakah ada agen peran khusus yang relevan?** `.github/agents/` punya `security-qa-evaluator.agent.md` dan `ui-ux-performance.agent.md` — baca kalau tugasnya cocok.
5. **Apakah saya bisa membuktikan ini di perangkat?** Kalau tidak, saya harus mengatakannya di output, bukan diam-diam melepaskannya.

---

## 2. Bentuk repo, supaya Anda tahu apa yang sedang Anda cari

| Angka | Nilai |
|---|---|
| File Dart di `lib/` | 68 |
| Baris Dart | ~13 200 |
| File Kotlin | 15 (13 di modul alarm) |
| File test | 19, melaporkan **273 test** |
| File terbesar | `lib/screens/dashboard_screen.dart` — 1 745 baris |

Lima file yang paling sering jadi sumber bug, karena isinya besar dan dipakai
semua halaman:

| File | Kenapa |
|---|---|
| `lib/screens/dashboard_screen.dart` | State, polling, riwayat, evaluasi alarm, dan susunan 5 halaman dalam satu file. 1 745 baris. |
| `lib/utils/alarm_rules.dart` | Satu-satunya definisi apa yang dihitung sebagai alarm. Duplikasinya ada di Kotlin. |
| `lib/widgets/liquid_glass.dart` | `LiquidGlassCard` dan `AmbientBackground` dipakai semua kartu. Perubahan di sini terlihat di mana-mana. |
| `lib/services/thingsboard_api.dart` | Client REST, lifecycle token, cache offline. |
| `lib/screens/dashboard/widgets/chart_card.dart` | Chart 3 seri, sumbu, tooltip, statistik. |

---

## 3. Doktrin kerja paralel

### Kapan **tidak** perlu agen

- Jawabannya satu `grep`. Menjalankan agen untuk itu membuang waktu dan
  menambah satu langkah yang bisa gagal.
- Perubahan yang terisolasi di satu file dan mekanisnya sudah jelas.
- Apapun yang butuh `flutter test` — **RAM tidak cukup untuk paralelisme di
  sini** (lihat §5).

### Kapan agen itu benar

| Pola | Agen | Cola |
|---|---|---|
| "Di mana X dibaca?" | `explore` | follow kunci ke penulis **dan** pembacanya |
| "Apakah ini kode mati?" | `explore` | wajib minta bukti grep, bukan kesimpulan |
| "Audit file X" | `general` | read-only kecuali diminta mengedit |
| "Terjemahkan semua string di Y" | `general` | batasi file, larang sentuh yang lain |
| "Buat inventaris fitur" | `general` × N paralel | satu per area, di depan (foreground) |
| "Refactor file 1 541 baris" | `general` | **satu saja**, tidak paralel dengan yang lain |

Aturan yang tidak bisa ditawar:

1. **Jangan pernah menugaskan dua agen ke file yang sama.** Tabrakan editing
   seperti ini menghasilkan perubahan yang setengah jadi dan sangat sulit dideteksi.
2. **Selalu beri scope file eksplisit, termasuk file yang HARUS TIDAK disentuh.**
  Pelajaran: satu agen menerjemahkan string di 40 file dan menyentuh
   `alarm_rules.dart` yang sedang diedit agen lain. Untungnya ketahuan, tapi
   hampir merusak.
3. **Selalu instruksikan agar memverifikasi terhadap kode, bukan dokumen.**
  Instruksi yang dipakai di sini: *"Read CODE, not markdown — several docs in
   this repo are stale."* Kalimat itu mengubah kualitas output secara dramatis.
4. **Jangan minta agen menjalankan `flutter test`.** Satu eksekusi test sudah
   memakan RAM yang tersisa; dua akan OOM.
5. **Jangan pernah meng-*poll* agen latar.** Dia akan memberitahu sendiri. Poll
   itu membosankan dan membuang token.
6. **Jangan menduplikasi pekerjaan agen.** Kalau dia sedang membuat inventaris
   settings, jangan Anda ikut-too membuat inventaris settings.

### Resep yang berhasil di sesi ini

Empat agen `general` paralel, masing-masing satu area, semua read-only, semua
diberi instruksi yang sama soal verifikasi:

```
SCOPE: dashboard_screen.dart + lib/screens/dashboard/widgets/*.dart + charts + utils
RULES: Verify every claim by reading the file. Do not infer from names.
       Say explicitly when something is ambiguous rather than guessing.
OUTPUT: structured inventory + a "not implemented / stubbed" list. English.
Do NOT edit any file. Do NOT run any build.
```

Hasilnya: bukan ringkasan, tapi temuan yang tidak ada di dokumen mana pun —
`_cctvKeepAlive` yang tidak pernah ditulis, `WeatherCard.forecast` yang tidak
pernah dibaca di `build`, `ThingsBoardClient.fetch` yang parameter `deadline`-nya
tidak pernah diisi. Itu tiga dari celah yang paling penting.

Agen keempat (data/service layer) menemukan hal yang paling merusak: energi report
menggunakan **dua kebijakan perbandingan berbeda** dengan kartu analytics, sehingga
kasus `-100%` yang sudah "diperbaiki" di kartu masih bisa muncul di report.

### Kapan agen di latar belakang, kapan di depan

- **Latar** untuk pekerjaan yang berjalan lama dan tidak memblokir Anda
  (build APK, test suite, agen yang hasilnya tidak Anda perlukan untuk keputusan
  berikutnya).
- **Depan** kalau Anda tidak bisa decides hal berikutnya tanpa hasilnya, atau kalau
  Anda tidak mau mengedit file yang sama dengan dia.

Jangan pernah menjalankan `flutter build` di latar belakang lalu mengedit file
Dart yang sedang dikompilasi. Gradle membaca file sewaktu-waktu; hasil build-nya
tidak bisa dipercaya.

---

## 4. Pasangan yang tidak boleh dipisah

Ini pasangan yang kalau hanya disentuh satu sisi, tidak ada yang memberi tahu
selama berminggu-minggu.

### 4.1 Alarm: Dart, Kotlin, dan fixture paritas

```
lib/utils/alarm_rules.dart                          ← formatAlarmMessage
android/.../alarm/AlarmMessageFormat.kt             ← format() (duplikat)
android/app/src/test/resources/alarm_parity_vectors.json
tool/generate_alarm_parity_fixture.dart
```

- Pesan alarm **harus ada dua kali** karena notifikasi dibangun saat Dart tidak
  berjalan.
- `dart run tool/generate_alarm_parity_fixture.dart` mencetak
  `MISMATCH in "..."` kalau yangpnilai ekspektasi sudah basi, lalu **tetap menulis
  file**. Itu bukan berarti selesai: `expected` adalah pin yang menangkap
  pergeseran, jadi harus diperbarui **secara manual** setelah Anda yakin
  perubahannya memang disengaja.
- Setelah mengubah string, jalankan **kedua** sisi:
  `flutter test test/alarm_parity_test.dart` dan
  `cd android && ./gradlew :app:testDebugUnitTest` (Windows: `.\gradlew.bat`).
  Kalau Anda hanya menjalankan yang Dart, Anda belum memverifikasi apa pun.

### 4.2 Aturan alarm: satu daftar untuk dua evaluator

Dashboard dan modul native mengevaluasi **daftar aturan yang sama**. Kalau Anda
menambah tipe aturan baru, keduanya harus ikut — dan `AlarmParityTest.kt` akan
menolak config yang perangkatnya tidak ada di daftar.

### 4.3 Tanda baterai

BMS ini melaporkan **minus saat charging** (terukur di perangkat). Tiga aturan,
semuanya sudah dilanggar sekali dan ketiganya terlihat seperti perbaikan:

1. Baca key `power`. **Jangan** mengalikan `voltage * current`.
2. **Jangan balik tanda** di call site — dua layar yang menampilkan angka berbeda
   untuk besaran yang sama lebih buruk daripada minus yang aneh.
3. **Nol bukan arah.** Tiga status: charging, standby, discharging.

### 4.4 Allowlist host

`requireAllowedThingsBoardHost` (Kotlin) dan `parseAllowedCctvUrl` (Dart) adalah
dua implementasi dari aturan yang sama dengan lima kasus penolakan yang dipin test.
Ubah satu, ubah yang lain.

---

## 5. Lingkungan — angka yang harus Anda tahu sebelum menjadwalkan sesuatu

Repo ini pernah dibangun di **dua mesin**: CachyOS/Arch lalu Windows 11. Angka
RAM dan core sama-sama 7 GB, jadi keputusan di sini berlaku untuk keduanya.
Yang berbeda adalah shell dan path, jadi **tanyakan atau cek mana yang aktif**
sebelum menulis perintah untuk user.

| Fakta | Nilai | Konsekuensi |
|---|---|---|
| RAM total | 7 249 MB (Linux) · 7,3 GB (Windows) | — |
| RAM tersedia saat diukur | 1 834 MB (Linux) · 0,4 GB (Windows, saat Gradle jalan) | **hanya satu proses build/test boleh jalan** |
| CPU | 8 core (kedua mesin) | — |
| `dart_test.yaml` | `concurrency: 1` | **dengan sengaja**; naikkan hanya setelah cek RAM |
| Shell default | **fish** di Linux, **PowerShell** di Windows | pakai sintaks shell yang sedang aktif |
| `flutter analyze` | ~5 s (Linux) · 15 s (Windows) | jalankan sering, jangan ditunda |
| `flutter test` | ~23 s (Linux) · ~45 s (Windows) | jalankan setiap perubahan |
| `cd android && ./gradlew :app:testDebugUnitTest` | ~7 s (Linux) · 2 m 50 s (Windows, cold) | hanya setelah alarm/rule berubah |
| `flutter build apk --release` | 2–4 menit (Linux) · 386 s (Windows, cold) | **letakkan di latar belakang** |
| `dl.google.com` | 65–114 KB/s **di Linux saja** | **jangan pernah** biarkan AGP/Gradle mengunduh di Linux; pakai `curl -fL`. Detail di `AGENTS.md`. |
| NDK | terunduh ~2,3 GB, **tidak terpakai** | jangan coba "memperbaikinya" |

Angka Windows diukur pada build **cold**, jadi angka warm akan jauh lebih kecil.
Jangan membandingkan angka satu mesin dengan yang lain dan menyimpulkan ada
regresi performa — itu mengukur cache, bukan kode.

### kenapa `concurrency: 1`

Pada RAM 7 GB dengan 1,4–2,4 GB bebas selama test, compiler Dart dan isolate test
saling berebut memori dan salah satunya di-OOM. Gejalanya menipu: "did not
complete" untuk **seluruh file** termasuk test sinkron yang tidak mungkin butuh
memori, atau kegagalan telanjang "loading x.dart" tanpa stack trace, dan file yang
gagal **berpindah-pindah antar run**. Mengganti gejalanya dengan berulang-ulang
menjalankan test adalah cara yang salah. Biarkan satu proses.

Bukti bahwa batasnya nyata: checkout dari mesin Linux membawa tiga log
`Daemon compilation failed` di `android/.kotlin/errors/` — Kotlin daemon kalah
melawan memori, dan pesannya menyebut kompilasi, tidak pernah menyebut memori.

### OOM baru yang terukur di Windows

Terjadi nyata pada 29 September 2026, dan bentuknya persis seperti yang
dideskripsikan di atas — jadi ini bukan kerusakan yang perlu dicari di dalam test:

```
flutter analyze; flutter test
# -> "cctv_test.dart: CctvViewport offline offers retry and back (did not complete)"
#    ... and 10 more
# -> Exited with code 1
```

Dijalankan terpisah, `flutter analyze` tulis "No issues found!" dan
`flutter test` tulis "All tests passed!" 273. Tidak ada kode yang berubah di
antara keduanya.

Penyebabnya bukan `concurrency: 1` yang salah — itu sudah benar. Penyebabnya
**Gradle daemon yang masih hidup** dari `flutter build apk --release` sebelumnya,
masih memegang ~1 GB saat test mulai. Free RAM saat itu 1,4 GB, dan compiler Dart
ikut mengambil bagian. Setelah daemon selesai, run kedua langsung hijau.

Jadi aturan praktisnya:

- **Jangan merangkai `flutter analyze` dan `flutter test` dalam satu perintah**
  tepat setelah build Gradle. Jalankan `./gradlew --stop`
  (`.\gradlew.bat --stop` di Windows) lebih dulu, atau sisipkan jeda.
- Kalau `flutter test` gagal dengan `did not complete` atau `loading x.dart`
  tanpa stack trace, **cek free RAM dan proses yang masih hidup sebelum membaca
  kode test.** Hampir pasti OOM.

Konsekuensi untuk agen: **jangan pernah menjalankan dua `flutter test` bersamaan,
dan jangan minta agen backgroundEQ menjalankan test.** A jalankan di akhir.

### Path yang perlu Anda export

Windows — hampir tidak ada yang perlu, `flutter` dan `adb` sudah ada di `PATH`:

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-21"   # opsional; lihat catatan di bawah
```

`gradlew.bat` berjalan tanpa `JAVA_HOME` karena wrapper memakai `java` di `PATH`.
`ANDROID_HOME`, `ANDROID_SDK_ROOT` dan `JAVA_HOME` tidak di-set di environment,
jadi jangan menulis perintah yang bergantung pada variabel itu ada.

Linux:

```bash
export PATH="$HOME/dev/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export ANDROID_HOME=$HOME/Android/Sdk
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
```

### Perintah yang berbeda per mesin

| Aksi | Linux | Windows |
|---|---|---|
| Gradle | `cd android && ./gradlew …` | `cd android; .\gradlew.bat …` |
| Sanity check file | `grep -qU $'\r' file` | `Select-String -Pattern "`r" -Quiet file` (atau `git` saja) |
| Loop normalisation CRLF | loop bash + `awk` | loop PowerShell, atau `git add --renormalize .` |
| Heredoc | `python3 - <<'PY' … PY` | PowerShell tidak punya heredoc yang sama; pakai `@'…'@` atau file sementara |

**Aturan umum:** jangan pernah menempelkan perintah bash ke user Windows. Kalau
perlu sesuatu yang hanya ada di bash, katakan perintahnya Linux dan sebut bahwa
tidak jalan di sini — lebih baik daripada memberi perintah yang pasti gagal.

---

## 6. Aturan keras

Kalau Anda hanya mengingat satu bagian, ini bagiannya.

1. **Verifikasi klaim "dead code" dengan grep sebelum menghapus apa pun.** Sebuah
   agen review pernah yakin `dashboard_screen._history` adalah kebocoran memori.
   Salah. `TelemetryChartCard` membacanya. **Laporan yang yakin dan berargumen
   baik tetap sebuah laporan.**
2. **Jangan menyederhanakan alarm native kembali menjadi isolate Dart.** Itu
   keputusan terukur: isolate Dart menahan puluhan MB tetap reside; jalur native
   handful MB dan ~0,45 detik.
3. **Jangan pernah menyentuh Release APK dalam proses build.** Build incremential
   bisa menghasilkan APK setengah jadi yang terlihat valid.
4. **Jangan menjalankan operasi jaringan destruktif** terhadap server ThingsBoard,
   perangkat, atau akun. Audit memakai static analysis, test, dan reproduksi
   lokal.
5. **Jangan cetak kredensial.** `android/key.properties` dan
   `android/upload-keystore.jks` **harus tetap git-ignored**, dan isinya tidak
   pernah dicetak meski untuk "memverifikasi" — periksa **kunci yang ada**, bukan
   nilainya.
6. **Satu `[Unreleased]` saja di `CHANGELOG.md`.** Entri yang bertentangan dengan
   kondisi akhir diperbaiki, bukan ditumpuk. Merge yang bersih juga diperbaiki.
7. **Verifikasi klaim yang sudah tertulis di komentar.** Komentar "in Indonesian"
   setelah Anda menerjemahkan UI jadi fakta salah yang sekarang mengarahkan orang
   salah.
8. **Jangan menambahkan dependensi untuk masalah yang bisa diselesaikan dengan
   kode yang sudah ada.** Provider, geocoding, dan csv sudah pernah dihapus
   karena tidak pernah di-import.
9. **Jangan menempelkan perintah bash ke user Windows.** Shell aktifnya
   PowerShell, dan `grep`, `awk`, heredoc, dan `sleep` tidak ada di sana.
   Perintah yang benar-benar lintas-platform harus ditulis ulang per shell; jika
   tidak sempat, katakan bahwa itu perintah Linux.

---

## 7. Jebakan yang sudah memakan waktu

Diurutkan menurut biaya yang pernah menyita waktu.

### 7.1 Konten file bisa berubah di balik layar

Terjadi nyata pada `date_helpers.dart` dan `weather_card.dart`: penulisan
text-mode menyisipkan CRLF, dan beberapa kata berganti bentuk saat dibaca ulang.
Kata Indonesia berubah menjadi CJK atau Hangul di beberapa dokumen — termasuk di
PRD dan `progress.md` milik sesi ini.

Gejalanya sangat mudah disalahpahami: file *terlihat* benar.

Baru terjadi lagi saat dokumen ini ditulis di Windows: beberapa kata Indonesia
mengubah bentuknya menjadi CJK di draf yang masih halfway jadi, dan tidak
terdeteksi sampai pemeriksaan karakter dijalankan. Jadi ini bukan hanya teoritis
untuk mesin ini.

```bash
# 1. CRLF
for f in $(git status --porcelain | awk '{print $NF}'); do
  [ -f "$f" ] && grep -qU $'\r' "$f" 2>/dev/null && echo "CRLF: $f"
done

# 2. karakter asing di dokumen Indonesia
python3 -c "
import re
for f in ('PRD_PLTS_Monitoring_App.md','progress.md','CHANGELOG.md','AGENTS.md'):
    s=open(f,encoding='utf-8').read()
    bad=[c for c in set(s) if 0x4e00<=ord(c)<=0x9fff or 0xac00<=ord(c)<=0xd7af]
    if bad: print(f,'CORRUPT',bad)
"
```

Setara di Windows, tanpa `python3`:

```powershell
foreach ($f in (git status --porcelain | ForEach-Object { $_.Substring(3) })) {
  if (Test-Path $f -PathType Leaf) {
    $b = [IO.File]::ReadAllBytes($f)
    if ($b -contains 13) { "CRLF: $f" }
  }
}
foreach ($f in @('AGENTS.md','AGENT_PLAYBOOK.md','FEATURE.md','progress.md',
                 'CHANGELOG.md','README.md','PRD_PLTS_Monitoring_App.md')) {
  $bad = [IO.File]::ReadAllText($f).ToCharArray() |
    Where-Object { ($_ -ge [char]0x4e00 -and $_ -le [char]0x9fff) -or
                   ($_ -ge [char]0xac00 -and $_ -le [char]0xd7af) -or
                   ($_ -ge [char]0x3040 -and $_ -le [char]0x30ff) } |
    Select-Object -Unique
  if ($bad) { "$f CORRUPT: $($bad -join '')" } else { "$f OK" }
}
```

Jalankan dua pemeriksaan itu setelah setiap perubahan dokumen yang besar, di
mesin mana pun. `AGENT_PLAYBOOK.md` sendiri ikut diperiksa, karena ia yang
mendeskripsikan perangkapnya.

### 7.2 Backtick di dalam `python3 -c "..."` dihapus oleh bash

```bash
# SALAH — `FEATURE.md` dieksekusi sebagai perintah, isinya hilang
python3 -c "s = 'lihat di `FEATURE.md` untuk detail'"

# BENAR — heredoc dengan kutip protects apa pun
python3 - <<'PY'
s = 'lihat di `FEATURE.md` untuk detail'
PY
```

Sudah terjadi: sebuah filename utuh **hilang dari dokumen** tanpa error, dan
terlihat seperti penulisannya gagal.

### 7.3 Edit berbasis nomor baris rapuh

Ketika konten bergeser, edit `lines[247] = ...` menulis ke tempat yang salah dan
tidak menghasilkan error — hanya teks yang salah tempat. Pakai pencocokan konten
(`assert old in s` sebelum `replace`), bukan indeks, untuk dokumen.

### 7.4 Panggilan `write` yang panjang bisa terpotong di tengah

Satu panggilan penulisan ~1 000 baris gagal separuh jalan dan menghasilkan
konten yang tercampur dengan teks lain. **Tulis dokumen dalam beberapa bagian:**
`write` untuk bagian pertama, `cat >> file <<'EOF'` untuk bagian-bagian
berikutnya, lalu periksa hasilnya.

### 7.5 Bug UI senyap — tidak ada exception, analyze bersih, test lulus

Tiga kasus di satu sesi, semuanya hanya terlihat di perangkat atau lewat
pengukuran:

| Gejala | Penyebab |
|---|---|
| Chart dengan sumbu, legenda, dan statistik benar tapi **tanpa garis** | `dashArray: []` — fl_chart menelusuri `pattern[index % pattern.length]`, jadi list kosong berarti "gambar nol". Yang solid adalah **tidak mengisi field itu**. |
| Bar yang "ada di kodenya" tapi **tidak menggambar** | `SizedBox(height: 5)` membuat `maxWidth` jadi infinity, jadi `Row` di bawahnya unbounded dan `Expanded` resolve ke nol. Perlu `width: double.infinity` eksplisit. |
| Banner yang hilang dalam **satu frame** | `AnimatedSwitcher` menumpuk child keluar di bawah child masuk, dan `Stack` mengambil **child terbesar**. Butuh `SizeTransition`, bukan hanya fade. |

Cara menemukan yang ketiga: crop screenshot lalu ukur brightness tiap baris
piksel. Bar yang seharusnya terlihat tetapi max-nya sama dengan background berarti
**tidak menggambar** — bukan "sukar dilihat".

### 7.6 Klaim aksesibilitas yang diukur terhadap permukaan yang salah

`Colors.white54` / `Colors.black45` jelas gagal AA. Tapi pasangan pengganti
juga gagal, dan baru ketahuan saat diukur terhadap glass card fill yang sebenarnya
dipakai: amber **4,02:1** dan abu-abu **4,29:1**, keduanya di bawah 4,5:1 yang
dibutuhkan teks 9–11 dp. Sekarang `test/color_helpers_test.dart` mengukur
terhadap nilai nyata dari `main.dart` dan `liquid_glass.dart`.

### 7.7 Urutan tanda minus yang "diperbaiki" justru merusak

Normalisasi `-(V × I)` supaya card bisa menampilkan positif, padahal halaman
Battery menampilkan nilai mentah. Dua layar jadi mengukur besaran yang sama dengan
angka berbeda, dan pembaca harus bisa renaissance bahwa minus jadi plus.

### 7.8 Label yang sama muncul di tempat yang tidak perlu

`PV Output` ada tiga kali dalam satu kartu: sebagai header, sebagai caption di
bawah angka besarnya, dan sebagai label capsule. Dua yang pertama dihapus.
 conquered

### 7.9 Teks yang terlalu panjang di kolom sempit

`↓ 6.98 ↑ 21.43 V` meluber dari lebar 1/3 kartu dan jadi `109....` — persis
angka yang paling tidak boleh hilang. Satu angka per baris.


### 7.10 `screencap` mengembalikan layar hitam saat ada jendela `FLAG_SECURE`

Terjadi nyata pada 29 September 2026, dan Mahal karena saya membaca resulting
layar hitam sebagai "aplikasi hang" lalu dilaporkan sebagai temuan.

Aplikasi EnerGrow lewat layar kunci biometrik saat cold start. Prompt sidik jarinya
bukan window aplikasi: MIUI menampilkannya sebagai **dua `com.miui.securitycenter
/.FloatingWindow`**. Jendela itu `FLAG_SECURE`, dan selama ada jendela secure di
layar, `adb shell screencap` mengembalikan **hitam penuh untuk seluruh display** —
bukan hanya area window-nya. Yang tetap terlihat cuma satu cincin brightness
180 di y≈2438, yaitu indikator sidik jari, dan itu membuat file PNG-nya kecil
(31 KB) dan *byte-identical* antar dua screenshot yang diambil 3 detik terpisah.

Tiga kesalahan yang lahir dari sana, semuanya karena mempercayai yang dilihat:

1. "Layar hitam" → dilaporkan sebagai bug aplikasi. Bukan.
2. "Spinner" → dilaporkan sebagai `CircularProgressIndicator` yang macet. Justru
   cincin penuh, abu-abu, ketebalan seragam — bukan busur berputar.
3. "Aplikasi tidak merespons" → saya memindai `BLASTBufferQueue` yang melaporkan
   120 fps, jadi jelas *sedang* merender.

Cara mengenali dalam satu detik, sebelum menebak apa pun:

```powershell
# 1. jendela secure milik siapa
adb shell dumpsys window windows | Select-String "FloatingWindow|Biometric|Fingerprint"
# 2. tutup prompt-nya, lalu lihat apakah layarnya kembali
adb shell input keyevent KEYCODE_BACK
# 3. dua screenshot 3 detik apart, bandingkan ukuran file
adb shell screencap -p /sdcard/a.png; Start-Sleep 3; adb shell screencap -p /sdcard/b.png
adb pull /sdcard/a.png; adb pull /sdcard/b.png
```

Kalau ukuran file lompat dari ~31 KB ke ~1,1 MB setelah prompt ditutup, itu
bukan bug — itu `screencap` yang sebelumnya diblokir. **Ukuran file PNG adalah
sinyal yang lebih cepat dan lebih jujur daripada menatap gambarnya.**

Konsekuensi praktis: **aplikasi yang butuh biometrik tidak bisa diuji visual
sambil prompt-nya terbuka.** Selama itu terbuka, satu-satunya yang bisa dibuktikan
adalah `logcat`, `dumpsys`, dan `pm`.

### 7.11 `shouldAcceptUserOffset` tidak meng-gate drag sentuh

Ditemukan 29 September 2026, saat memperbaiki bug "infinite page" di pager
dashboard. Komentar lama di `chart_gesture_lock.dart` mengklaim flag-nya
*"consulted when a drag begins, not when the widget is built"*. Itu **salah**
untuk Flutter 3.47.5, dan membaca sumbernya memakan lima menit yang tidak
dibuang-buang:

`shouldAcceptUserOffset` hanya dibaca di tiga tempat, dan tidak satu pun di
tengah-tengah drag sentuh:

| Tempat | Kapan |
|---|---|
| `ScrollPositionWithSingleContext.applyNewDimensions` | saat layout — hasilnya di-cache jadi `canDrag` |
| `ScrollableState._receivedPointerSignal` | hanya `PointerScrollEvent` (scroll wheel) |
| `scrollable_helpers.dart`, `scrollbar.dart` | aksi scroll & scrollbar |

Artinya `canDrag` **latch**: `setCanDrag(false)` melepas
`_gestureRecognizers`, dan tidak ada yang memasangnya lagi tanpa
`setCanDrag(true)`, yang hanya dipanggil dari `applyNewDimensions`.

Dua konsekuensi yang harus diingat:

- **`allowUserScrolling` bukan gate per-gestur.** Ia dibaca saat `Scrollable`
  memutuskan boleh drag — saat build. Mengikutinya membuat kunci lengket.
  Hook yang benar adalah `shouldAcceptUserOffset`, dan meski pun begitu ia hanya
  berefek lewat relayout yang kebetulan terjadi saat jari ditekan (`fl_chart`
  repaint saat pointer bergerak, jadi jalurnya memang ada).
- **Physics yang meng-*gate* harus meneruskan semua method, bukan cuma yang
 _accept_ gesture.** `createBallisticSimulation` yang tidak diteruskan membuat
  fling jatuh ke friksi biasa dan pager kehilangan snap — itu bug "infinite
  page", dan test dengan **satu** swipe tetap lulus. Uji butuh delapan swipe.

Dan aturan yang berlaku untuk semua di atas: **verifikasi klaim dengan mengukur,
bukan dengan melihat.** Saya salah membaca layar hitam dua kali dan salah
melaporkan tiga bug yang bukan bug sebelum berhenti dan mengukurnya.

---

## 8. Gate verifikasi

**Tidak ada commit tanpa ketiganya.** Urutan ini karena `flutter analyze` paling
murah dan menangkap paling banyak kesalahan sebelum test jalan.

```bash
# Linux
export PATH="$HOME/dev/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export ANDROID_HOME=$HOME/Android/Sdk

flutter analyze          # wajib "No issues found!"   ~5 s
flutter test             # wajib "All tests passed!"   ~23 s
cd android && ./gradlew :app:testDebugUnitTest --console=plain   # 11 test, ~7 s
```

```powershell
# Windows — flutter dan adb sudah di PATH, tidak ada yang perlu di-set
flutter analyze          # wajib "No issues found!"   ~15 s
flutter test             # wajib "All tests passed!"   ~45 s
cd android; .\gradlew.bat :app:testDebugUnitTest --console=plain   # 11 test, 2 m 50 s cold
```

Angka di komentar adalah **cold** di Windows dan **warm** di Linux. Bandingkan
hanya terhadap gate ("No issues found", "All tests passed", BUILD SUCCESSFUL),
jangan terhadap durasi.

Aturan tambahan:

- `flutter test` **hanya boleh satu proses.** Kalau muncul
  `did not complete` atau `loading x.dart` tanpa stack trace, itu OOM — bukan
  test yang gagal. Jangan mencari penyebab di dalam test.
- Gradle hanya wajib kalau alarm, rule, atau `AlarmMessageFormat.kt` berubah.
- Kalau Anda menambahkan test, hitung ulang angka yang Anda sebut di dokumen dan
  di commit message. Angka basi lebih merusak daripada tidak menyebutnya.
- APK release: `flutter build apk --release`, 2–4 menit di Linux, ~6 menit cold
  di Windows. **Latar belakang.**
- Kalau release build di Windows gagal sebelum tahap Dart/Kotlin, periksa
  `android/local.properties` duluan — isinya masih path mesin Linux. Detail di
  `AGENTS.md` §Environment.

### Verifikasi di perangkat — dan apa yang harus Anda akui belum terbukti

Tidak semua bisa dibuktikan dengan test. Untuk yang tidak bisa, lakukan ini dan
**katakan apa yang tidak Anda lihat** di output.

```bash
# Linux
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
D=192.168.18.44:<port>          # port berubah-ubah setiap layar mati, lihat catatan di bawah
adb -s $D install -r build/app/outputs/flutter-apk/app-release.apk
adb -s $D shell am start -n tech.mbkm.energrow/.MainActivity
sleep 22
adb -s $D shell screencap -p /sdcard/s.png
adb -s $D pull /sdcard/s.png /tmp/opencode/s.png
```

```powershell
# Windows — adb sudah di PATH
$D = "192.168.18.44:<port>"
adb -s $D install -r build/app/outputs/flutter-apk/app-release.apk
adb -s $D shell am start -n tech.mbkm.energrow/.MainActivity
Start-Sleep -Seconds 22
adb -s $D shell screencap -p /sdcard/s.png
adb -s $D pull /sdcard/s.png "$env:TEMP\opencode\s.png"
```

`grep -A4` pada output `dumpsys` dan `aapt2` tidak ada di PowerShell. Gunakan
`Select-String -Pattern "CHECK_ALARMS" -Context 0,4`, dan untuk cek release APK
lebih andal daripada memanggil `aapt2` dengan path yang panjang:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\36.0.0\aapt2.exe" `
  dump xmltree build\app\outputs\flutter-apk\app-release.apk --file AndroidManifest.xml |
  Select-String -Pattern "Alarm\w*Receiver"
```

Hasil yang benar hanya `AlarmCheckReceiver` dan `AlarmBootReceiver`.
`AlarmDebugReceiver` **tidak boleh muncul** — kalau muncul, release APK
membocorkan komponen debug.

Yang hanya bisa dibuktikan di perangkat:

| Klaim | Cara |
|---|---|
| Modul alarm berjalan | `adb -s $D logcat -s EnerGrowAlarmCheck:* EnerGrowAlarmSchedule:*` |
| Tidak ada notifikasi berulang | baris `check finished: N active (0 new)` |
| Dua trigger terpasang | `adb -s $D shell dumpsys alarm \| grep -A4 CHECK_ALARMS` |
| Release APK bersih | `aapt2 dump xmltree app-release.apk --file AndroidManifest.xml \| grep AlarmDebugReceiver` → harus kosong |
| Elemen benar-benar menggambar | crop screenshot, ukur brightness tiap baris piksel |

### Jebakan perangkat wireless

- **Layar harus menyala.** Android menghentikan listener wireless debugging saat
  layar mati, dan port-nya berputar. `Connection refused` hampir selalu berarti
  layar mati, bukan masalah jaringan.
- **mDNS sering kosong pada percobaan pertama.** Ulangi 3–4 kali dengan jeda; entri yang ditemukan biasanya muncul di percobaan
  ke-1 atau ke-2.
- **Satu perangkat muncul dua kali.** adb 37 mendaftarkan perangkat yang
  ditemukan via mDNS sebagai entri tambahan. Putuskan yang non-mDNS supaya
  `-d` tidak ambigu.
- **Never `adb shell am broadcast` untuk menguji alarm.** `AlarmCheckReceiver`
  memang `exported="false"`, jadi shell ditolak — itu benar. Untuk build debug
  ada `AlarmDebugReceiver` yang hanya ada di `src/debug/AndroidManifest.xml`
  **dan** menolak kecuali app debuggable. Perintah dan argumennya ada di
  `AGENTS.md`.
- `adb uninstall` **menghapus sesi ThingsBoard**. Pengguna harus login lagi.

---

## 9. Commit dan push

Format commit di repo ini: `tipe: ringkasan imperative`, lalu paragraf yang
menjelaskan **kenapa**, bukan apa. Body commit adalah tempat alasan penolakan
disimpan, karena itu yang tidak hilang saat diff-nya hilang.

```
<type>: <summary in the imperative>

<Why the change was made, and what was tried and rejected first.
 Name the specific failure mode it prevents.>

<What was verified, and on what.>
```

Jenis yang dipakai repo ini: `feat`, `fix`, `refactor`, `docs`, `chore`, `revert`.

Sebelum commit:

```bash
git status --short
# normalisasi line ending dulu — repo ini pernah develop di Windows
for f in $(git status --porcelain | awk '{print $NF}'); do
  [ -f "$f" ] && grep -qU $'\r' "$f" 2>/dev/null && \
    python3 -c "p='$f'; d=open(p,'rb').read(); open(p,'wb').write(d.replace(b'\r\n',b'\n'))"
done
git add -A
git diff --cached --name-only | grep -iE "key.properties|\.jks|\.apk" && echo "JANGAN COMMIT" || echo "aman"
```

```powershell
git status --short
# normalisasi line ending — di NTFS ini bukan masalah teoretis,
# tapi git add --renormalize adalah satu perintah dan menutup semua kasus
git add --renormalize -A
git add -A
$leak = git diff --cached --name-only | Select-String -Pattern "key.properties|\.jks|\.apk"
if ($leak) { "JANGAN COMMIT: $leak" } else { "aman" }
```

`.gitattributes` sudah fijar `* text=auto eol=lf` dan `core.autocrlf` sudah
`input` di repo ini, jadi `--renormalize` biasanya tidak menemukan apa-apa.
Jalankan tetap — biayanya satu perintah, dan yang dicegah adalah 126 file
tampak berubah tanpa satu pun perubahan nyata.

Pengecekan terakhir itu **wajib**: `android/key.properties` dan
`android/upload-keystore.jks` harus tetap tidak pernah masuk.

Setelah commit, `git push origin main`. Working tree harus bersih.

---

## 10. Cara menjawab ke user

Bahasa: **Indonesia**, kecuali user menulis dalam bahasa lain. Komentar kode,
string UI, dan commit message dalam **Inggris** — itu konvensi repo dan sudah
ditegakkan di `AGENTS.md`.

Yang dilakukan:

- Laporkan **apa yang berubah dan apa yang terbukti**. Pisahkan dengan jelas.
- Sebutkan secara eksplisit **apa yang belum terverifikasi**. Kalau Anda tidak
  melihat sesuatu di perangkat, katakan begitu.
- Kalau Anda menolak permintaan, sebutkan alasannya dalam satu kalimat, lalu
  kerjakan bagian yang bisa dikerjakan.
- Kalau permintaan Anda tidak jelas dan salah paham akan membuang banyak
  kerja, ajukan satu pertanyaan alih-alih menebak.

Yang tidak dilakukan:

- Menyatakan "sudah beres" atau "lulus" tanpa menyebutkan apa yang dijalankan.
- Menyembunyikan kegagalan di tengah jalan. Secara konvensi, kegagalan lebih
  berharga daripada keberhasilan karena bisa diulang.
- Menolak perubahan hanya karena preferensi. Security dan kebenaran data
  boleh dibantah; taste dan layout tidak.

---

## 11. Kalau hanya mengingat lima baris

1. Baca `AGENTS.md`, `FEATURE.md`, `progress.md`, `CHANGELOG.md`, PRD — **sebelum
   menulis kode**.
2. Jangan pernah percaya klaim "dead code" tanpa grep.
3. Alarm punya **dua implementasi dan satu fixture** — ubah ketiganya atau
   tidak ubah sama sekali.
4. `flutter analyze` → `flutter test` → Gradle. Satu proses test saja.
   Di Windows perintah Gradle-nya `.\gradlew.bat`, dan `android/local.properties`
   harus sudah menunjuk ke mesin yang sedang dipakai.
5. Yang tidak bisa Anda buktikan, katakan tidak bisa Anda buktikan.
