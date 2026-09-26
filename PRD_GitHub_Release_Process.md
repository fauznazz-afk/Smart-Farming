# PRD & SOP — Proses Rilis GitHub EnerGrow

**Project:** FNN-XAI-IoT — Smart Farming Energy Monitoring
**Cakupan:** Rilis aplikasi Flutter untuk Android melalui GitHub Releases
**Dokumen:** 1.1
**Status:** Prosedur kerja untuk rilis berikutnya
**Rilis acuan:** 1.4.0 (build 10), tag `v1.4.0` — procedures in this document
were all exercised successfully for that release

---

## 1. Tujuan

Dokumen ini menetapkan satu alur rilis yang berulang dan dapat ditinjau. Setiap rilis harus memiliki versi aplikasi yang konsisten, changelog yang lengkap, APK release yang ditandatangani dengan key proyek, serta tag dan halaman GitHub Release yang menunjuk pada commit yang benar.

## 2. Sumber kebenaran dan format versi

- `pubspec.yaml` adalah sumber versi aplikasi. Formatnya `major.minor.patch+build`, misalnya `1.2.3+7`.
- Label versi di Settings dibaca dari metadata APK melalui `package_info_plus`; jangan mengubah nomor versi secara terpisah di layar Settings.
- Gunakan tag Git `v<major>.<minor>.<patch>`, misalnya `v1.2.3`.
- Setiap APK baru harus menaikkan build number. Build number Android (`versionCode`) harus selalu lebih tinggi dari release sebelumnya.
- Naikkan patch untuk perbaikan, minor untuk fitur kompatibel, dan major untuk perubahan yang memutus kompatibilitas.
- `CHANGELOG.md` menyimpan riwayat semua versi, dengan versi terbaru di bagian paling atas.
- `RELEASE_NOTES_vX.Y.Z.md` berisi ringkasan yang akan ditampilkan di halaman GitHub Release. Lampirkan juga `CHANGELOG.md` agar pengguna dapat mengunduh riwayat lengkap.

## 3. Signing dan perlindungan key

Build release memakai signing config di `android/app/build.gradle.kts` dan properti lokal di `android/key.properties`. Keystore saat ini berada di `android/upload-keystore.jks`.

`android/key.properties` perlu memiliki properti berikut. Isi nilainya dari salinan aman yang dikelola tim; jangan menaruh nilai contoh atau password sungguhan di dokumen, chat, source control, atau release asset.

```properties
keyAlias=<alias-keystore>
keyPassword=<password-key>
storeFile=../upload-keystore.jks
storePassword=<password-keystore>
```

Perhatikan bahwa `storeFile` dibaca relatif ke direktori modul Android `android/app`; nilai `../upload-keystore.jks` menunjuk ke `android/upload-keystore.jks`.

Ketentuan keamanan:

- Jangan commit, push, atau unggah `android/key.properties` maupun `android/upload-keystore.jks`. Keduanya sudah dimasukkan ke `.gitignore`.
- Jangan menampilkan isi properties, password, private key, atau file keystore dalam log.
- Simpan backup keystore dan password di tempat aman yang aksesnya dibatasi. Kehilangan key dapat membuat APK tidak bisa memperbarui instalasi pengguna yang sudah ada.
- Jangan membuat keystore pengganti untuk rilis aplikasi yang sama tanpa rencana migrasi signing.
- Fingerprint sertifikat signing APK saat ini yang diharapkan (SHA-256):
  `504d13ee0bbfa8df2a24c20ef3cc59bde4f35b69596a12ceabb709cf702564b5`
- Jika fingerprint hasil build berbeda, hentikan proses publikasi dan periksa konfigurasi signing terlebih dahulu.

## 4. Persiapan rilis

Sebelum build:

1. Pastikan branch rilis adalah `main` dan working tree bersih.
2. Pastikan perubahan yang akan dirilis sudah di-review dan seluruh commit yang dibutuhkan sudah berada di `main`.
3. Perbarui versi di `pubspec.yaml`, misalnya dari `1.2.3+7` menjadi `1.2.4+8`.
4. Tambahkan bagian baru di paling atas `CHANGELOG.md`; pertahankan bagian versi sebelumnya.
5. Buat `RELEASE_NOTES_vX.Y.Z.md` dengan perubahan utama, batasan yang diketahui, cara pemasangan, dan hasil verifikasi.
6. Periksa `android/key.properties` dan `android/upload-keystore.jks` tersedia secara lokal. Jangan mencetak nilainya untuk memeriksa keberadaan.
7. Pastikan tag versi yang akan dipakai belum ada:

```powershell
git tag --list "v1.2.4"
git ls-remote --tags origin "refs/tags/v1.2.4"
```

Jangan memakai ulang tag yang sudah pernah dipublikasikan. Jika ada masalah setelah publikasi, naikkan versi patch dan buat release baru.

## 5. Pemeriksaan dan build APK

Jalankan dari root repository pada PowerShell:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Flutter mengambil `versionName` dan `versionCode` dari `pubspec.yaml`. APK release dihasilkan pada:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Salin ke nama ber-versi untuk mencegah APK tertukar:

```powershell
Copy-Item `
  build/app/outputs/flutter-apk/app-release.apk `
  build/app/outputs/flutter-apk/EnerGrow-v1.2.4.apk
```

Validasi signature dengan `apksigner` dari Android SDK:

```powershell
$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$apksigner = Get-ChildItem (Join-Path $sdkRoot 'build-tools') `
  -Filter apksigner.bat -Recurse |
  Sort-Object FullName |
  Select-Object -Last 1 -ExpandProperty FullName

& $apksigner verify --verbose --print-certs `
  build/app/outputs/flutter-apk/EnerGrow-v1.2.4.apk
```

Pastikan signature valid, v2 scheme bernilai `true`, dan SHA-256 sertifikat sesuai fingerprint di Bagian 3. Periksa juga versi APK (`versionName=1.2.4`, `versionCode=8`) dengan Android SDK `apkanalyzer` atau setelah instalasi melalui Package Manager.

Jika perangkat Android tersedia, uji update dengan key yang sama:

```powershell
adb install -r build/app/outputs/flutter-apk/EnerGrow-v1.2.4.apk
```

Jika Android melaporkan signature berbeda, jangan langsung menghapus instalasi lama. Penghapusan akan menghilangkan token ThingsBoard dan preferensi lokal. Periksa fingerprint terlebih dahulu; minta persetujuan pengguna sebelum menghapus instalasi jika memang diperlukan.

Catat hasil `flutter analyze`, `flutter test`, build, verifikasi signature, dan uji perangkat pada `RELEASE_NOTES_vX.Y.Z.md` atau catatan release.

## 6. Commit dan tag

Commit kode, `pubspec.yaml`, `CHANGELOG.md`, dan release notes. Jangan commit APK hasil build atau material signing.

```powershell
git status --short
git diff --check
git add <file-yang-diubah>
git commit -m "Prepare EnerGrow v1.2.4 release"
git push origin main
git tag -a v1.2.4 -m "EnerGrow 1.2.4 (build 8)"
git push origin v1.2.4
```

Pastikan tag menunjuk ke commit rilis yang sama dengan `main`:

```powershell
git show -s --format="%h %D %s" v1.2.4
git ls-remote origin refs/heads/main refs/tags/v1.2.4
```

## 7. Membuat GitHub Release

Di repository `fauznazz-afk/Smart-Farming`:

1. Buka **Releases** lalu pilih **Draft a new release**.
2. Pilih tag `v1.2.4` yang sudah didorong ke remote; target commit harus commit rilis pada `main`.
3. Isi judul `EnerGrow 1.2.4 (build 8)`.
4. Salin isi `RELEASE_NOTES_v1.2.4.md` ke deskripsi release.
5. Lampirkan aset berikut:
   - `EnerGrow-v1.2.4.apk` — APK release bertanda tangan.
   - `CHANGELOG.md` — riwayat lengkap seluruh versi.
6. Jadikan release terbaru, periksa kembali tag, deskripsi, dan kedua aset, lalu pilih **Publish release**.

Jangan unggah `app-debug.apk`, file `.jks`, `key.properties`, atau APK yang fingerprint-nya belum diperiksa. Jika GitHub CLI tersedia dan sudah terautentikasi, release dapat dibuat dengan cara otomatis, tetapi verifikasi aset dan tag setelah upload tetap wajib.

## 8. Verifikasi setelah publikasi

- Halaman release `vX.Y.Z` terbuka dan tidak berstatus draft.
- Tag menunjuk ke commit yang benar dan release ditandai sebagai release terbaru.
- APK dapat diunduh dari halaman release; ukuran file masuk akal dan checksum/signature sesuai.
- `CHANGELOG.md` terlampir dan bagian versi teratas sama dengan judul release.
- APK di perangkat menampilkan versi dan build number yang diharapkan.
- Working tree bersih dan branch `main` sudah sinkron dengan `origin/main`.

## 9. Checklist rilis

- [ ] Versi `pubspec.yaml`, changelog, release notes, nama APK, tag, dan judul release konsisten.
- [ ] Build number naik dan tag belum pernah digunakan.
- [ ] `flutter analyze`, `flutter test`, dan `flutter build apk --release` berhasil.
- [ ] APK lolos verifikasi signing dan memakai fingerprint key proyek.
- [ ] Tidak ada key, password, atau APK build di commit source.
- [ ] Commit dan annotated tag sudah didorong ke `origin`.
- [ ] GitHub Release memuat APK release dan changelog lengkap.
- [ ] Release sudah dipublikasikan dan tautan download sudah diperiksa.
