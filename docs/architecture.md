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
