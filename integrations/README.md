# Sitasi ReadPaper di Word, OnlyOffice, LibreOffice, dan Google Docs

Folder ini berisi empat pemasangan untuk menyisipkan sitasi dan daftar
pustaka dari library ReadPaper langsung di pengolah kata, plus kode bersama
semuanya.
Kontraknya — server lokal, bentuk data di dokumen, dan daftar perintah — ada di
[`docs/api-sitasi.md`](../docs/api-sitasi.md).

| Folder | Isi |
|---|---|
| `core/` | Kode bersama: citeproc-js, pemanggil server ReadPaper, inti sitasi, perintah, dan panel. Lihat [`core/README.md`](core/README.md). |
| `onlyoffice/` | Plugin OnlyOffice (`config.json` + `index.html`), dipaket menjadi berkas `.plugin`. |
| `word/` | Add-in Office.js untuk Microsoft Word: `manifest.xml` dan task pane yang disajikan dari GitHub Pages. |
| `libreoffice/` | Ekstensi LibreOffice Writer (Python-UNO), dipaket menjadi `.oxt`. |
| `google-docs/` | Add-on Google Docs (Apps Script): panel samping di peramban + penulis dokumen di server Google. |

Mesin sitasinya **citeproc-js**, mesin yang dipakai Zotero sendiri, dengan gaya
dan locale CSL yang sama dengan yang dibundel ReadPaper: APA 7, IEEE,
Vancouver (NLM dan AMA), Harvard (Cite Them Right), MLA 9, Chicago
author-date, AMA 11, dan NLM. Di Word, OnlyOffice, dan Google Docs mesin itu
berjalan di panelnya sendiri; LibreOffice tidak punya mesin JavaScript, jadi
ReadPaper yang menjalankannya untuknya (`POST /api/run`, kode inti yang sama
persis). Hasilnya sama sampai ke satu karakter di keempat editor.

**Daftar pustaka selalu diturunkan dari dokumen.** Setiap "Perbarui semua"
memindai dokumen dari awal; referensi yang sitasinya dikurangi dari sebuah
klaster atau dihapus dari teks langsung hilang dari daftar pustaka — juga dari
daftar "Tanpa disitasi". Bug Zotero yang meninggalkan referensi lama di daftar
pustaka tidak punya tempat untuk terjadi, dan diuji di keempat editor.

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

## LibreOffice Writer

Butuh **LibreOffice 7.6 atau lebih baru** (content control bertag) dan
ReadPaper desktop yang berjalan. ReadPaper merender sitasinya dengan
JavaScriptCore: di Debian/Ubuntu paket `libjavascriptcoregtk-4.1-0` (ikut
terpasang bersama GNOME, dan direkomendasikan paket .deb ReadPaper), di
Arch/CachyOS `webkit2gtk-4.1`. Pengaturan ReadPaper menyebut apakah mesin itu
sudah ditemukan.

### Memasang

Berkas `readpaper-libreoffice-<versi>.oxt` dilampirkan di setiap rilis, atau
buat sendiri dengan `scripts/package-libreoffice-extension.sh`. Lalu:

- **Alat** → **Pengelola Ekstensi** (*Tools → Extension Manager*) →
  **Tambah…** → pilih berkas `.oxt` → jalankan ulang LibreOffice; atau
- dari terminal: `unopkg add readpaper-libreoffice-<versi>.oxt`

Menu **ReadPaper** muncul di bilah menu Writer, dan bilah alat ReadPaper
(Sisipkan sitasi, Daftar pustaka, Perbarui semua) bisa dinyalakan dari
**Tampilan → Bilah Alat**.

### Token

Tidak perlu disalin: ekstensinya membaca token ReadPaper dari
`~/.local/share/readpaper/credentials.json` di komputer yang sama (hanya
kunci token sitasi; isi lain berkas itu tidak disentuh). Bila ReadPaper
memakai folder lain, tempel tokennya lewat **ReadPaper → Token…**; disimpan di
profil LibreOffice dengan izin 600.

### Di dokumen

- Sitasi: content control inline bertag `READPAPER_CITATION_v1:<base64 JSON>`
  — bentuk yang sama dengan OnlyOffice, jadi .docx bisa berpindah editor.
- Daftar pustaka: bookmark `READPAPER_BIBLIOGRAPHY_v1` yang membentang di
  paragrafnya. (Section tidak dipakai: disimpan sebagai .docx ia berubah
  jadi pemisah section yang mengganti halaman.) Daftar pustaka buatan Word
  atau OnlyOffice dikenali dan diubah ke bentuk bookmark saat ditulis ulang,
  tanpa meninggalkan entri lamanya.
- Pengaturan, gaya, dan salinan gaya/locale: properti dokumen
  `ReadPaperCitations` (Berkas → Properti → Properti Kustom).
- Setiap perintah satu langkah **Urungkan**.

## Google Docs

Add-on Apps Script dengan panel samping — panel yang sama dengan Word dan
OnlyOffice. Panelnya berjalan di peramban Anda, jadi ia menghubungi ReadPaper
di `127.0.0.1` langsung dan tahu posisi kursor; dokumennya ditulis lewat
Apps Script. Satu perintah hanya dua panggilan ke server Google (potret
dokumen, lalu tulis perubahan), supaya menyisipkan sitasi tetap ringan.

### Memasang (sekali, dengan akun Google sendiri)

1. Siapkan proyeknya: `scripts/package-google-docs-addon.sh` (hasilnya
   `build/integrations/google-docs/`), atau ekstrak
   `readpaper-google-docs-<versi>.zip` dari rilis.
2. Pasang [clasp](https://github.com/google/clasp) (`npm i -g @google/clasp`),
   `clasp login`, lalu di folder tadi: `clasp create --type standalone
   --title "ReadPaper"` dan `clasp push`.
   (Tanpa clasp: buka <https://script.google.com>, proyek baru, lalu buat
   berkas-berkasnya satu per satu dengan isi yang sama — `Code.gs`,
   `Sidebar.html`, setiap `rp-*.html`, dan `appsscript.json` lewat
   Setelan proyek → tampilkan manifest.)
3. Di editor Apps Script: **Terapkan → Uji penerapan → Add-on editor →
   Google Docs**, pilih dokumen, **Jalankan**. Atau, untuk semua dokumen
   sendiri, pasang sebagai add-on tidak terdaftar (lihat dokumentasi Google
   "Test an editor add-on").
4. Di dokumen: **Ekstensi → ReadPaper → Buka panel sitasi**. Tempel token
   ReadPaper saat diminta. Chrome dan Edge menanyakan izin **akses jaringan
   lokal** sekali — pilih **Izinkan**.

Scope yang diminta hanya `documents.currentonly` (dokumen yang sedang
dibuka) dan `script.container.ui` (panel), bukan seluruh Drive.

### Di dokumen

- Sitasi: named range `READPAPER_CITATION_v1#c-xxxxxx` di atas teksnya.
- Daftar pustaka: named range `READPAPER_BIBLIOGRAPHY_v1` di atas
  paragrafnya.
- Data sitasi, pengaturan, dan salinan gaya: properti dokumen add-on,
  dipecah per 8000 karakter.

## Memakai

Panel ReadPaper sama di Word, OnlyOffice, dan Google Docs; menu ReadPaper di
LibreOffice berisi perintah yang sama:

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

- **LibreOffice** diuji di Writer sungguhan (24.2, tanpa layar dan di Xvfb):
  sisip, sunting klaster, hapus, daftar pustaka, perbarui, simpan .odt dan
  .docx lalu buka lagi, daftar pustaka buatan Word, teks biasa, dan .oxt yang
  dipasang dengan unopkg. Sitasi di catatan kaki dan kotak teks belum
  didukung; di tabel didukung.
- **Google Docs** diuji dengan DocumentApp tiruan, bukan Google Docs
  sungguhan — pemasangan pertama perlu dicoba dengan akun Google sendiri.
  Salinan dokumen (Berkas → Buat salinan) tidak membawa properti add-on,
  jadi sitasi di salinannya dilaporkan "tanpa data" sampai disisipkan ulang;
  teksnya tetap. Ekspor ke .docx membuang named range.
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
