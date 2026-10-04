# Panduan teknis

Untuk yang hendak mengubah kode ReadPaper: cara menyiapkan mesin, membangun,
menguji, merilis, dan — yang paling sering dibutuhkan — di mana mencari ketika
sesuatu rusak. Dokumen ini sengaja tidak mengulang yang sudah ditulis di
tempat lain:

| Pertanyaan | Dokumen |
|---|---|
| Dibuat dari apa, paket apa saja, pola apa yang berulang | [tech-stack.md](tech-stack.md) |
| Format data Zotero, koordinat anotasi, clone hemat, paketan Linux | [architecture.md](architecture.md) |
| Keputusan yang sulit diubah (Rust, plugin WASM, Google Docs) | [keputusan-teknis.md](keputusan-teknis.md) |
| Apa yang sudah dan belum, beserta riwayatnya | [backlog.md](backlog.md) |
| Fork, branch, sign-off, pull request | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| Fitur dari sisi pemakai | [fitur.md](fitur.md), [panduan-pengguna.md](panduan-pengguna.md) |

---

## 1. Peta singkat

ReadPaper seluruhnya Dart/Flutter. Yang native hanya pdfium (dibawa `pdfrx`)
dan mesin Flutter sendiri. Kodenya per fitur di `lib/src/features/`, dengan
lapisan `domain` / `data` / `presentation` di dalam tiap fitur; `domain` tidak
memanggil siapa pun. Rinciannya di tech-stack.md bagian 2.

Empat titik yang paling sering disentuh:

| Berkas | Perannya |
|---|---|
| `features/workspace/presentation/controllers/workspace_controller.dart` | satu-satunya tempat operasi remote dan penulisan library dijalankan; UI cukup merender `WorkspaceState` |
| `features/sync/domain/repositories/git_backend.dart` | satu-satunya sambungan antarplatform. Di atasnya, semua kode sama di Android dan desktop |
| `features/library/data/datasources/zotero_writer.dart` + `zotero_json.dart` | semua yang menulis ke format Zotero |
| `features/reader/presentation/screens/reader_screen.dart` | pembaca, penanda, pena, mode baca, mode menyajikan (berkas terbesar, ~3.100 baris) |

`shared/providers/app_providers.dart` memilih backend sinkronisasi:
`GitHubApiBackend` di Android dan iOS (iOS tidak punya biner git, dan aplikasinya
tidak boleh menjalankan proses lain), `GitCliBackend`
di Linux, Windows, dan macOS.

---

## 2. Menyiapkan mesin

### Flutter

Dikembangkan dengan **Flutter 3.44.5 / Dart 3.12**, kanal stable — versi yang
sama dipin di kedua alur kerja CI. `pubspec.yaml` menuntut Dart `^3.10.0`.
Di mesin pengembangan SDK-nya ada di `~/flutter/bin`; tambahkan ke `PATH` atau
panggil dengan jalur lengkap.

```sh
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
flutter doctor
```

### Linux desktop

```sh
sudo apt install clang ninja-build libgtk-3-dev git git-lfs
flutter run -d linux
```

`git` dibutuhkan saat berjalan, bukan hanya saat membangun: backend desktop
memanggil biner `git` sistem.

### Android

- Android SDK dengan NDK. Versinya tidak dipin sendiri:
  `android/app/build.gradle.kts` memakai `flutter.ndkVersion`, jadi NDK yang
  diminta mengikuti versi Flutter (di mesin pengembangan saat ini
  28.2.13676358).
- Java 17 (`compileOptions` dan `jvmTarget` di berkas yang sama).
- Hanya **arm64-v8a**. `abiFilters` sengaja dikosongkan lalu diisi satu ABI:
  tanpa itu, pustaka 32-bit nyasar dari sebuah plugin membuat APK mengaku
  mendukung armeabi-v7a, dan perangkat 32-bit memasangnya lalu crash.
- Rilis masih ditandatangani dengan **kunci debug** (`signingConfigs.debug`).
  Ini tercatat di backlog Fase 4.
- Uji di perangkat sungguhan, bukan emulator. Stylus, telapak tangan, lubang
  kamera, dan bilah navigasi sistem adalah sumber setengah bug pembaca, dan
  emulator tidak punya satu pun.

### Windows

Tidak bisa dibangun dari Linux: `flutter build windows` menuntut Visual Studio
dan MSVC. Jalurnya `.github/workflows/windows.yml` di runner `windows-latest`
(lihat bagian 3). Untuk mencoba di mesin Windows sendiri, pasang Visual Studio
dengan beban kerja C++ dan Git for Windows, lalu `flutter run -d windows`.

### iOS

Tidak bisa dibangun dari Linux maupun Windows: `flutter build ios` menuntut
Xcode, yang hanya ada di macOS. Jalurnya `.github/workflows/ios.yml` di runner
`macos-latest` (lihat bagian 3). Tidak ada Mac di sini, jadi semua yang khas iOS
— `ios/Runner/AppDelegate.swift`, `Info.plist` — baru terbukti saat dibangun di
sana dan dipasang di perangkat.

### Penyematan yang perlu diingat

`path_provider_android` dipin ke **2.2.23** lewat `dependency_overrides`. Versi
2.3.0 menarik paket `jni`, plugin FFI yang dibangun untuk setiap platform dan
menuntut `libjvm.so` saat menaut di Linux. Jangan dilepas tanpa memeriksa
bahwa `pubspec.lock` tetap tanpa `jni`. Alasan lengkapnya di architecture.md.

---

## 3. Membangun

### APK Android

```sh
flutter build apk --release --target-platform=android-arm64
# hasil: build/app/outputs/flutter-apk/app-release.apk
```

### Paket Linux

Bangun **di dalam kontainer Debian 12**, bukan di mesin pengembangan (Ubuntu
24.04): biner dari Ubuntu 24.04 terpasang di Debian 12 lalu mati dengan
`undefined symbol: g_once_init_enter_pointer`.

```sh
scripts/build-linux-in-debian12.sh     # flutter build linux + package-linux.sh di Debian 12
scripts/test-linux-packages.sh         # pasang dan jalankan di Debian 12, Ubuntu 22.04/24.04, Arch
```

Hasilnya di `build/linux/dist/`: `readpaper-<versi>-linux-x64.tar.gz`,
`readpaper_<versi>_amd64.deb`, dan `PKGBUILD`. `scripts/package-linux.sh` bisa
dijalankan sendiri (`--skip-build` kalau bundelnya sudah ada), tetapi hasilnya
hanya sejauh sistem tempat ia dibangun.

`test-linux-packages.sh` menjalankan aplikasinya di bawah Xvfb di tiap
kontainer. Kode keluar 124 (dihentikan `timeout`) berarti masih hidup saat
waktu habis — itu **berhasil**; kode lain berarti ia berhenti sendiri. Jangan
merilis paket Linux yang belum lewat skrip ini: dua bug yang tidak terlihat di
mesin pengembangan (`g_once_init_enter_pointer`, `libEGL.so.1` yang dibuka
lewat `dlopen`) ditemukan olehnya.

Satu jebakan yang dijaga skrip paketan: berkas `.desktop` harus bernama sama
dengan `APPLICATION_ID` di `linux/CMakeLists.txt`
(`com.situkangsayur.readpaper.desktop`). Kalau tidak, dok menampilkan aplikasi
tanpa ikon. Skripnya gagal kalau namanya tidak cocok.

### Windows

`.github/workflows/windows.yml` berjalan pada setiap tag `v*` dan bisa dipicu
tangan (`workflow_dispatch`, dengan masukan `release_tag` opsional). Urutannya:
`flutter analyze`, `flutter test`, `flutter build windows --release`, lalu
seluruh folder `build/windows/x64/runner/Release` dibungkus jadi
`readpaper-<versi>-windows-x64.zip` beserta `LICENSE` dan `PASANG.md`.

Zip-nya dilampirkan ke rilis GitHub dengan `gh release upload --clobber`.
Alur kerjanya butuh `permissions: contents: write`; tanpa itu langkah terakhir
gagal dengan "HTTP 403: Resource not accessible by integration" setelah semua
langkah lain lolos. Rilisnya harus sudah ada sebelum alur kerja itu sampai di
langkah terakhir — kalau belum, picu ulang dengan `release_tag`.

Tes dijalankan di runner Windows juga, bukan hanya buildnya. Itu sudah
membayar dirinya: sembilan tes gagal di sana sementara semuanya hijau di Linux
— jalur dengan `\`, dan jam berkas yang lebih kasar (lihat 5.5).

### iOS (iPhone/iPad)

`.github/workflows/ios.yml` berjalan pada setiap tag `v*` dan bisa dipicu
tangan, sama seperti Windows. Urutannya: `flutter analyze`, `flutter test`,
`flutter build ios --release --no-codesign`, lalu `Runner.app` dimasukkan ke
folder `Payload/` dan dizip menjadi `ReadPaper-<versi>-ios-unsigned.ipa`.
Hasilnya selalu diunggah sebagai artefak alur kerja, dan dilampirkan ke rilis
GitHub hanya kalau rilisnya sudah ada — berbeda dengan Windows, langkah itu
tidak menggagalkan alur kerja; picu ulang dengan `release_tag` setelah rilisnya
dibuat.

Target minimumnya **iOS 14.0**, karena `file_picker` menuntutnya; plugin lain
cukup 12 atau 13. Semua plugin membawa `Package.swift`, jadi Flutter memakai
Swift Package Manager dan tidak ada Podfile. Kalau suatu hari ada plugin yang
hanya punya podspec, Flutter membuat Podfile sendiri saat membangun; baris
`platform :ios, '14.0'` di dalamnya harus diaktifkan.

Berkas yang dibuka dari aplikasi lain ("Buka di…", lembar bagikan, Files)
masuk lewat kanal yang sama dengan Android, `readpaper/berkas-masuk`
(`takeInitialPdf`, `openPdf`). Sisi iOS-nya kelas `BerkasMasuk` di
`AppDelegate.swift`: menyalin berkasnya ke `Caches/masuk` selagi akses
security-scoped terbuka, lalu menyerahkan jalurnya ke Dart. Folder kerja
(`Documents/readpaper`) terlihat di aplikasi Files berkat `UIFileSharingEnabled`
dan `LSSupportsOpeningDocumentsInPlace`; data aplikasi dan token tetap di
`Library/Application Support`, yang tidak terlihat.

**Memasang .ipa yang belum ditandatangani.** iPhone hanya menjalankan aplikasi
yang ditandatangani dengan sertifikat dari akun Apple. Jalur yang tidak butuh
Mac maupun akun berbayar:

1. Buat **Apple ID gratis** (cukup Apple ID biasa; tidak perlu mendaftar
   program pengembang).
2. Di PC **Windows**, pasang **Sideloadly** atau **AltServer** (pasangan
   AltStore). Keduanya butuh iTunes dan iCloud versi unduhan dari situs Apple,
   bukan dari Microsoft Store. Untuk Linux tidak ada versi resmi dari
   keduanya; AltServer-Linux adalah proyek komunitas yang belum dicoba di sini.
3. Sambungkan iPhone/iPad dengan kabel, buka `.ipa` dari rilis di Sideloadly
   (atau lewat AltStore di perangkat), masukkan Apple ID, lalu pasang.
4. Di perangkat: **Pengaturan → Umum → VPN & Manajemen Perangkat**, percayai
   Apple ID tadi. Di iOS 16 ke atas nyalakan juga **Pengaturan → Privasi &
   Keamanan → Mode Pengembang** dan mulai ulang perangkat.

Batasan akun gratis: tanda tangannya **kedaluwarsa setelah 7 hari** — aplikasi
lalu menolak terbuka sampai ditandatangani ulang (data di dalamnya tetap ada
selama aplikasinya tidak dihapus). AltStore bisa memperbaruinya sendiri lewat
Wi-Fi selama AltServer menyala di jaringan yang sama; Sideloadly cukup
memasang ulang `.ipa` yang sama. Satu Apple ID gratis juga hanya boleh punya
**tiga aplikasi** hasil pasang sendiri yang aktif sekaligus — AltStore sendiri
ikut dihitung.

Nanti, dengan **Apple Developer Program berbayar**, tanda tangannya berlaku
setahun dan aplikasinya bisa dibagikan lewat TestFlight. Alur kerjanya perlu
ditambah sertifikat dan profil sebagai rahasia repositori; itu belum ada.

### CI

`.github/workflows/ci.yml` di setiap pull request dan push ke `main`:

```sh
dart format --line-length 100 --set-exit-if-changed .
flutter analyze
flutter test
```

Ketiganya harus lolos di mesin sendiri sebelum membuka pull request.

---

## 4. Menguji

```sh
flutter test                         # semua, sekitar 45 berkas dan ±450 tes
flutter test test/github_api_backend_test.dart
flutter test --name "telapak"        # menurut nama tes
```

Nama tes ditulis sebagai kalimat yang menyebut maksudnya ("lampiran tidak ikut
disiapkan saat commit", "tidak pernah nol — pena yang hilang terasa rusak").
Pertahankan kebiasaan itu: tes yang gagal sudah memberi tahu apa yang rusak.

### Suite yang paling penting

| Berkas | Yang dijaga |
|---|---|
| `zotero_writer_test.dart` | anotasi ditulis dalam format plugin; `children` terurut menurut kunci; sunting mengganti, bukan menggandakan; komentar multibaris jadi satu baris di catatan |
| `zotero_collection_write_test.dart` | `collections.json` ditulis ulang identik; entri baru di ujung; nama kembar dan garis miring ditolak |
| `zotero_new_item_test.dart` | item baru dari PDF terbaca kembali oleh parser aplikasi sendiri |
| `github_api_backend_test.dart` | mirror, status, commit, push, pull, lampiran sesuai permintaan, penolakan saat GitHub maju, berkas ditolak yang disisihkan, lampiran yang tidak pernah dikirim, batas waktu unggahan, *racily clean* |
| `git_cli_backend_test.dart`, `git_progress_parser_test.dart` | backend desktop dan pengurai `git --progress` |
| `stylus_pressure_test.dart`, `ink_geometry_test.dart` | tekanan jadi tebal, tebal per titik bertahan setelah disimpan, dipotong, atau diputar |
| `annotation_move_test.dart`, `annotation_move_layer_test.dart` | memindah, memperbesar, memutar tinta; pegangan di tepi halaman tetap bisa disentuh |
| `pdf_page_editor_test.dart` | halaman kosong di awal, tengah, akhir; hasilnya bukan gambar sehingga berkas tidak membengkak |
| `note_document_test.dart`, `notebook_screen_test.dart`, `shape_connector_test.dart` | buku catatan: putar empat kali kembali persis, penghubung mengikuti benda, penghapus sebagian membelah goresan, stylus bertekanan |
| `markdown_doc_test.dart`, `mermaid_graph_test.dart`, `markdown_pdf_test.dart`, `pdf_to_markdown*_test.dart` | pengurai Markdown, tata letak Mermaid, dua arah konversi |
| `search_query_test.dart`, `duplicate_finder_test.dart`, `library_stats_test.dart` | operator cari, pencocokan duplikat bertingkat, statistik |
| `csl_*_test.dart` | pembaca CSL-JSON, locale, dan gaya (Fase 9) |

### Dua pemeriksaan di luar `flutter test`

Berkas berawalan garis bawah tidak diambil `flutter test` dan tidak berjalan di
CI, karena butuh library orang atau kuota API:

```sh
# Mengurai klona sungguhan dan menuntut setiap berkas item ditulis ulang
# identik bita per bita. Wajib sebelum menggabungkan apa pun di
# features/library/data/.
READPAPER_TEST_REPO=~/.local/share/readpaper/repos/<pemilik>-<repo> \
  flutter test test/_real_repo_check.dart

# GitHubApiClient terhadap API GitHub sungguhan (repo publik, tanpa token).
flutter test test/_real_github_api_check.dart
```

### Yang belum diuji otomatis

Pembaca tidak punya uji widget untuk penangkapan stylus dan penolak telapak
tangan; logika itu duduk di `reader_screen.dart` dan dibuktikan di tablet.
Perubahan di bagian itu harus diuji di perangkat dengan stylus sungguhan —
tulis di halaman yang sudah digulir jauh, dengan telapak bertumpu, di mode
biasa dan mode menyajikan.

---

## 5. Sinkronisasi dari dalam

### 5.1 Dua backend, satu antarmuka

`GitBackend` mendefinisikan clone, status, fetch, pull, commitAll, push,
fetchAttachment, lfsPull, dan checkConnection. `WorkspaceController` hanya
mengenal antarmuka itu.

| | `GitCliBackend` (desktop) | `GitHubApiBackend` (Android) |
|---|---|---|
| Salinan lokal | clone git sungguhan, partial + sparse | *mirror* berkas metadata |
| Pembukuan | `.git/` | `.readpaper/sync-state.json` |
| Transport | SSH (`GIT_SSH_COMMAND`, `BatchMode=yes`) atau HTTPS (`GIT_ASKPASS` berumur pendek) | HTTPS + token |
| commit | `git add -- .` lalu `git commit` | catat jalur ke antrean `pending`, belum menyentuh GitHub |
| push | `git push` | blob → tree → commit → `PATCH` ref |
| Lampiran | `git sparse-checkout add`, atau `git lfs pull --include` | `GET /git/blobs/{sha}` saat **Unduh** ditekan; **tidak pernah dikirim** |

Kedua backend sama-sama **meng-commit seluruh isi salinan**, bukan hanya
berkas yang ditulis ReadPaper (`commitAll` tanpa `paths`). Di desktop itu
`git add -- .`; di Android itu setiap berkas di luar folder lampiran yang
berbeda dari catatan sinkronisasi. Berkas asing yang ditaruh orang di folder
repositori ikut terkirim.

### 5.2 Mirror dan `GitHubSyncState`

`.readpaper/sync-state.json` di akar folder profil memegang peran `.git`:

| Bidang | Isi |
|---|---|
| `branch`, `commitSha` | dari commit mana mirror berasal; push dibangun di atasnya |
| `files` | tiap berkas metadata: id blob git, ukuran, mtime saat ditulis |
| `attachments` | id blob lampiran di GitHub, untuk diunduh nanti |
| `pending` | antrean `PendingChange` (pesan, daftar jalur, waktu) |
| `rejected` | berkas yang ditolak GitHub: id blob isinya dan alasan dari GitHub |
| `behind`, `lastCommitSubject`, `lastCommitDate` | untuk tampilan status |

Deteksi perubahan tanpa git: ukuran + mtime dulu, lalu `gitBlobSha()`
(`sha1("blob <len>\0" + isi)`) hanya kalau keduanya berubah. Hasilnya bisa
dibandingkan langsung dengan pohon GitHub.

Unduhan metadata berjalan delapan paralel, memeriksa setiap blob terhadap id
yang dijanjikan GitHub (blob terpotong ditolak), dan menyimpan pembukuan setiap
50 berkas — unduhan yang terputus dilanjutkan, bukan diulang. Pohon yang
`truncated` ditolak dengan pesan; itu batas API untuk repositori yang sangat
besar.

### 5.3 Push dan berkas yang ditolak

`push` di Android:

1. Kalau `headSha` remote ≠ `state.commitSha`: tolak, minta tarik dulu. Tidak
   pernah memaksa.
2. Saring jalur lampiran sekali lagi (jaring pengaman untuk antrean lama).
3. Per berkas: kalau sudah tidak ada dan pernah ada di commit induk, masukkan
   entri hapus; kalau tidak pernah ada di GitHub, lewati (meminta GitHub
   menghapus jalur yang tidak ada membuat **seluruh** pohon ditolak). Kalau id
   blob lokal sama dengan yang di GitHub, lewati. Kalau sama dengan yang pernah
   ditolak, jangan unggah ulang.
4. `createBlob`; kegagalan 413 (pemeriksaan ukuran sendiri, >100 MB) atau 422
   menjadi `RejectedFile`, bukan kegagalan seluruh push.
5. Tree, commit, update ref. Berkas yang terkirim diperbarui di `files`; yang
   ditolak tetap di `pending` dan `rejected` dengan alasannya.

Pesan 422 diambil dari badan jawaban GitHub (`errors[].message`, lalu
`message`). Dulu 422 ditebak sebagai "branch bergerak", dan tebakan itu
membuat orang menarik perubahan berulang kali tanpa pernah bisa berhasil —
jangan kembalikan tebakan semacam itu.

Batas waktu: permintaan kecil 30 detik; unggahan diberi 30 detik + satu menit
per megabita (setelah base64), paling lama 45 menit. Permintaan diulang sampai
tiga kali untuk timeout, soket putus, 5xx, 408, 429, dan batas kecepatan
sekunder (403 dengan `Retry-After` ditunggu, bukan dibaca sebagai token yang
kurang izin).

### 5.4 Aturan lampiran

**Lampiran tidak pernah dikirim lewat API.** `isAttachmentPath()` mengenali
jalur yang memuat segmen `attachments` atau `attachments-lfs`, dan jalur itu
disaring di `commitAll` dan sekali lagi di `push`. Sebabnya bukan kerapian:

- berkas di `attachments-lfs/` disimpan di repositori sebagai **penunjuk** LFS
  ±100 bita; mengirim PDF-nya ke jalur itu menimpa penunjuk dan merusak LFS
  repositori;
- berkas di `attachments/` sering puluhan megabita, dan API menolak di atas
  100 MB;
- satu lampiran di antrean dulu terbawa selamanya dan menggagalkan setiap
  pengiriman berikutnya.

Akibat yang harus diingat saat menambah fitur: item yang dibuat di Android
(`createItemFromPdf`) terkirim tanpa PDF-nya. Catatan di `catatan/berkas/`
bukan jalur lampiran, jadi ikut terkirim.

Di desktop, clone hemat memakai sparse checkout yang mengecualikan
`/**/attachments/**` dan `/**/attachments-lfs/**`. Membuka paper menjalankan
`git sparse-checkout add` untuk foldernya. Berkas *baru* di folder lampiran —
PDF dari "Tambahkan ke koleksi" — berada di luar pola sparse, dan git menolak
menambahkannya tanpa `--sparse`. Karena itu `GitCliBackend.commitAll` memakai
`git add --sparse` setiap kali `core.sparseCheckout` menyala (sejak 0.23.7;
butuh git 2.34 ke atas). Ujinya ada di `git_cli_backend_test.dart`.

### 5.5 Jalur dan jam

- Jalur relatif repositori selalu diseragamkan ke `/` (`_repoRelative`).
  `p.relative` memakai `\` di Windows, dan tanpa penyeragaman setiap berkas
  tampak berubah.
- *Racily clean*: berkas yang mtime-nya tidak lebih tua dari mtime
  `sync-state.json` sendiri selalu dibaca ulang isinya
  (`GitHubApiBackend.isRacilyClean`). Pembandingnya mtime berkas catatan, bukan
  jam dinding — keduanya harus dari jam yang sama.

### 5.6 Kesetiaan JSON Zotero

Semua yang ditulis ke `zotero/` harus identik bita per bita dengan tulisan
plugin: indentasi tab, kunci terurut, diakhiri `}\n`, `children` terurut
menurut `key`, angka utuh tanpa `.0`, `annotationPosition` sebagai string JSON
padat. `ZoteroJson.encodeFile` adalah satu-satunya penyandi. Rincian dan
alasannya di architecture.md bagian "Format data yang dibaca".

Satu-satunya berkas **struktur** yang ditulisi adalah `collections.json`
(membuat koleksi): entri lama tidak pernah diubah atau diurutkan ulang, entri
baru di ujung, berkas yang isinya bukan daftar koleksi ditolak.

---

## 6. Jalur penulisan anotasi

Dari layar ke commit:

1. `ReaderScreen` membangun `ZoteroAnnotation`: kunci baru (`ZoteroKey`),
   `parentItemKey` = kunci lampiran, `pageIndex`, `rects` (stabilo/garis bawah)
   atau `paths` + `inkWidth` (tinta), dan `sortIndex` dari
   `ZoteroAnnotation.buildSortIndex`.
2. `_persist` memanggil `WorkspaceController.saveAnnotation`. Untuk PDF lepas
   (`isStandalone`, `itemFilePath` kosong) anotasi hanya ditahan di memori dan
   ditandai belum disimpan.
3. `ZoteroWriter.upsertAnnotation` membaca berkas item, mengganti atau
   menambah anak dengan kunci yang sama, lalu `_persist` menulis ulang berkas
   item (lewat `ZoteroJson`), memperbarui `meta.attachments[].annotationCount`,
   dan menulis ulang blok `## Annotations` di `notes/**.md` milik item itu.
4. Kalau tidak ada berkas yang berubah, itu galat ("berkas item tidak
   berubah"), bukan keberhasilan diam.
5. `_commitAnnotation` meng-commit dengan `annotationCommitMessage` —
   `Tambah ink p.3 — Judul paper` — dan push kalau `autoPushOnSave` menyala.

Koordinat: Zotero memakai poin PDF dengan asal kiri-bawah, sama dengan
`PdfRect` pdfrx, jadi hanya sumbu Y yang dibalik saat menggambar.

Tinta dikumpulkan di `_pendingInk` dan disimpan sebagai **satu** anotasi
`ink` saat pena dimatikan (**Selesai**), saat berpindah halaman, atau saat
warna/tebal diganti — Zotero menyimpan satu warna dan satu tebal per anotasi
tinta. Memindah, mengubah ukuran, dan memutar tinta menulis ulang titiknya
sekali dari anotasi asli saat jari diangkat, karena sudut yang disimpan
terpisah tidak akan terbaca Zotero.

---

## 7. Pena dan stylus di pembaca

Bagian ini yang paling sering rusak, dan semua aturannya lahir dari bug yang
terbukti di tablet.

**`Listener` membungkus penampil, bukan lapisan di depannya.** Apa pun yang
menerima pointer di depan `PdfViewer` — `GestureDetector` maupun `Listener`,
sekalipun dibatasi ke stylus — membuat jari tidak pernah sampai ke penampil,
dan dokumen beku selama pena aktif. Jadi di mode "Stylus saja" lapisan tinta
per halaman memakai `IgnorePointer` dan hanya melukis, sementara goresan
ditangkap `Listener` di `_buildViewer` yang hanya menyimak.

**Satu goresan, satu pointer** (`_stylusPointer`). Telapak tangan mengirim
pointer sendiri yang turun-naik berkali-kali; dulu setiap telapak yang
terangkat mengakhiri goresan yang sedang ditarik.

**Kotak halaman dihitung saat stylus turun** (`_pageRectNow`), dari
`_controller.layout.pageLayouts` dan `documentToLocal`. `_pageRects` yang
dicatat saat lapisan halaman dibangun **basi** untuk halaman yang sudah keluar
layar; memakainya membuat "separuh halaman tidak bisa ditulisi" setelah lama
menggulir. Jangan kembali mengandalkan kotak yang dicatat saat build.

**Kunci telapak** (`_palmPointers`, `_handLocked`). Di mode "Stylus saja" jari
tetap menggeser halaman, kecuali sentuhan yang datang saat stylus sedang dekat
(hover), sedang menulis, atau baru diangkat (`_stylusGrace`, 800 ms), atau yang
`radiusMajor`-nya di atas 16 titik logis. Selama ada satu, `panEnabled` dan
cubit dimatikan.

**Cat ulang tanpa membangun ulang layar.** Titik goresan yang sedang ditarik
masuk ke `_stylusLive` dan memicu `_stylusTick` (`ValueNotifier`); hanya kanvas
tinta yang dicat ulang. `setState` seratus kali sedetik terasa tersendat.

Titik yang lebih rapat dari 1,5 piksel dibuang — tidak menambah bentuk, hanya
menambah besar berkas di repositori orang.

Pena di pembaca **tidak** memakai tekanan: anotasi `ink` Zotero menyimpan satu
`inkWidth` untuk seluruh gambar, dan tebal per titik tidak akan terbaca Zotero.
Tekanan dipakai di papan tulis dan buku catatan (`whiteboard_screen.dart`,
`notebook_screen.dart`), dibaca dari peristiwa mentah dan dinormalkan dengan
`pressureMin`/`pressureMax`, hanya untuk stylus — banyak layar melaporkan
tekanan tetap untuk jari. Kurva penghalus dan `InkSmoothing.widthFor` ada di
`core/utils/ink_smoothing.dart` dan dipakai layar, PNG, dan PDF bersama.

Mode menyajikan: bagian atas layar dipakai lubang kamera dan bilah status yang
disembunyikan mode imersif tetapi tetap mengambil sentuhan, jadi semua kendali
ada di bilah bawah, diletakkan dengan `MediaQuery.viewPaddingOf`, bukan
`SafeArea` (yang memberi nol di mode imersif).

---

## 8. Merilis

Urutannya, setiap kali sebuah perubahan selesai dan terbukti:

1. **Naikkan versi** di `pubspec.yaml` (`version: X.Y.Z+N`; `N` = versionCode
   Android, selalu naik).
2. **Commit dan push** ke `main`.
3. **Tag beranotasi**: `git tag -a vX.Y.Z -m "..."` lalu `git push origin
   vX.Y.Z`. Tag ini juga memicu alur kerja Windows dan iOS.
4. **Bangun APK** (bagian 3), dan paket Linux lewat kontainer kalau rilis itu
   menyertakannya — lalu uji paketnya dengan `test-linux-packages.sh`.
5. **Rilis GitHub** dengan APK terlampir:

   ```sh
   gh release create vX.Y.Z \
     build/app/outputs/flutter-apk/app-release.apk#"ReadPaper X.Y.Z (arm64 APK)" \
     --repo situkangsayur/readpaper --title "ReadPaper X.Y.Z" --notes "..."
   ```

   Nama berkas di rilis mengikuti `readpaper-<versi>-arm64.apk`. Tambahkan
   paket Linux dari `build/linux/dist/` ke rilis yang sama. Zip Windows
   dilampirkan sendiri oleh alur kerjanya. `.ipa` iOS juga, kalau rilisnya
   sudah ada saat alur kerja itu selesai; kalau belum, picu ulang `ios.yml`
   dengan `release_tag`.
   `scripts/publish-releases.sh` menyusulkan rilis untuk tag yang belum punya,
   aman diulang.
6. **Perbarui halaman unduh internal** dengan APK yang sama. Halaman itu
   dikelola di luar repositori ini; caranya tidak dicatat di sini.

Kredensial untuk `gh`: `gh auth login --scopes public_repo`, atau `GH_TOKEN`
berisi fine-grained token yang dibatasi ke repositori ini dengan *Contents:
read and write*. Jangan memakai scope `repo` penuh atau `project`.

---

## 9. Konvensi

**Pesan commit dalam bahasa Indonesia, menjelaskan sebab.** Baris pertama apa
yang berubah, dalam kalimat biasa, di bawah ±70 karakter. Badannya: apa yang
salah, bagaimana ketahuan, apa yang diputuskan dan apa yang ditolak. Lihat
`git log` — misalnya "Buku 57 MB yang tidak pernah bisa dikirim, dan pesan yang
menyuruh hal yang sia-sia". Kode sudah mengatakan *apa*; pesan commit adalah
satu-satunya tempat *kenapa* bertahan. Kontribusi dari luar memakai
`git commit -s` (DCO, lihat CONTRIBUTING.md).

**Komentar menjelaskan kenapa, bukan apa.** Komentar yang baik di kode ini
menyebut bug yang mendasarinya dan apa yang terjadi kalau aturannya dilanggar:

```dart
// Telapak tangan yang terangkat bukan pena yang diangkat.
if (event.pointer != _stylusPointer) return;
```

Komentar baru boleh Indonesia atau Inggris; kode lama mencampur keduanya.

**Menolak dengan menyebut sebabnya.** Keadaan yang tidak bisa dilayani dijawab
dengan pesan yang bisa ditindaklanjuti, bukan kekosongan atau tombol mati
tanpa keterangan. Pesan galat ditulis untuk pemakai, dalam bahasa Indonesia.

**Domain murni, diuji langsung.** Logika yang bisa salah masuk `domain/` tanpa
Flutter dan tanpa `dart:io`, lalu diuji tanpa widget.

**Hitungan mahal di provider**, tidak di `build()`.

**Format Zotero tidak pernah ditebak.** Ubah apa pun di `features/library/data/`
→ jalankan `_real_repo_check.dart` terhadap klona sungguhan.

**Format:** `dart format --line-length 100`.

---

## 10. Ketika sesuatu rusak

| Gejala | Lihat dulu |
|---|---|
| Diff raksasa di repositori setelah satu anotasi | `ZoteroJson.encodeFile`, `ZoteroWriter._persist`; jalankan `_real_repo_check.dart` |
| Zotero gagal mengimpor setelah ReadPaper menulis | berkas asing di `zotero/` (ingat `git add -- .`), `collections.json`, `ZoteroWriter.createItemFromPdf` |
| Anotasi muncul lalu hilang saat dimuat ulang | `WorkspaceController.saveAnnotation` (pesannya di `state.error`), `ZoteroWriter.upsertAnnotation` |
| Push Android gagal berulang di tempat yang sama | `.readpaper/sync-state.json` → `pending` dan `rejected`; `GitHubApiBackend.push`; tab **Log git** |
| "GitHub sudah punya commit lebih baru" padahal sudah ditarik | `state.commitSha` vs `headSha`; pull yang gagal di tengah tidak memajukan `commitSha` |
| Status menampilkan perubahan pada mirror yang bersih | `_repoRelative` (pemisah jalur), `isRacilyClean`, mtime |
| Commit desktop gagal setelah memasukkan PDF | sparse checkout dan `git add -- .` (5.4) |
| Unduhan metadata macet atau kuota habis | `GitHubApiClient` (`_send`, `_message`, `rateLimitRemaining`); mirror pertama ±3.500 permintaan |
| Stylus tidak menulis di sebagian halaman | `_pageRectNow`, `_stylusDown` |
| Goresan terputus atau halaman bergeser saat menulis | `_stylusPointer`, `_palmPointers`, `_handLocked`, `panEnabled` |
| Dokumen tidak bisa digeser saat pena aktif | sesuatu menerima pointer di depan penampil; lapisan tinta harus `IgnorePointer` di mode stylus |
| Tombol terlihat tetapi tidak bisa ditekan | lubang kamera/bilah status/bilah navigasi; `viewPaddingOf`; anak di luar batas induknya tidak menerima sentuhan |
| Paket Linux mati di distribusi lain | dibangun di luar Debian 12? `scripts/test-linux-packages.sh`; `ldd` dan pustaka `dlopen` |
| Aplikasi tanpa ikon di dok Linux | nama berkas `.desktop` vs `APPLICATION_ID` |
| Tes merah hanya di Windows | jalur dengan `\`, jam berkas kasar |
| Build Linux menuntut JDK | `jni` kembali masuk `pubspec.lock`; penyematan `path_provider_android` |

Untuk perilaku yang dilaporkan pemakai, minta **nomor versi** dari bagian bawah
layar Repositori lebih dulu. Lebih dari sekali, "fiturnya tidak ada" ternyata
APK lama.
