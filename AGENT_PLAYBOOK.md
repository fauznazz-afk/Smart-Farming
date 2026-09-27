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
| 2 | `FEATURE.md` | Apa yang **sudah ada**. §18 mencantumkan celah yang diketahui — 9 celah fungsional, 20+ simbol mati, 7 perilaku counterintuitive, 5 celah test, 6 hal yang belum pernah dilihat di perangkat. |
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
| File Dart di `lib/` | 67 |
| Baris Dart | ~14 300 |
| File Kotlin | 15 (13 di modul alarm) |
| File test | 14, melaporkan **227 test** |
| File terbesar | `lib/screens/dashboard_screen.dart` — 1 541 baris |

Lima file yang paling sering jadi sumber bug, karena isinya besar dan dipakai
semua halaman:

| File | Kenapa |
|---|---|
| `lib/screens/dashboard_screen.dart` | State, polling, riwayat, evaluasi alarm, dan susunan 5 halaman dalam satu file. 1 541 baris. |
| `lib/utils/alarm_rules.dart` | Satu-satunya definisi apa yang Counts sebagai alarm. Duplikasinya ada di Kotlin. |
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
  `cd android && ./gradlew :app:testDebugUnitTest`. Kalau Anda hanya menjalankan
  yang Dart, Anda belum memverifikasi apa pun.

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

| Fakta | Nilai | Konsekuensi |
|---|---|---|
| RAM total | 7 249 MB | — |
| RAM tersedia saat diukur | 1 834 MB | **hanya satu proses build/test boleh jalan** |
| CPU | 8 core | — |
| `dart_test.yaml` | `concurrency: 1` | **dengan sengaja**; naikkan hanya setelah cek RAM |
| Shell default | **fish**, bukan bash | tulis sintaks fish di pesan ke user; skrip shell tetap bash |
| `flutter analyze` | ~5 s | jalankan sering, jangan ditunda |
| `flutter test` | ~23 s | jalankan setiap perubahan |
| `cd android && ./gradlew :app:testDebugUnitTest` | ~7 s | hanya setelah alarm/rule berubah |
| `flutter build apk --release` | 2–4 menit | **letakkan di latar belakang** |
| `dl.google.com` | 65–114 KB/s | **jangan pernah** biarkan AGP/Gradle mengunduh; pakai `curl -fL` (7–44 MB/s). Detail di `AGENTS.md`. |
| NDK | terunduh ~2,3 GB, **tidak terpakai** | jangan coba "memperbaikinya" |

### kenapa `concurrency: 1`

Pada RAM 7 GB dengan 1,4–2,4 GB bebas selama test, compiler Dart dan isolate test
saling berebut memori dan salah satunya di-OOM. Gejalanya menipu: "did not
complete" untuk **seluruh file** termasuk test sinkron yang tidak mungkin butuh
memori, atau kegagalan telanjang "loading x.dart" tanpa stack trace, dan file yang
gagal **berpindah-pindah antar run**. Mengganti gejalanya dengan berulang-ulang
menjalankan test adalah cara yang salah. Biarkan satu proses.

Konsekuensi untuk agen: **jangan pernah menjalankan dua `flutter test` bersamaan,
dan jangan minta agen backgroundEQ menjalankan test.** A jalankan di akhir.

### Path yang perlu Anda export

```bash
export PATH="$HOME/dev/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export ANDROID_HOME=$HOME/Android/Sdk
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
```

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
   kondisi akhir diperbaiki, bukan ditumpuk._merge yang bersih juga diperbaiki.
7. **Verifikasi klaim yang sudah tertulis di komentar.** Komentar "in Indonesian"
   setelah Anda menerjemahkan UI jadi fakta salah yang sekarang mengarahkan orang
   salah.
8. **Jangan menambahkan dependensi untuk masalah yang bisa diselesaikan dengan
   kode yang sudah ada.** Provider, geocoding, dan csv sudah pernah dihapus
   karena tidak pernah di-import.

---

## 7. Jebakan yang sudah memakan waktu

Diurutkan menurut biaya yang pernahiserserobot.

### 7.1 Konten file bisa berubah di balik layar

Terjadi nyata pada `date_helpers.dart` dan `weather_card.dart`: penulisan
text-mode menyisipkan CRLF, dan beberapa kata berganti bentuk saat dibaca ulang.
Kata Indonesia berubah menjadi CJK atau Hangul di beberapa dokumen — termasuk di
PRD dan `progress.md` milik sesi ini.

Gejalanya sangat mudah disalahpahami: file *terlihat* benar.

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

Jalankan dua perintah itu setelah setiap perubahan dokumen yang besar.

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


---

## 8. Gate verifikasi

**Tidak ada commit tanpa ketiganya.** Urutan ini karena `flutter analyze` paling
murah dan menangkap paling banyak kesalahan sebelum test jalan.

```bash
export PATH="$HOME/dev/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export ANDROID_HOME=$HOME/Android/Sdk

flutter analyze          # wajib "No issues found!"   ~5 s
flutter test             # wajib "All tests passed!"   ~23 s
cd android && ./gradlew :app:testDebugUnitTest --console=plain   # 11 test, ~7 s
```

Aturan tambahan:

- `flutter test` **hanya boleh satu proses.** Kalau muncul
  `did not complete` atau `loading x.dart` tanpa stack trace, itu OOM — bukan
  test yang gagal. Jangan mencari penyebab di dalam test.
- Gradle hanya wajib kalau alarm, rule, atau `AlarmMessageFormat.kt` berubah.
- Kalau Anda menambahkan test, hitung ulang angka yang Anda sebut di dokumen dan
  di commit message. Angka basi lebih merusak daripada tidak menyebutnya.
- APK release: `flutter build apk --release`, 2–4 menit. **Latar belakang.**

### Verifikasi di perangkat — dan apa yang harus Anda akui belum terbukti

Tidak semua bisa dibuktikan dengan test. Untuk yang tidak bisa, lakukan ini dan
**katakan apa yang tidak Anda lihat** di output.

```bash
export PATH="$HOME/Android/Sdk/platform-tools:$PATH"
D=192.168.18.44:<port>          # port berubah-ubah setiap layar mati, lihat catatan di bawah
adb -s $D install -r build/app/outputs/flutter-apk/app-release.apk
adb -s $D shell am start -n tech.mbkm.energrow/.MainActivity
sleep 22
adb -s $D shell screencap -p /sdcard/s.png
adb -s $D pull /sdcard/s.png /tmp/opencode/s.png
```

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
- Kalau permintaan Anda_-nya tidak jelas dan salah paham akan membuang banyak
  kerja, ajukan satu pertanyaan alih-alih menebak.

Yang tidak dilakukan:

- Menyatakan "sudah beres" atau "lulus" tanpa menyebutkan apa yang dijalankan.
- Menyembunyikan kegagalan di tengah jalan. conventionally kegagalan lebih
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
5. Yang tidak bisa Anda buktikan, katakan tidak bisa Anda buktikan.
