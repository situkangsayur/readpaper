# Arsitektur ReadPaper

## Lapisan

Struktur *feature-first* dengan pemisahan `domain` / `data` / `presentation`
per fitur. Aturannya satu arah:

```
presentation  →  domain  ←  data
   (widget)      (entity,     (parser, penulis,
                  kontrak)     git CLI, berkas setelan)
```

- `domain/entities` — objek murni tanpa Flutter (`ZoteroItem`, `ZoteroAnnotation`,
  `GitRepoStatus`, `RepoProfile`, …).
- `domain/repositories` — kontrak abstrak (`LibraryRepository`, `GitBackend`,
  `SettingsRepository`).
- `data/datasources` — implementasi nyata: pembaca/penulis berkas Zotero,
  pemanggil `git`, berkas setelan.
- `data/repositories` — perekat antara kontrak dan datasource.
- `presentation/controllers` — `Notifier` Riverpod.
- `presentation/screens|widgets` — UI.

### Fitur

| Fitur | Isi |
| --- | --- |
| `library` | Membaca dan menulis ekspor Zotero; pohon koleksi; daftar item |
| `reader` | Pembaca PDF, geometri anotasi, panel & editor anotasi |
| `sync` | Entity git dan `GitBackend`; implementasi CLI |
| `settings` | Profil repositori, kredensial, preferensi |
| `workspace` | Orkestrasi lintas fitur: repo aktif, status git, library aktif |
| `notes` | Koleksi catatan di direktori tersendiri, di luar struktur Zotero |
| `files` | Penjelajah berkas perangkat; berkas diseret dari sini ke pohon |
| `whiteboard` | Papan tulis berlembar-lembar → PDF, bisa disimpan sebagai catatan |
| `markdown` | Baca/sunting Markdown, diagram Mermaid, Markdown ↔ PDF |
| `notebook` | Buku catatan stylus: komponen yang bisa disunting, `.catatan.json` |

`WorkspaceController` adalah satu-satunya tempat operasi remote dijalankan,
sehingga UI cukup merender satu `WorkspaceState`.

## Format data yang dibaca

Repositori hasil plugin `zotero-github-sync`:

```
zotero/
  README.md
  .zotero-sync/
    manifest.json          daftar library (nama, direktori, jumlah item)
    files.json             daftar berkas yang ditulis
  my-library/
    library.json           id, nama, jumlah item
    collections.json       [{key, name, parentKey, path, relations}]
    searches.json          saved searches
    settings.json          warna tag
    index.md               daftar isi per koleksi
    items/<XX>/<KEY>.json  satu berkas per item tingkat atas
    notes/<A>/<judul> (<KEY>).md
    attachments/<XX>/<KEY>/<berkas>
    attachments-lfs/<XX>/<KEY>/<berkas>   (Git LFS)
```

Satu berkas item:

```jsonc
{
  "children": [ /* attachment, note, dan annotation — datar, urut menurut key */ ],
  "meta":     { /* ringkasan: judul, pengarang, tahun, lampiran + path berkas */ },
  "zotero":   { /* Zotero API JSON item itu sendiri */ }
}
```

Hal penting yang ditemukan dari repo asli dan dipertahankan oleh penulis
(`ZoteroWriter`), semuanya diuji di `test/zotero_writer_test.dart`:

1. **Indentasi tab, kunci terurut alfabetis, diakhiri `}\n`.**
   `ZoteroJson.encodeFile` menghasilkan keluaran identik dengan plugin —
   diverifikasi byte-for-byte pada seluruh 1.740 berkas item repo asli.
2. **`children` diurutkan menurut `key`,** bukan menurut tipe atau
   `annotationSortIndex`. Mengikuti aturan ini membuat penambahan satu anotasi
   hanya menambah satu blok di diff, bukan menulis ulang seluruh berkas.
3. **Angka utuh ditulis tanpa `.0`** (`[[72,600,500,612]]`), seperti keluaran
   `JSON.stringify` di JavaScript.
4. **`annotationPosition` adalah string JSON padat**, bukan objek.
5. **Blok `## Annotations` di catatan**: kutipan ditulis apa adanya (termasuk
   spasi ganda dari lapisan teks PDF), komentar selalu satu baris — baris-baris
   komentar di-*trim* lalu digabung dengan spasi.
6. **`meta.attachments[].annotationCount`** ikut diperbarui.

## Catatan: direktori tersendiri

Pohon koleksi punya **dua akar**, dan tiap akar punya jenis. Akar paper adalah
ekspor Zotero di atas. Akar catatan adalah folder terpisah di akar repositori
yang sama:

```
catatan/
  koleksi.json                  [{key, name, parentKey}]
  item/<XX>/<KEY>.json          satu berkas per catatan
  berkas/<XX>/<KEY>/<nama>      isinya — PDF papan tulis, markdown, gambar
```

Kenapa tidak ditumpangkan ke `zotero/`, padahal di sana sudah ada `notes/`?
Karena `notes/**.md` di sana adalah **catatan anak sebuah item** — ia melekat
pada paper dan ikut diperiksa Zotero saat impor. Yang dibutuhkan di sini adalah
catatan yang berdiri sendiri: hasil rapat, coretan papan tulis, catatan kuliah.
Untuk menyimpannya sebagai item Zotero, ia harus mengaku punya rujukan dan
bibliografi yang sebenarnya tidak ada, dan seluruh isi `zotero/` ditulis
byte-for-byte oleh plugin `zotero-github-sync` — satu berkas yang tidak sah di
sana berarti impor yang gagal. Jadi catatan mendapat foldernya sendiri, dan
kedua struktur bisa hidup di satu repositori tanpa yang satu merusak yang lain.

Yang tetap ditiru dari sebelah: ember dua huruf, kunci delapan karakter dari
abjad Zotero (`ZoteroKey`), JSON beridentasi tab dengan kunci terurut. Diff git
tetap kecil, dan repositorinya tetap terlihat seperti satu benda.

Dua aturan yang dijaga kode, bukan oleh kebiasaan pemakai:

1. **Menyimpan catatan wajib ke akar catatan.** `NoteTarget.of(selection)`
   adalah satu-satunya tempat aturan ini tinggal; penolakannya menyebutkan
   sebabnya. Dipakai papan tulis dan pelepasan berkas di pohon.
2. **Akar paper hanya menerima PDF,** karena item Zotero adalah paper dengan
   lampiran PDF. Berkas lain ditolak dengan saran melepasnya di akar catatan.

Menghapus koleksi catatan tidak menghapus catatannya — isinya pindah ke "tanpa
koleksi". Menghapus berkas orang karena satu ketukan adalah kejutan yang tidak
pantas.

## Markdown, Mermaid, dan dua arah konversi

Markdown-nya diurai sendiri (`MarkdownDoc.parse`) dan bukan dengan pustaka,
karena satu dokumen harus melayani tiga keluaran: widget di layar, PDF, dan
penyuntingan balik ke sumbernya. Pustaka Markdown yang lengkap menghasilkan
HTML — satu lapisan lagi untuk dibongkar sebelum bisa digambar ke PDF. Tiap
blok menyimpan **nomor baris asalnya**, dan itulah yang membuat ketukan di
pratinjau bisa memindahkan kursor ke sumber blok yang diketuk.

Diagram Mermaid digambar sendiri juga — tanpa WebView, tanpa mermaid.js —
karena catatan harus terbuka di tablet tanpa jaringan, dan sebuah mesin
JavaScript untuk menggambar sepuluh kotak adalah harga yang tidak perlu
dibayar. Yang dikenali hanya `graph`/`flowchart`; jenis lain ditolak dengan
menyebut sebabnya dan menampilkan sumbernya apa adanya, karena diagram yang
salah gambar lebih menyesatkan daripada kode yang terbaca jujur.

`MermaidLayout` dihitung **sekali** dan dipakai dua kali: oleh pelukis di layar
dan oleh penulis PDF. Kalau keduanya menghitung sendiri, diagram di layar dan
di cetakan akan berbeda, dan yang mencetak tidak akan tahu mana yang benar.

Markdown → PDF menulis **teks sungguhan**, bukan tangkapan layar: hasilnya
masih bisa dicari, disalin, dan dibaca pembaca layar — termasuk label di dalam
diagram, yang ditulis sebagai widget teks di atas bentuk yang digambar kanvas.
Satu jebakan yang sudah diperbaiki: font baku PDF tidak punya blok tanda baca
"pintar" (— “ ” … •) dan **menghilangkannya tanpa jejak**, bukan menggambar
kotak kosong. Semua teks karena itu melewati `_safe()` yang menukarnya dengan
padanan ASCII.

PDF → Markdown menebak struktur dari geometri, karena PDF tidak menyimpan
paragraf, tajuk, atau daftar — hanya potongan teks beserta tempatnya. Aturannya
sengaja bisa dijelaskan: tinggi huruf badan teks diambil dari tinggi yang
membawa paling banyak **huruf** (bukan rata-rata, yang digeser satu tajuk
raksasa, dan bukan nilai tengah, yang digeser dokumen bertajuk banyak); baris
yang lebih besar dan pendek jadi tajuk; baris berdekatan disambung; kata
terpotong tanda hubung disatukan; dan kepala/kaki halaman dikenali dari
**ruang kosong di sekitarnya**, bukan dari isinya — tanpa itu, badan teks yang
kebetulan berpola ("Isi halaman 3.") ikut terbuang.

Hasil konversinya ditulis ke folder kerja aplikasi, tidak pernah di sebelah
papernya: paper hidup di dalam ekspor Zotero, dan berkas asing di sana
mengacaukan struktur yang dijaga plugin sinkronisasi.

## Buku catatan: komponen, bukan gambar

Papan tulis menghasilkan gambar; buku catatan menghasilkan **dokumen**. Isinya
komponen — tinta, teks, gambar, diagram — yang masing-masing punya tempat,
ukuran, sudut, warna, dan kepekatan sendiri.

Aturan yang dijaga kode: **sudut, skala, dan kepekatan adalah sifat komponen,
bukan sesuatu yang ditulis balik ke titik-titik tintanya.** Memutar dengan
menulis ulang titik akan kehilangan ketelitian sedikit demi sedikit sampai
tulisannya berubah bentuk; menyimpannya sebagai sifat membuat memutar
bolak-balik kembali persis ke asalnya. Ada uji yang menjaganya.

Lembarnya berukuran A4 dalam **titik PDF** dan diperkecil utuh ke layar. Satu
koordinat karena itu berlaku di mana saja — ponsel, tablet, dan PDF — dan
catatan yang ditulis di layar kecil tidak berpindah tempat saat dibuka di layar
besar.

Urungkan menyimpan **keadaan dokumen**, bukan daftar tindakan
(`NoteHistory`). Daftar tindakan selalu punya satu tindakan yang lupa
didaftarkan, dan satu saja sudah cukup untuk membuat urungkan bohong. Satu
gerakan tangan mencatat satu langkah, bukan satu langkah per piksel.

Penghapusnya dua macam. Yang per goresan membuang goresan yang disentuh; yang
sebagian memotong bagian yang dilewati dan **membelah** goresan yang dihapus di
tengahnya. Jebakan yang ditemukan di sini: goresan cepat hanya menyimpan titik
yang berjauhan, jadi penghapus yang memeriksa titik saja akan melewatkan
goresan yang jelas dilewatinya — ruas yang tersentuh dirapatkan dulu, dan hanya
yang tersentuh, supaya sisa goresannya tetap sehemat semula.

Berkasnya `<nama>.catatan.json`: JSON beridentasi tab dengan kunci terurut,
seperti berkas lain di repositori ini. Bukan format biner, karena catatan ini
hidup di dalam git — diff-nya harus terbaca. Berkas dari versi format yang
lebih baru ditolak dengan jelas alih-alih dibaca setengah-setengah lalu
disimpan balik dalam keadaan rusak. Ekspor Markdown dan PDF berdiri di
sampingnya: Markdown kehilangan posisi, PDF kehilangan kemampuan disunting,
jadi keduanya cara membagikan — bukan pengganti.

Yang belum ada: mengubah tulisan tangan jadi teks dan diagram. Wadahnya sudah
berdiri, jadi yang tersisa hanya bagian pengenalannya.

## Koordinat anotasi

Zotero menyimpan persegi anotasi sebagai `[x1, y1, x2, y2]` dalam satuan poin
PDF dengan titik asal di **kiri-bawah** halaman — sama persis dengan `PdfRect`
milik pdfrx. Jadi tidak ada konversi satuan, hanya pembalikan sumbu Y saat
menggambar:

```
x_lokal = x_pdf * (lebar_halaman_di_layar / lebar_halaman_pdf)
y_lokal = (tinggi_halaman_pdf - y_pdf) * (tinggi_di_layar / tinggi_pdf)
```

Penandaan digambar lewat `PdfViewerParams.pageOverlaysBuilder` (bukan
`pagePaintCallbacks`) supaya ikut ter-*rebuild* setiap kali daftar anotasi
berubah, tanpa memaksa pdfrx memuat ulang gambar halaman.

Satu seleksi teks dipetakan menjadi beberapa persegi — satu per baris — dengan
`PdfPageTextRange.enumerateFragmentBoundingRects()`, lalu potongan yang berada
pada baris yang sama digabung. Ini menghasilkan bentuk `rects` yang sama dengan
yang ditulis Zotero sendiri.

## Sinkronisasi git

`GitBackend` adalah antarmuka; di desktop implementasinya `GitCliBackend`, yang
memanggil biner `git` sistem:

- **SSH** lewat `GIT_SSH_COMMAND` (`-i <kunci> -o IdentitiesOnly=yes`,
  `BatchMode=yes` supaya tidak pernah menunggu input).
- **HTTPS** lewat berkas bantu `GIT_ASKPASS` berumur pendek, sehingga token
  tidak pernah masuk ke URL remote atau `.git/config`.
- `GIT_TERMINAL_PROMPT=0` di semua perintah agar kegagalan autentikasi langsung
  jadi error, bukan proses yang menggantung.
- Pesan error git yang umum diterjemahkan ke bahasa yang bisa ditindaklanjuti
  (kunci ditolak, token kedaluwarsa, repo tidak ditemukan, konflik, jaringan).

### Clone hemat

Library Zotero didominasi PDF, jadi clone bawaannya **partial + sparse**:

```bash
git clone --filter=blob:none --sparse --single-branch <url> <dir>
git -C <dir> sparse-checkout set --no-cone '/*' '!/**/attachments/**' '!/**/attachments-lfs/**'
```

Diukur pada repositori asli (1.740 item, 187 PDF):

| | Ukuran | Waktu |
| --- | --- | --- |
| clone penuh | ~940 MB | menit-an |
| partial + sparse | **~23 MB** | **~14 detik** |
| membuka satu paper | +berkas itu saja | ~4 detik |

Saat sebuah paper dibuka, `fetchAttachment` menjalankan
`git sparse-checkout add '/<folder berkas>/*'`; pada partial clone perintah itu
sekaligus menarik blob-nya dari remote. `GitRepoStatus.lazyAttachments`
mendeteksi kondisi ini dari `remote.origin.partialclonefilter` +
`core.sparseCheckout`, dan UI memakainya untuk menampilkan tombol **Unduh**.
Push dari partial clone sudah diuji terhadap remote asli dengan `--dry-run`.

### Progres

Keluaran `git --progress` (dipisah carriage return) diurai
`GitProgressParser` menjadi fase, persen, jumlah objek, dan kecepatan, sehingga
bilah progres benar-benar menunjukkan kemajuan. Baris tanpa persentase tetap
memakai bilah indeterminate alih-alih angka palsu.

## Sinkronisasi Android (tanpa git)

Android tidak punya biner `git`, jadi `gitBackendProvider` memilih
`GitHubApiBackend` di sana. Antarmuka `GitBackend` tidak berubah, sehingga
seluruh UI dan `WorkspaceController` sama persis di kedua platform.

Alih-alih clone, backend ini menyimpan **mirror**:

```
<folder profil>/
  .readpaper/sync-state.json     commit asal, id blob tiap berkas, antrean kirim
  zotero/my-library/…            metadata (±19 MB) — ikut di-mirror
  zotero/my-library/attachments/ kosong sampai papernya dibuka (±529 MB di GitHub)
```

| Operasi | Yang terjadi |
| --- | --- |
| clone | `GET /commits/{branch}` → `GET /git/trees/{sha}?recursive=1` → unduh setiap blob metadata (8 paralel), catat id blob lampiran untuk nanti |
| fetch | bandingkan `headSha` dengan commit mirror, hitung selisih commit |
| pull | ambil pohon baru, unduh blob yang id-nya berubah, hapus berkas yang hilang di remote |
| commit | catat berkas yang berubah ke antrean lokal (`pending`) — belum menyentuh GitHub |
| push | `POST /git/blobs` tiap berkas → `POST /git/trees` di atas pohon commit terakhir → `POST /git/commits` → `PATCH /git/refs/heads/{branch}` |
| buka lampiran | `GET /git/blobs/{sha}` satu berkas saja, saat tombol **Unduh** ditekan |

Beberapa keputusan yang penting:

- **Deteksi perubahan tanpa git.** `gitBlobSha()` menghitung id blob git
  (`sha1("blob <len>\0" + isi)`), jadi mirror bisa dibandingkan langsung dengan
  daftar pohon GitHub. Pemeriksaan murah (ukuran + mtime) dilakukan dulu; sha1
  hanya dihitung kalau keduanya berubah, supaya status tetap cepat di ponsel.
- **Push menolak kalau remote sudah bergerak.** Commit dibuat di atas
  `state.commitSha`; kalau `headSha` remote sudah berbeda, push dibatalkan dan
  pengguna diminta menarik perubahan dulu — tidak pernah memaksa.
- **SSH tidak tersedia** di jalur ini; `supportedTransports` hanya berisi HTTPS
  dan editor profil otomatis menyembunyikan pilihan SSH di Android.
- **Izin `INTERNET`** dideklarasikan di `android/app/src/main/AndroidManifest.xml`.
  Flutter hanya menambahkannya pada manifest debug, jadi tanpa baris itu build
  rilis tidak bisa mengakses jaringan sama sekali.
- **Git LFS belum didukung** di Android; berkas `attachments-lfs/` perlu
  endpoint LFS batch tersendiri.

## Kinerja

Library asli berisi 1.740 item dalam ~1.740 berkas JSON. Seluruh proses
pembacaan dijalankan di isolate terpisah lewat `Isolate.run`, sehingga UI tidak
pernah terblokir. Pada mesin pengembangan, parsing penuh memakan ~360 ms.

## Penyimpanan setelan

```
$XDG_DATA_HOME/readpaper/            (default ~/.local/share/readpaper)
  config.json                        profil repositori + preferensi
  credentials.json                   token HTTPS, izin 600
  repos/<owner>-<repo>/              clone lokal tiap profil
```

Berpindah repositori = mengganti `activeProfileId`. Karena tiap profil punya
folder clone sendiri, perpindahan antar repo yang sudah pernah di-clone terjadi
seketika.
