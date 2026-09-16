# ReadPaper

Pembaca paper bergaya Zotero untuk library yang disinkronkan ke GitHub oleh
plugin [zotero-github-sync](https://github.com/situkangsayur/zotero-github-plugin).

Buka repositori Zotero di GitHub, telusuri koleksinya seperti di Zotero, baca
PDF-nya, beri **stabilo berwarna** dan **komentar** pada teks tertentu — lalu
setiap perubahan langsung ditulis balik ke berkas Zotero dan di-*commit* ke git.

![ReadPaper](docs/screenshot-library.png)

## Yang bisa dilakukan sekarang

- **Sinkron GitHub** — clone, fetch, pull, commit, push lewat **SSH** (dengan
  pilihan kunci privat) maupun **HTTPS** (personal access token). `git lfs pull`
  untuk lampiran besar. PDF baru yang ditambahkan lewat GitHub muncul setelah pull.
- **Jalan juga di Android** — di sana tidak ada biner `git`, jadi repositori
  di-*mirror* lewat GitHub REST API: metadata library (±19 MB) diunduh penuh,
  PDF-nya (±529 MB) baru diambil saat papernya dibuka. Anotasi dikirim balik
  sebagai commit sungguhan.
- **Ganti repositori kapan saja** — tiap profil punya folder clone sendiri, jadi
  pindah bolak-balik antar repo tidak perlu clone ulang.
- **Struktur koleksi Zotero** — pohon koleksi bertingkat yang bisa
  dibuka/ditutup, jumlah item per koleksi, "Semua item", "Tanpa koleksi", dan
  opsi menyertakan item sub-koleksi.
- **Daftar paper** — judul, pengarang, tahun, jenis item, badge lampiran /
  anotasi / catatan; pencarian cepat dan pengurutan.
- **Pembaca PDF** — seleksi teks, stabilo & garis bawah dalam 8 warna palet
  Zotero, komentar per anotasi, catatan lepas di halaman (tekan lama), panel
  anotasi yang bisa diklik untuk loncat ke posisinya.
- **Kompatibel dua arah dengan Zotero** — anotasi ditulis ke
  `items/<XX>/<KEY>.json` dalam format Zotero API JSON yang sama persis dengan
  yang ditulis plugin (indentasi tab, kunci terurut, `annotationPosition`,
  `annotationSortIndex`), dan blok `## Annotations` di `notes/**.md` ikut
  diperbarui. Menambah satu stabilo = satu baris baru di catatan dan satu blok
  baru di JSON, jadi diff-nya tetap kecil.

Rencana berikutnya ada di [docs/backlog.md](docs/backlog.md): pencarian
pengarang & detail metadata (fase 2), EPUB (fase 3), lalu Android + publikasi
APK (fase 4).

## Menjalankan

Butuh Flutter 3.41+ (diuji di 3.44.5 / Dart 3.12) dan, untuk desktop Linux,
`clang`, `ninja-build`, `libgtk-3-dev`, `git`, dan `git-lfs`:

```bash
sudo apt install clang ninja-build libgtk-3-dev git git-lfs
flutter pub get
flutter run -d linux
```

Untuk Android (butuh token GitHub dengan izin *Contents: read and write*):

```bash
flutter build apk --release --target-platform=android-arm64
```

Saat pertama dijalankan, tambahkan repositori:

| Isian | Contoh |
| --- | --- |
| URL repositori | `git@github.com:situkangsayur/zotero-hendri.git` |
| Transport | SSH (kunci privat opsional) atau HTTPS + token |
| Folder clone | otomatis `~/.local/share/readpaper/repos/<owner>-<repo>` |

Lalu tekan **Clone sekarang**. Setelah selesai, koleksi dan daftar paper
langsung terbaca.

## Cara memberi tanda

1. Buka paper → tombol **Baca** pada lampiran PDF.
2. Seleksi teks di halaman. Bilah aksi muncul di bawah.
3. Pilih warna, lalu **Stabilo**, **Garis bawah**, atau **Komentar**.
4. Klik anotasi di halaman (atau ikon pensil di panel kanan) untuk mengubah
   warna/komentar, atau menghapusnya.

Setiap aksi langsung jadi satu commit. Aktifkan *Push otomatis setelah
menyimpan anotasi* di profil kalau ingin langsung terkirim ke GitHub;
kalau tidak, tekan tombol unggah di bilah atas untuk commit & push manual.

## Struktur kode

Feature-first, tiap fitur dipisah `domain` / `data` / `presentation`:

```
lib/
  main.dart
  src/
    app/                     tema + widget aplikasi
    core/                    konstanta, error, util (path, warna, key Zotero)
    shared/providers/        provider Riverpod untuk repository & backend
    features/
      library/               parser & penulis ekspor Zotero, pohon koleksi, daftar item
      reader/                pembaca PDF, geometri anotasi, panel anotasi
      sync/                  GitBackend + dua implementasi: git CLI (desktop)
                             dan GitHub REST API (Android)
      settings/              profil repositori & kredensial
      workspace/             orkestrasi: repo aktif, status git, library terbaca
```

Detail arsitektur dan format data ada di
[docs/architecture.md](docs/architecture.md).

## Pengujian

```bash
flutter test
```

Ada juga pemeriksaan manual terhadap clone asli (tidak ikut `flutter test`):

```bash
flutter test test/_real_repo_check.dart
```

Pemeriksaan itu memastikan seluruh berkas item bisa dibaca ulang dan ditulis
kembali **byte-for-byte** sama dengan keluaran plugin.

Ada pula pemeriksaan klien GitHub terhadap API sungguhan (repo publik, tanpa
token):

```bash
flutter test test/_real_github_api_check.dart
```
