# Sitasi ReadPaper di Word dan OnlyOffice

Folder ini berisi dua pemasangan untuk menyisipkan sitasi dan daftar pustaka
dari library ReadPaper langsung di pengolah kata, plus kode bersama keduanya.
Kontraknya — server lokal, bentuk data di dokumen, dan daftar perintah — ada di
[`docs/api-sitasi.md`](../docs/api-sitasi.md).

| Folder | Isi |
|---|---|
| `core/` | Kode bersama: citeproc-js, pemanggil server ReadPaper, inti sitasi, perintah, dan panel. Lihat [`core/README.md`](core/README.md). |
| `onlyoffice/` | Plugin OnlyOffice (`config.json` + `index.html`), dipaket menjadi berkas `.plugin`. |
| `word/` | Add-in Office.js untuk Microsoft Word: `manifest.xml` dan task pane yang disajikan dari GitHub Pages. |

Mesin sitasinya **citeproc-js**, mesin yang dipakai Zotero sendiri, dengan gaya
dan locale CSL yang sama dengan yang dibundel ReadPaper. ReadPaper desktop
hanya menyediakan data (lewat `http://127.0.0.1:23121`); sitasi, nomor, dan
daftar pustaka dihitung di dalam editor.

## Sebelum memasang: ReadPaper dan token

1. Jalankan ReadPaper **desktop** (Linux, Windows, atau macOS) dan buka
   library yang akan disitasi. Server sitasinya hanya mendengarkan di
   `127.0.0.1`, jadi Word/OnlyOffice harus di komputer yang sama.
2. Buka **Pengaturan** ReadPaper, kartu **Sitasi di Word & OnlyOffice**, lalu
   salin **token**-nya.
3. Saat panel ReadPaper pertama kali dibuka di Word atau OnlyOffice, ia meminta
   token itu. Tempel, lalu **Simpan dan periksa**. Token bisa diganti kapan
   saja lewat tombol **Token…** di panel. Bila token di ReadPaper dibuat ulang,
   panel akan bilang "Token salah" sampai token baru ditempel.

Token disimpan di penyimpanan lokal panel di komputer itu, tidak di dalam
dokumen.

## OnlyOffice Desktop Editors

Butuh **OnlyOffice 9.0 atau lebih baru** (Linux atau Windows).

### Memasang dari berkas `.plugin`

Berkas `readpaper-onlyoffice-<versi>.plugin` dilampirkan di setiap rilis
GitHub, atau buat sendiri:

```sh
scripts/package-onlyoffice-plugin.sh   # hasil: build/integrations/readpaper-onlyoffice-<versi>.plugin
```

Lalu di OnlyOffice: tab **Plugin** → **Pengelola Plugin** (*Plugin Manager*) →
**Plugin saya** (*My plugins*) → **Pasang plugin secara manual** (*Install
plugin manually*) → pilih berkas `.plugin`. Tombol **ReadPaper** muncul di tab
Plugin; panelnya terbuka di sisi kiri.

### Atau: salin ke folder plugin

Ekstrak berkas `.plugin` (sebuah zip) ke folder bernama GUID plugin,
`{B7FE5580-F725-4545-9808-E1B34505DCC1}`, di:

- Linux: `~/.local/share/onlyoffice/desktopeditors/sdkjs-plugins/`
- Windows: `%UserProfile%\AppData\Local\ONLYOFFICE\DesktopEditors\data\sdkjs-plugins\`

lalu jalankan ulang OnlyOffice. Plugin yang dipasang dengan cara ini tidak bisa
dihapus dari Pengelola Plugin; hapus foldernya.

## Microsoft Word

Task pane disajikan dari
`https://situkangsayur.github.io/readpaper/word/taskpane.html`, jadi yang
dipasang hanya `word/manifest.xml`. Butuh Word yang menjalankan add-in dengan
**WebView2/Edge**: Microsoft 365 atau Office 2021 ke atas di Windows, atau Word
di peramban. Word 2016/2019 non-langganan memakai mesin Internet Explorer dan
tidak didukung; panelnya akan mengatakan begitu.

### Word di Windows (desktop): katalog folder bersama

1. Buat folder, misalnya `C:\ReadPaperAddin`, salin `manifest.xml` ke sana.
2. Klik kanan folder → **Properties** → **Sharing** → **Share…** → bagikan ke
   akun sendiri. Catat alamat jaringannya, misalnya `\\NAMA-PC\ReadPaperAddin`.
3. Di Word: **File** → **Options** → **Trust Center** → **Trust Center
   Settings…** → **Trusted Add-in Catalogs**. Isi **Catalog Url** dengan alamat
   jaringan tadi → **Add catalog** → centang **Show in Menu** → **OK**.
4. Tutup dan buka lagi Word.
5. **Insert** (Sisipkan) → **Add-ins** / **My Add-ins** → tab **SHARED
   FOLDER** → **ReadPaper** → **Add**. Tombol **Sitasi ReadPaper** muncul di
   tab **References** (Referensi).

### Word di peramban (Word web)

1. Buka dokumen di Word web → **Insert** → **Add-ins** (di versi baru:
   **Home** → **Add-ins** → **More Add-ins**) → **Upload My Add-in** /
   **Unggah Add-in Saya**.
2. Pilih `manifest.xml` → **Upload**.
3. Peramban harus mengizinkan halaman https memanggil `http://127.0.0.1`.
   Chrome dan Edge menanyakan izin **akses jaringan lokal** saat panel pertama
   kali menghubungi ReadPaper — pilih **Izinkan**. Bila panel selalu bilang
   "ReadPaper tidak berjalan" padahal ReadPaper terbuka, periksa izin itu di
   pengaturan situs untuk `situkangsayur.github.io` (dan domain Office).
   Firefox dan Safari belum diuji.

### Word di macOS

Belum diuji. Word di macOS memakai WKWebView (Safari), yang bisa memperlakukan
panggilan https → `http://127.0.0.1` berbeda dari Chromium. Sideload di macOS:
salin `manifest.xml` ke
`~/Library/Containers/com.microsoft.Word/Data/Documents/wef/` lalu buka
**Insert** → **Add-ins** → **My Add-ins**.

## Memakai

Panel ReadPaper sama di kedua editor:

- **Sisipkan sitasi** — ketik untuk mencari (judul, pengarang, tahun,
  abstrak); Enter menambah hasil yang disorot, beberapa item boleh. Per item:
  lokator (halaman, bab, …), prefiks, sufiks, sembunyikan pengarang, atau
  **Pilih anotasi** — anotasi ReadPaper dipakai sebagai penanda dan nomor
  halamannya mengisi lokator. Ctrl+Enter menyisipkan. Sitasi baru langsung
  bernomor/berteks sesuai sitasi yang sudah ada; sitasi lain tidak ditulis
  ulang.
- **Sunting sitasi** — letakkan kursor di dalam sebuah sitasi.
- **Sisipkan / Bangun ulang daftar pustaka** — di posisi kursor bila belum
  ada.
- **Perbarui semua** — memindai dokumen, mengambil data item terbaru bila
  ReadPaper berjalan, merender ulang semua sitasi sesuai urutan kemunculan
  (gaya bernomor jadi berurutan lagi) dan semua daftar pustaka. Daftar pustaka
  hanya berisi yang benar-benar disitasi, ditambah item "tanpa disitasi".
- **Gaya sitasi…** — memilih gaya dan bahasa, lalu perbarui semua.
- **Tanpa disitasi…** — item yang masuk daftar pustaka tanpa disitasi, dan
  kebalikannya.
- **Jadikan teks biasa…** — membuang semua content control ReadPaper dan data
  sitasinya; teksnya tinggal.

Dokumen menyimpan sitasinya sendiri, termasuk salinan data item dan salinan
gaya serta locale terakhir, sehingga **Perbarui semua** tetap jalan di
komputer tanpa ReadPaper.

## Di mana data disimpan

| | OnlyOffice | Word |
|---|---|---|
| Sitasi | content control inline; tag `READPAPER_CITATION_v1:<base64 JSON>` berisi seluruh data sitasi | content control inline; tag pendek `READPAPER_CITATION_v1#c-xxxxxx`, datanya di custom XML part |
| Daftar pustaka | content control blok; tag `READPAPER_BIBLIOGRAPHY_v1:<base64 pengaturan>` | content control blok; tag `READPAPER_BIBLIOGRAPHY_v1` |
| Pengaturan dokumen + salinan gaya/locale | custom XML part `urn:readpaper:citations:1` (cadangan pengaturan di tag daftar pustaka) | custom XML part `urn:readpaper:citations:1` |

Keduanya membaca kedua bentuk tag, jadi .docx yang disunting di OnlyOffice
bisa diteruskan di Word dan sebaliknya.

## Keterbatasan

- **Belum diuji di Word sungguhan maupun di panel OnlyOffice sungguhan.** Yang
  sudah diuji: inti sitasi dan semua perintah dengan editor tiruan (Node),
  panel di jsdom, task pane termuat di Chrome, manifest lolos
  `office-addin-manifest validate`, dan kode editor plugin OnlyOffice di
  OnlyOffice DocumentBuilder 9.0.4 dan 9.4.0
  (`scripts/test-onlyoffice-docbuilder.sh`, butuh Docker): sisip, tulis ulang,
  daftar pustaka, custom XML, simpan .docx, buka lagi, teks biasa.
- Word di macOS belum diuji; Word web butuh peramban yang mengizinkan akses
  ke jaringan lokal (lihat di atas).
- Hanya sitasi di dalam teks; gaya catatan kaki belum didukung.
- Di Word, sitasi yang disalin ke **dokumen lain** kehilangan datanya (data ada
  di custom XML part dokumen asal) dan dilaporkan sebagai "sitasi tanpa data".
  Salin-tempel di dokumen yang sama aman.
- Di Word, data sitasi yang dihapus tetap tersimpan di custom XML part (supaya
  Urungkan tetap berfungsi) sampai **Jadikan teks biasa**. Daftar pustaka
  tidak terpengaruh: ia selalu dibangun dari sitasi yang ada di dokumen.
- Spasi baris gaya (mis. spasi ganda APA) diterapkan pada daftar pustaka di
  OnlyOffice, tetapi tidak di Word.
- `noBib` di gaya bernomor: itemnya tetap mendapat nomor (citeproc menomori
  semua yang disitasi), hanya entrinya yang tidak muncul di daftar pustaka.
- Plugin OnlyOffice memuat `plugins.js` OnlyOffice dari
  `onlyoffice.github.io`, seperti plugin resmi; tanpa internet ia mencoba
  salinan milik editor di `../v1/`.
- GitHub Pages harus sudah diatur ke sumber "GitHub Actions" agar workflow
  `integrations.yml` bisa menerbitkan task pane Word.
