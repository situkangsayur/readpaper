# Tumpukan teknologi, arsitektur, pola, dan fitur

Dokumen ini menjawab "dibuat dari apa, disusun bagaimana, dan bisa apa".
Untuk **kenapa** sebuah keputusan diambil, lihat
[keputusan-teknis.md](keputusan-teknis.md) dan [architecture.md](architecture.md);
untuk apa yang belum ada, [backlog.md](backlog.md).

Angka saat ditulis (2026-09-30): 102 berkas Dart, sekitar 28.000 baris,
43 berkas uji, 439 tes.

---

## 1. Tumpukan teknologi

### ReadPaper tidak memakai Rust

Ini perlu ditulis lebih dulu karena mudah salah sangka: **ReadPaper seluruhnya
Dart.** Tidak ada crate Rust, tidak ada `Cargo.toml`, tidak ada kode C atau
C++ yang ditulis di repositori ini. Penguraian Zotero, anotasi, buku catatan,
Markdown, Mermaid, penyuntingan halaman PDF, mesin sitasi — semuanya Dart.

Yang **native** di dalamnya bukan tulisan sendiri, melainkan pustaka yang
dibawa paket:

| Pustaka | Bahasa | Dari mana | Untuk apa |
|---|---|---|---|
| Mesin Flutter (`libflutter_linux_gtk.so`, `flutter_windows.dll`) | C++ | Flutter | menggambar dan menjalankan Dart |
| `libpdfium.so` / `pdfium.dll` | C++ | dibawa paket `pdfrx` | membaca, merender, dan menyunting PDF |
| plugin kecil (`printing`, `url_launcher`) | C++/Kotlin tipis | paketnya masing-masing | menjembatani ke API sistem |

Rust ada di **WritePaperTeX**, bukan di sini. Di sana crate `wptex_engine`
membungkus **Tectonic** (Rust, yang sendiri membungkus XeTeX dalam C/C++) dan
**libgit2**, lalu dipanggil dari Dart lewat `dart:ffi`. Alasannya khusus dan
tidak berlaku untuk ReadPaper: Android tidak punya TeX Live, jadi mesin TeX
harus ikut di dalam aplikasinya, dan Tectonic adalah satu-satunya mesin TeX
yang bisa dibawa seperti itu.

Jadi pembagiannya:

| | Antarmuka | Inti | Native yang dibawa |
|---|---|---|---|
| **ReadPaper** | Flutter/Dart | **Dart** | pdfium (C++) |
| **WritePaperTeX** | Flutter/Dart | **Rust** (Tectonic, libgit2) | XeTeX (C/C++) lewat Tectonic |

### Bahasa dan kerangka

- **Dart 3.12** / **Flutter 3.44.5**, kanal stable.
- Material 3, tema terang dan gelap.
- Bahasa antarmuka: Indonesia. Dwibahasa masih di backlog (Fase 8).

### Paket yang dipakai, dan untuk apa

| Paket | Perannya | Catatan |
|---|---|---|
| `flutter_riverpod` 3.4 | keadaan aplikasi | `Notifier` dan `Provider`; `AsyncValue.value`, bukan `valueOrNull` |
| `pdfrx` 2.4 | menampilkan PDF | membawa pdfium; `PdfViewerParams` mengatur tata letak, gulir, dan lapisan di atas halaman |
| `pdfium_dart` + `ffi` | menyunting halaman PDF | menyisipkan halaman kosong; pdfium yang sama yang sudah dimuat penampilnya |
| `pdf` 3.13 | menulis PDF baru | ekspor Markdown dan buku catatan; teksnya tetap bisa dicari dan disalin |
| `printing` | cetak dan "simpan sebagai PDF" | lewat dialog sistem |
| `http` + `crypto` | sinkronisasi Android | GitHub REST API; Android tidak punya `git` |
| `xml` 7.0 | membaca gaya dan locale CSL | keduanya XML |
| `image` | menulis JPG | `dart:ui` hanya bisa PNG |
| `path_provider`, `path`, `file_picker`, `share_plus`, `url_launcher` | berkas dan sistem | |
| `wakelock_plus` | layar tetap menyala saat membaca | |
| `uuid`, `collection`, `intl`, `meta` | utilitas | |

Satu penyematan yang perlu diingat: **`path_provider_android` dipin ke
2.2.23** lewat `dependency_overrides`. Versi 2.3.0 mulai memakai paket `jni`,
dan `jni` adalah plugin FFI yang dibangun untuk *setiap* platform — termasuk
Linux, tempat ia tidak pernah dipanggil tetapi tetap menuntut `libjvm.so` saat
menaut. Akibatnya membangun untuk Linux menuntut JDK terpasang, dan paketnya
seolah menuntut Java di mesin pemakainya.

### Platform dan cara membangunnya

| Platform | Status | Dibangun dengan |
|---|---|---|
| **Android** arm64 | jalan, dipakai sehari-hari | `flutter build apk --release` |
| **Linux** x86-64 | jalan, tiga bentuk paket | `scripts/build-linux-in-debian12.sh` — di dalam kontainer Debian 12, supaya jangkauannya lebar |
| **Windows** x64 | dibangun di CI | `.github/workflows/windows.yml`, runner `windows-latest` — MSVC tidak bisa dijalankan dari Linux |
| **macOS** | belum | butuh mesin macOS; jalurnya CI, dikerjakan setelah penyambung sitasi |

Paket Linux **dipasang lalu dijalankan** di kontainer Debian 12, Ubuntu 22.04,
Ubuntu 24.04, dan Arch sebelum dirilis (`scripts/test-linux-packages.sh`).
Itu bukan kemewahan: cara ini menangkap dua bug yang tidak terlihat di mesin
pengembangan — simbol glib yang belum ada di Debian 12, dan `libEGL.so.1`
yang dibuka lewat `dlopen` sehingga tidak pernah muncul di `ldd`.

---

## 2. Arsitektur

### Bentuk folder: per fitur, bukan per lapisan

```
lib/src/
  app/         tema, rute, titik masuk
  core/        utilitas tanpa ketergantungan fitur (tinta, geometri, format)
  shared/      provider yang dipakai lintas fitur
  features/
    library/     koleksi, item, pencarian, duplikat, statistik
    reader/      penampil PDF, penanda, pena, mode menyajikan
    notes/       catatan lepas di folder tersendiri
    notebook/    buku catatan tulisan tangan berlembar
    whiteboard/  papan tulis
    markdown/    baca, sunting, Mermaid, konversi dua arah
    citation/    CSL-JSON, locale, gaya   (Fase 9, sedang dikerjakan)
    files/       penjelajah folder kerja
    sync/        git dan GitHub API
    settings/    profil repositori
    workspace/   yang menyatukan semuanya
```

Tiap fitur berisi hingga tiga lapisan, dan **tidak semua fitur punya
ketiganya**:

```
domain/         entitas dan aturan murni — tanpa Flutter, tanpa dart:io
data/           membaca dan menulis: berkas, jaringan, pdfium
presentation/   layar, widget, controller Riverpod
```

Aturan arahnya satu: `presentation` boleh memanggil `data` dan `domain`;
`data` boleh memanggil `domain`; **`domain` tidak memanggil siapa pun**.
Itulah yang membuat 439 tes bisa berjalan tanpa emulator.

### Alur data

```
repositori git (format ekspor Zotero)
        │  parse sinkron, sekali per pemuatan
        ▼
   LibraryIndex  ── item, koleksi, pohon, indeks per koleksi
        │
        │  Riverpod Provider (dihitung ulang hanya saat indeksnya berganti)
        ▼
 visibleItemsProvider · duplicateGroupsProvider · libraryStatsProvider
        │
        ▼
      layar
```

Anotasi berjalan berlawanan arah: dari layar pembaca ke `ZoteroWriter`, yang
menulis balik ke berkas item dalam format Zotero **byte-for-byte**, lalu
menjadi commit di repositori yang sama.

---

## 3. Pola yang dipakai berulang

Yang di bawah ini muncul di banyak tempat, dan sebaiknya diikuti kode baru.

### Domain murni, dan itu yang diuji

Logika yang bisa salah ditaruh di `domain/` sebagai fungsi atau kelas tanpa
Flutter: pencari duplikat, statistik, geometri anotasi, pengurai Mermaid,
pemetaan CSL-JSON. Ujinya lalu memanggilnya langsung — cepat, tanpa widget,
tanpa perangkat. Layar tinggal menampilkan hasilnya.

### Hitung sekali, di provider

Pekerjaan yang mahal tidak boleh ada di dalam `build()`. Pencarian duplikat
memakan 65 milidetik pada 1.741 item; kalau dipanggil dari bilah cari, ia
dibayar ulang setiap ketikan. Jadi ia duduk di `Provider` yang bergantung pada
indeks library, dan Riverpod menyimpan hasilnya sampai indeksnya benar-benar
berganti.

### Diturunkan, bukan ditimbun

Daftar yang bisa dihitung ulang **selalu** dihitung ulang dari sumbernya,
tidak pernah disimpan di samping lalu dijaga tetap sejalan. Daftar seperti itu
tidak akan pernah tetap sejalan. Ini yang akan mencegah kelas bug yang
menjengkelkan di Zotero — sitasi dihapus tetapi entrinya masih tertinggal di
daftar pustaka — ketika penyambung dokumen dibuat (lihat Fase 10 di backlog).

### Menolak dengan menyebut sebabnya

Keadaan yang tidak bisa dilayani tidak dijawab dengan kekosongan. Gaya CSL
dependen melempar `CslStyleIsDependent` yang menyebut induknya; menyimpan
catatan tanpa akar Catatan menolak sambil menjelaskan; menyalin spasi
mengatakan bahwa yang terpilih memang spasi. Kekosongan yang diam tidak bisa
dibedakan dari kerusakan.

### Peristiwa pointer mentah untuk stylus

Menggambar tidak memakai `GestureDetector`. `Listener` dipakai langsung karena
tekanan stylus hanya ada di peristiwa mentah, dan karena pengenal gerakan
merebut seretan yang seharusnya milik pena. Satu goresan **terikat pada satu
pointer**: telapak tangan yang bertumpu mengirim pointer sendiri, dan tanpa
ikatan itu setiap telapak yang terangkat memutus goresan yang sedang ditarik.

### IO sinkron di penyunting

Penyunting Markdown dan buku catatan membaca dan menulis secara sinkron.
Bukan karena lebih cepat, melainkan karena IO asinkron membuat
`pumpAndSettle` menggantung di uji widget, dan berkas yang dibaca berukuran
kilobita.

### Format Zotero tidak pernah ditebak

`ZoteroJson` mengekalkan bentuk keluaran plugin sinkronisasi: kunci terurut,
indentasi tab. Ada uji yang mengurai dan menulis ulang **setiap** berkas item
di sebuah klona sungguhan dan menuntut hasilnya identik bita per bita. Satu
berkas yang berubah bentuknya berarti diff palsu di git orang.

### Uji sebagai penjelasan

Nama tes ditulis sebagai kalimat yang menyebut *maksudnya*, bukan nama metode:
"telapak tangan tidak memutus goresan stylus", "gaya dependen ditolak dengan
menyebut induknya". Kalau sebuah tes gagal, namanya sudah memberi tahu apa
yang rusak.

---

## 4. Fitur yang sudah ada

### Library

- Membaca library Zotero yang disinkronkan ke git; pohon koleksi bertingkat,
  koleksi tanpa induk, dan item yang belum masuk koleksi mana pun.
- **Pencarian beroperator**: `pengarang:`, `judul:`, `tahun:`, `tag:`,
  `jenis:`, `jurnal:`, `doi:`, `abstrak:`, `koleksi:` — diterima dalam dua
  bahasa, frasa dikutip, `-` mengecualikan.
- **Panel pengarang** berisi seluruh nama beserta jumlah karyanya.
- **Terakhir dibaca** dan lanjut di halaman terakhir.
- **Kemungkinan duplikat**: DOI, lalu ISBN, lalu judul + tahun + pengarang.
  Tidak menghapus apa pun.
- **Statistik library**: per tahun, per jenis, pengarang dan tag tersering,
  dan berapa persen item yang berkasnya benar-benar ada.

### Membaca dan menandai

- Penampil PDF dengan pilihan teks, daftar isi bawaan berkas, lompat ke
  halaman, bilah gulir bernomor.
- **Stabilo berwarna**, garis bawah, coretan, dan komentar — ditulis balik
  sebagai anotasi Zotero.
- **Pena**: menggambar bebas dengan ketebalan dan warna; lebar goresan
  mengikuti tekanan stylus.
- **Stylus saja**: tangan yang bertumpu tidak meninggalkan garis, sementara
  jari tetap menggeser dan mencubit halaman.
- **Mode baca** (semua bilah hilang), **warna halaman** normal/sepia/redup/
  balik, dan **mode menyajikan** satu halaman penuh layar.
- Sisipkan halaman kosong, isi formulir, tanda tangani, simpan sebagai PDF
  atau PNG/JPG, cetak, bagikan.

### Catatan dan tulisan tangan

- **Buku catatan** berlembar: A5–A1, tegak atau mendatar, komponen yang bisa
  digeser, diputar, dan diubah ukurannya, bangun ruang dan panah yang
  menyambung antar objek, kotak pilih untuk menghapus beberapa sekaligus.
- **Papan tulis** yang berdiri sendiri, bisa disimpan sebagai catatan.
- **PDF jadi buku catatan** dan sebaliknya.
- **Markdown** dengan Mermaid yang digambar sendiri — tanpa WebView, supaya
  catatan tetap terbuka tanpa jaringan — dan konversi dua arah ke PDF.
- Catatan lepas disimpan di folder `catatan/` tersendiri, **di luar** struktur
  Zotero.

### Sinkronisasi

- Clone, fetch, pull, commit, push lewat **SSH** atau **HTTPS** di desktop.
- Di Android lewat **GitHub REST API**, karena Android tidak punya `git`.
- **Klona ramping**: metadata dulu, PDF menyusul saat papernya dibuka.

### Sedang dikerjakan

- **Sitasi** (Fase 9–10): pemetaan CSL-JSON, pembaca locale, dan pembaca gaya
  sudah ada; perendernya dan penyambung ke OnlyOffice, LibreOffice, Word, dan
  Google Docs belum.

---

## 5. Cara menjalankan pemeriksaan

```sh
dart format --line-length 100 --set-exit-if-changed .
flutter analyze
flutter test

# Terhadap klona Zotero sungguhan — tidak ikut di CI karena butuh library orang
READPAPER_TEST_REPO=~/path/ke/klona flutter test test/_real_repo_check.dart

# Paket Linux, dipasang dan dijalankan di empat distribusi
scripts/test-linux-packages.sh

# Daftar gaya CSL tetap utuh (juga diuji dari flutter test)
scripts/csl-style.py check
```
