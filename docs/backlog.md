# ReadPaper — Backlog

Status per 2026-09-25. Fase 1 selesai dan teruji di desktop Linux dan di
perangkat Android; fase 4 terpasang dan dipakai sehari-hari. Fase 5–12 baru
rencana: belum ada satu barispun kodenya kecuali yang ditandai `[~]`.

Legenda: `[x]` selesai · `[~]` sebagian · `[ ]` belum.

---

## Urutan pengerjaan

Fase 1–4 sudah jalan. Sisanya dikerjakan berurutan seperti di bawah; urutannya
bukan selera, tapi mengikuti apa yang menghalangi apa.

| Tahap | Isi | Kenapa di sini | Menghalangi |
|---|---|---|---|
| **A** | Bug terbuka + Fase 5 (alat tulis) & Fase 6 (kenyamanan baca) | Ini yang dipakai tiap hari dan sebagiannya sudah setengah jadi | — |
| **B** | Fase 7 (recent, pindah koleksi, duplikat) | Murni di atas data yang sudah ada, tidak menunggu apa pun | — |
| **C** | Fase 8 (dwibahasa) | Harus **sebelum** fitur baru menumpuk teks Indonesia di kode. Makin lama ditunda makin mahal | Fase 9, 12 |
| **D** | Fase 9 (bibliografi & CSL) | Mesin CSL adalah inti sitasi; berdiri sendiri dan bisa diuji tanpa editor apa pun | Fase 10 |
| **E** | Fase 11 (sistem plugin) | Keputusan runtime-nya mengikat selamanya, jadi harus diambil sebelum ada plugin | Fase 12 |
| **F** | Fase 12 (AI Detector & Humanizer) | Plugin pertama, sekaligus pembuktian API Fase 11 | — |
| **G** | Fase 10 (sitasi di editor + build desktop) | Paling besar dan paling banyak bergantung: butuh CSL (D), butuh anotasi sebagai bookmark (Fase 5), butuh aplikasi desktop | — |

Catatan: Fase 10 sengaja ditaruh terakhir sesuai permintaan — dikerjakan
setelah yang lain selesai.

Tiga keputusan yang harus diambil **sebelum** tahapnya dimulai, karena sulit
diubah setelah dipakai orang:

1. ~~**Runtime plugin**~~ — diusulkan: WebAssembly lewat inti Rust (KT-2).
2. ~~**Jalur Google Docs**~~ — diusulkan: Google Docs API resmi (KT-3).
3. ~~**Gaya CSL kesehatan nasional Indonesia**~~ — pakai gaya CSL yang sudah
   ada di repositori, jangan menulis sendiri.
4. ~~**Lisensi SDK plugin**~~ — AGPL-3.0, sama dengan intinya, supaya plugin
   pihak ketiga pun tetap terbuka.

Keempatnya disetujui 2026-09-25. Rinciannya di
[keputusan-teknis.md](keputusan-teknis.md).

---

## Bug terbuka

- [x] **Salin teks menghasilkan papan klip kosong** — ternyata bukan bug
      aplikasi, melainkan kesalahan pengujian: tekan-lama jatuh tepat di spasi
      antara dua kata, jadi yang tersalin memang satu karakter spasi. Ketahuan
      setelah `hasSelectedText`, jumlah rentang, dan panjang teksnya
      ditampilkan langsung di layar. Yang tetap diperbaiki: penyalinan
      sekarang memakai `Clipboard.setData` sendiri dengan cadangan teks yang
      disimpan selagi pilihan masih hidup, jumlah karakter ditampilkan setelah
      menyalin, dan memilih spasi memberi pesan yang menyebut sebabnya —
      sebelumnya papan klip berisi spasi terlihat persis seperti kegagalan.
- [ ] Menyalin tidak mungkin selama mode penanda aktif (sapuan langsung jadi
      stabilo). Sudah dijelaskan di bilah mode, tapi perlu dilihat lagi apakah
      ada cara yang lebih enak daripada mematikan mode dulu.

---

## Fase 1 — Baca, tandai, sinkron (MVP)

Tujuan: buka repo Zotero di GitHub, telusuri koleksi, baca PDF, beri stabilo
berwarna dan komentar, lalu commit & push perubahannya.

### 1.1 Sinkronisasi GitHub
- [x] Clone repo lewat **SSH** (`git@github.com:...`) dengan pilihan kunci privat per profil
- [x] Clone repo lewat **HTTPS** + personal access token (token disimpan di
      `credentials.json`, izin `600`, tidak pernah masuk ke URL remote)
- [x] `fetch` / `pull --rebase --autostash` / `commit` / `push`
- [x] Git LFS: berkas besar diunduh per berkas saat papernya dibuka
      (`git lfs pull --include=<path>`), bukan sekaligus setiap kali pull —
      pada library asli itu 136 MB dalam dua buku. Tombol "Unduh semua berkas
      LFS" tetap ada di panel sinkronisasi kalau memang diinginkan.
- [x] Status working copy: jumlah perubahan lokal, ahead/behind, commit terakhir
- [x] Panel detail sinkronisasi: daftar perubahan, riwayat commit, log mentah git
- [x] PDF baru yang ditambahkan lewat GitHub otomatis muncul setelah `pull`
      (library dibaca ulang)
- [ ] Deteksi & bantuan penyelesaian konflik merge (saat ini hanya menampilkan pesan error git)
- [x] Aksi sinkronisasi saat proses berjalan memberi pesan, bukan tombol mati
- [ ] Auto-fetch berkala di latar belakang
- [x] Indikator progres berpersen saat clone/pull (fase, jumlah objek, kecepatan),
      diurai dari keluaran `git --progress`
- [x] **Clone hemat**: `--filter=blob:none` + sparse-checkout tanpa `attachments/`,
      lalu tiap PDF diambil saat papernya dibuka. Pada library asli: ~23 MB /
      ~14 detik, dari ~940 MB untuk clone penuh

### 1.2 Ganti / pindah repositori
- [x] Profil repositori: nama, URL, transport, branch, folder clone, identitas commit
- [x] Berpindah repo = mengganti profil aktif; setiap profil punya folder clone sendiri,
      jadi pindah bolak-balik tidak meng-clone ulang
- [x] Tambah / ubah / hapus profil (opsional ikut menghapus folder clone lokal)
- [x] Folder clone default otomatis dari `owner-repo`, bisa diganti manual
- [x] Dukungan beberapa library dalam satu repo (`my-library`, `group-…`)
- [ ] Impor profil dari `git remote` yang sudah ada di folder lokal

### 1.3 Struktur koleksi ala Zotero
- [x] Membaca `collections.json`, `items/<XX>/<KEY>.json`, `notes/`, `attachments/`,
      `attachments-lfs/`, `.zotero-sync/manifest.json`
- [x] Pohon koleksi bertingkat, **expand / collapse** per koleksi, buka/tutup semua
- [x] Jumlah item per koleksi (termasuk sub-koleksi)
- [x] Pseudo-koleksi "Semua item" dan "Tanpa koleksi"
- [x] Opsi "sertakan item sub-koleksi" seperti Zotero
- [x] Daftar item: judul, pengarang, tahun, jenis, badge lampiran/anotasi/catatan
- [x] Urutkan: judul, tahun, pengarang, tanggal ditambahkan, jumlah anotasi
- [x] Cari cepat (judul, pengarang, tahun, DOI, tag)
- [x] Parsing di isolate terpisah supaya UI tidak macet untuk ~1.700 item
- [ ] Cache indeks ke disk agar buka aplikasi berikutnya instan
- [ ] Saved searches (`searches.json`) dan warna tag (`settings.json`)

### 1.4 Pembaca & anotasi
- [x] Baca PDF (pdfium lewat `pdfrx`), zoom, navigasi halaman
- [x] Seleksi teks
- [x] **Stabilo berwarna** pada teks tertentu (8 warna palet Zotero)
- [x] **Garis bawah** berwarna
- [x] **Komentar** pada stabilo (buat langsung lewat "Stabilo + komentar")
- [x] Catatan lepas di halaman (tekan lama pada area kosong → anotasi tipe `text`)
- [x] Klik anotasi di halaman → ubah warna / komentar / hapus
- [x] Panel samping anotasi: daftar kutipan + komentar, klik untuk loncat ke posisinya
- [x] Anotasi ditulis balik ke `items/<XX>/<KEY>.json` dalam format Zotero API JSON
      (`annotationPosition`, `annotationSortIndex`, dst.) sehingga bisa diimpor
      kembali oleh plugin Zotero
- [x] Blok `## Annotations` di `notes/**.md` ikut diperbarui (tetap terbaca di Obsidian)
- [x] Setiap perubahan anotasi jadi satu commit; opsi push otomatis per profil
- [ ] Pencarian teks di dalam PDF (`PdfTextSearcher` sudah tersedia di pdfrx)
- [ ] Daftar isi / outline PDF
- [ ] Anotasi area (screenshot) dan coretan tinta
- [ ] Tag pada anotasi
- [ ] Ekspor anotasi ke Markdown / clipboard

---

## Fase 2 — Metadata & pencarian pengarang

Tujuan: menjawab "siapa pengarangnya" dan "apa detail buku/paper ini".

- [~] Panel detail item (pengarang, publikasi, DOI, URL, penerbit, tag, koleksi,
      tanggal, dan sisa field Zotero) — sudah ada, masih perlu dirapikan
- [ ] Pencarian khusus pengarang (facet daftar pengarang + jumlah karyanya;
      `LibraryIndex.creatorFacets()` sudah disiapkan)
- [ ] Filter gabungan: pengarang × tahun × jenis item × tag
- [ ] Halaman "profil pengarang": semua karya, koleksi tempat ia muncul, rentang tahun
- [ ] Pencarian lanjutan dengan operator (`author:`, `year:`, `tag:`, `type:`)
- [ ] Pengayaan metadata dari DOI (Crossref / OpenAlex) untuk item yang datanya kosong
- [ ] Ekstraksi metadata dari isi PDF ketika item tidak punya metadata sama sekali
- [ ] Ekspor sitasi per item atau per koleksi — dipindahkan ke Fase 9
- [ ] Statistik library: jumlah per tahun, per jenis, pengarang terbanyak

---

## Fase 3 — Format ebook lain

- [ ] EPUB: pembaca + stabilo + komentar (posisi disimpan sebagai CFI/offset)
- [ ] DjVu / CBZ (opsional, prioritas rendah)
- [ ] Teks biasa & Markdown sebagai lampiran
- [ ] Deteksi format otomatis dari `contentType` dan ekstensi berkas

---

## Fase 4 — Android & distribusi

- [x] **Backend sinkronisasi Android** (`GitHubApiBackend`): Android tidak punya
      biner `git`, jadi repositori di-*mirror* lewat GitHub REST API —
      baca pohon commit, unduh blob metadata, tulis balik sebagai blob → tree →
      commit → pindahkan ref. Antarmuka `GitBackend` dipakai apa adanya, jadi
      seluruh UI dan pengendali tidak berubah.
- [x] **Lampiran diunduh sesuai kebutuhan**: metadata library ±19 MB ikut
      di-mirror, PDF (±529 MB) tetap di GitHub sampai papernya dibuka
      ("Unduh" pada kartu lampiran)
- [x] Izin `INTERNET` pada manifest rilis (Flutter hanya menambahkannya di
      manifest debug — build rilis tanpa ini tidak bisa jaringan sama sekali)
- [x] Tata letak layar sempit: laci koleksi, daftar → detail, panel anotasi
      sebagai laci kanan, bilah sinkronisasi ringkas
- [x] **Tata letak tablet**: tiga kelas ukuran (compact <600dp, medium 600–1099dp,
      expanded ≥1100dp). Tablet 11" potret (±960dp) menampilkan daftar + detail
      berdampingan, lanskap (±1536dp) menampilkan koleksi + daftar + detail.
- [x] Sasaran sentuh: kerapatan tema mengikuti jenis perangkat, baris pohon
      koleksi 48dp di layar sentuh, chevron punya area ketuk sendiri
- [x] Tekan-lama dikembalikan ke seleksi teks di perangkat sentuh; membuat
      catatan lepas kini lewat tombol khusus di bilah pembaca
- [x] Ikon peluncur sendiri (adaptive + monochrome), menggantikan logo Flutter
      bawaan yang membuatnya kembar dengan aplikasi lain
- [x] Editor profil menyesuaikan diri: di Android hanya menawarkan HTTPS + token
- [x] Build APK rilis (arm64)
- [ ] Uji end-to-end di perangkat dengan token GitHub sungguhan
- [ ] Penyimpanan token di keystore Android (sekarang di berkas privat aplikasi)
- [ ] Git LFS di Android (`attachments-lfs/`) — perlu endpoint LFS batch
- [x] APK hanya mengiklankan arm64-v8a. Sebelumnya ada pustaka 32-bit nyasar
      dari sebuah plugin sehingga APK mengaku mendukung armeabi-v7a dan x86_64
      padahal libflutter.so-nya tidak ada di sana — perangkat 32-bit akan
      memasangnya lalu crash saat dibuka.
- [ ] Penandatanganan rilis dengan keystore sendiri (sekarang debug key)
- [ ] **Rilis GitHub**: tag + Release berisi APK supaya bisa diunduh dari GitHub
- [x] **Publikasi APK ke `http://10.100.21.22:8899`** (folder `~/apk-share/`,
      dilayani systemd user service `apk-share` di `nvda11-gpu`) — pola yang sama
      dengan Leuwi Panjang:
      ```bash
      cp build/app/outputs/flutter-apk/app-release.apk ~/apk-share/readpaper_vX.Y.Z.apk
      ln -sfn readpaper_vX.Y.Z.apk ~/apk-share/readpaper-latest.apk
      ```
      Kartu unduhan ReadPaper sudah ada di `~/apk-share/index.html`.
      Catatan: `ufw` hanya mengizinkan port 8899 dari `10.100.21.0/24`, jadi HP
      harus tersambung WireGuard. Kalau ingin bisa dari WiFi rumah juga:
      `sudo ufw allow from 192.168.11.0/24 to any port 8899 proto tcp`
- [ ] Unduh metadata awal lebih hemat di Android (saat ini ±3.500 permintaan API
      untuk mirror pertama; kuota GitHub 5.000/jam). Ide: tunda `notes/**.md`
      (±1.740 berkas, separuh dari total permintaan) dan ambil satu catatan
      hanya ketika anotasi paper itu ditulis

---

## Fase 5 — Alat tulis di atas halaman

Tujuan: halaman PDF bisa diperlakukan seperti papan tulis, tanpa pernah
merusak berkas aslinya.

- [x] **Gambar bebas (ink)** — mode pena di bilah pembaca, goresan ditangkap
      per halaman, pilihan ketebalan (1–16 pt), pilihan warna, undo per
      goresan, dan buang semua. Satu gambar disimpan sebagai satu anotasi
      `ink` berisi banyak path, sama seperti Zotero. Diuji di perangkat:
      tiga goresan, disimpan, lalu bertahan setelah aplikasi ditutup dan
      dibuka lagi.
      Satu bug format ikut ketahuan dan diperbaiki: `InkPath.toList()` selalu
      menghasilkan `double`, jadi akan menulis `[10.0, 20.0]` — persis
      masalah `72.0` vs `72` yang dulu diperbaiki untuk rects tapi terlewat
      di ink. Sekarang memakai pembulatan yang sama.
- [ ] Penghapus: ketuk satu goresan yang sudah tersimpan untuk membuangnya
      (sekarang penghapusan hanya lewat panel anotasi).
- [ ] **Kotak teks di atas halaman** (add text): teks bebas yang ditempel pada
      koordinat halaman, ukuran & warna font bisa diatur. Zotero punya tipe
      anotasi `text`; yang sekarang dipakai ReadPaper untuk catatan lepas, jadi
      formatnya sudah kompatibel.
- [ ] **Simpan sebagai PDF baru** — halaman + coretan dirender ke berkas baru
      lewat `FPDFPage_CreateAnnot` / `FPDFAnnot_AddInkStroke` / `encodePdf`,
      berkas asli tidak disentuh.
- [ ] **Resave** ke berkas yang sama, dengan salinan `.orig.pdf` disimpan lebih dulu.
- [x] **Ekspor halaman sebagai PNG / JPG**, lengkap dengan stabilo, garis
      bawah, dan coretan — digambar dengan painter yang sama seperti di layar,
      supaya tidak pernah menyimpang darinya. Bisa halaman yang sedang dibuka
      atau seluruh dokumen, pada 72 / 144 / 288 dpi. Disimpan lewat dialog
      sistem, jadi di Android tidak perlu izin penyimpanan sama sekali.
      Diuji di perangkat: PNG 1190x1684 berisi teks, stabilo, dan gambar ink.
- [ ] Ekspor hanya area yang dipilih (sekarang selalu satu halaman penuh).
- [ ] **Ekspor komentar & saran, dan menggabungkannya kembali ke PDF lama**
      sehingga bisa dimuat lagi tanpa kehilangan apa pun. Formatnya tiga lapis
      — anotasi PDF sungguhan, lampiran JSON di dalam berkas, dan halaman
      lampiran "Catatan" di belakang. Lengkapnya di
      [anotasi-ekspor-pdf.md](anotasi-ekspor-pdf.md), termasuk kenapa halaman
      belakang dipilih daripada catatan kaki.
- [ ] Stylus: bedakan jari dan pena (`PointerDeviceKind.stylus`), tekanan jadi
      ketebalan goresan, telapak tangan diabaikan.

---

## Fase 6 — Kenyamanan membaca

- [ ] **Zoom in / zoom out eksplisit** dengan tombol dan pintasan, plus
      "sesuaikan lebar" dan "sesuaikan halaman". (Tombol pembesaran sudah ada di
      bilah; yang belum adalah tingkat zoom yang terbaca dan tersimpan per paper.)
- [ ] **Lompat langsung ke halaman**: kotak isian nomor halaman, penggeser
      halaman, dan panel thumbnail.
- [ ] **Daftar isi PDF** (outline/bookmark bawaan berkas) sebagai panel navigasi.
- [ ] **Reading mode**: sembunyikan semua panel, gulir menerus, tema terang /
      sepia / gelap, kunci orientasi, layar tetap menyala.
- [ ] **Baca nyaring (read aloud / TTS)**
      - Dwibahasa sejak awal: Inggris dan Indonesia, suara dipilih per paper
        mengikuti bahasa item.
      - Ikuti teks yang sedang dibaca dengan sorotan berjalan, bisa jeda,
        lanjut, ganti kecepatan.
      - Lewati catatan kaki, nomor halaman, header/footer, dan daftar pustaka.
      - Mesin: `flutter_tts` (Android TTS / macOS AVSpeech / SAPI di Windows /
        speech-dispatcher di Linux) untuk lapisan dasar; sediakan lapisan
        opsional untuk suara neural (mis. Piper lokal) karena intonasi bawaan
        sistem untuk bahasa Indonesia biasanya datar.
      - **Perlu dicek**: apakah Zotero 7 memang punya fitur baca nyaring bawaan
        dan seperti apa suaranya. Kalau ada, contoh intonasinya dijadikan acuan;
        kalau tidak ada, acuan diambil dari pembaca lain. Jangan diasumsikan.

---

## Fase 7 — Library: riwayat, penataan, dan duplikat

- [ ] **Recent sebagai layar pembuka**: begitu aplikasi dibuka, yang tampil
      adalah paper yang terakhir dibuka/dibaca, bukan daftar kosong.
- [ ] **Riwayat baca** yang bisa diakses dari mana saja (dari daftar koleksi
      maupun setelah selesai membaca): kapan dibuka, halaman terakhir, berapa
      lama dibaca, anotasi yang dibuat di sesi itu.
- [ ] Lanjutkan di halaman terakhir saat paper dibuka lagi.
- [ ] **Pindahkan dokumen antar koleksi** (seret-lepas dan menu), termasuk
      menyalin ke koleksi lain tanpa memindahkan — Zotero mengizinkan satu item
      berada di banyak koleksi.
- [ ] **Deteksi duplikat**: cocokkan DOI, lalu ISBN, lalu judul+tahun+pengarang
      yang dinormalkan; tampilkan berdampingan dan tawarkan penggabungan yang
      mempertahankan anotasi dari kedua salinan.
- [ ] Pencarian referensi berdasarkan **judul, pengarang, dan abstrak**
      (lihat juga Fase 2 — ini perluasannya ke abstrak dan ke isi catatan).

---

## Fase 8 — Dwibahasa (i18n)

- [ ] Antarmuka dalam **Bahasa Indonesia dan Inggris**, bisa diganti di
      pengaturan dan mengikuti bahasa sistem secara bawaan.
- [ ] Pindahkan semua teks yang sekarang ditulis langsung di kode ke ARB
      (`flutter_localizations` + `gen_l10n`).
- [ ] Format tanggal, angka, dan jumlah mengikuti locale.
- [ ] Bahasa antarmuka terpisah dari bahasa isi: TTS, pemeriksa AI, dan
      humanizer memakai bahasa dokumen, bukan bahasa menu.

---

## Fase 9 — Bibliografi & ekspor sitasi

- [ ] **Gaya sitasi berbasis CSL** (Citation Style Language) — jangan menulis
      setiap gaya dengan tangan. CSL adalah format yang dipakai Zotero sendiri,
      dan repositori gayanya berisi ribuan gaya siap pakai, termasuk:
      - **Vancouver** (ada beberapa varian: Vancouver, Vancouver superscript,
        dan turunan penerbit — perlu ditentukan mana yang dipakai)
      - **IEEE** (teknik)
      - **Harvard** (beberapa varian institusi) dan gaya humaniora lain
        (APA, MLA, Chicago)
      - Gaya kesehatan nasional Indonesia — **pakai gaya CSL yang sudah ada**
        di repositori (diputuskan 2026-09-25). Tugasnya memilih yang paling
        dekat dan mengujinya, bukan menulis gaya baru.
- [ ] Mesin sitasi: pakai `citeproc` (port Dart) atau jalankan `citeproc-js`
      di dalam sandbox JS yang sama dengan sistem plugin (Fase 11).
- [ ] **Ekspor**: BibTeX (`.bib`), BibLaTeX, RIS, CSL-JSON, EndNote XML.
- [ ] Salin sitasi / daftar pustaka ke papan klip dalam bentuk teks biasa,
      HTML, dan RTF (RTF diperlukan agar tempel ke Word mempertahankan format).
- [ ] Bibliografi per koleksi, per pilihan item, atau per hasil pencarian.
- [ ] Lokalisasi bibliografi (istilah "dkk." / "et al.", "dalam" / "in")
      mengikuti Fase 8.

---

## Fase 10 — Sitasi langsung di editor dokumen

Tujuan: menulis di Word/LibreOffice/OnlyOffice/Google Docs, menekan satu
tombol, mencari referensi di library ReadPaper, dan sitasi beserta daftar
pustakanya masuk ke dokumen — dengan ReadPaper berjalan sebagai sumbernya.

### 10.1 Fondasi: ReadPaper sebagai server lokal
- [ ] API lokal di `127.0.0.1` (HTTP + WebSocket) yang hanya hidup selama
      ReadPaper berjalan, dilindungi token yang dibuat per pemasangan.
- [ ] Endpoint: cari (judul / pengarang / abstrak), ambil metadata CSL-JSON,
      ambil anotasi & bookmark sebuah item, render sitasi & daftar pustaka
      untuk gaya tertentu.
- [ ] Protokol dokumen: sisipkan sitasi, perbarui semua sitasi, bangun ulang
      daftar pustaka, konversi ke teks biasa. (Bentuknya mengikuti pola yang
      sudah terbukti di Zotero: field/bookmark tersembunyi di dokumen yang
      menyimpan identitas sitasi, bukan sekadar teks.)

### 10.2 Alur memilih apa yang disitasi
- [ ] Pencarian di dalam dialog sitasi: **nama pengarang, judul, abstrak**.
- [ ] **Pilih beberapa referensi sekaligus** untuk satu sitasi
      (mis. `[1], [3]–[5]`).
- [ ] **Tandai bagian mana yang disitasi**: nomor halaman, rentang halaman,
      atau **pilih dari anotasi yang sudah ada** — stabilo berwarna, garis
      bawah, dan catatan yang sudah dibuat di pembaca berlaku sebagai bookmark
      yang bisa dipilih, lengkap dengan kutipan teksnya.
- [ ] Prefiks/sufiks sitasi ("lihat", "bdk.", "hlm. 12–14") dan opsi
      menyembunyikan pengarang untuk sitasi naratif.
- [ ] **Atur mana yang masuk daftar pustaka**: sitasi bisa ditandai "jangan
      masukkan ke daftar pustaka", dan referensi bisa ditambahkan ke daftar
      pustaka tanpa pernah disitasi di badan teks.
- [ ] Bangun **daftar isi / daftar referensi** di posisi yang ditentukan
      penulis, dan perbarui otomatis saat sitasi berubah.

### 10.3 Penyambung per editor
- [ ] **LibreOffice / OpenOffice**: ekstensi UNO (`.oxt`) dengan menu dan
      toolbar sendiri, berbicara ke API lokal ReadPaper.
- [ ] **Microsoft Word**: add-in Office.js — satu basis kode untuk **Word 365
      web dan Word desktop** (Windows & macOS). Perlu manifest add-in dan,
      untuk distribusi di luar toko, sideload lewat berbagi folder/registry.
- [ ] **OnlyOffice**: plugin JavaScript sesuai API plugin OnlyOffice.
- [ ] **Google Docs**: lewat Google Docs API resmi dengan OAuth PKCE dan scope
      `drive.file`, bukan ekstensi peramban. Alasan dan langkah lengkapnya —
      termasuk cara mendapatkan kredensialnya — ada di
      [google-docs-api.md](google-docs-api.md); keputusannya KT-3 di
      [keputusan-teknis.md](keputusan-teknis.md).
- [ ] Uji lintas editor: satu dokumen yang sama disitasi dari dua editor
      berbeda harus tetap bisa diperbarui.

### 10.4 Aplikasi desktop

Antarmuka tetap Flutter, intinya dipindah ke Rust lewat `flutter_rust_bridge`
— lihat KT-1 di [keputusan-teknis.md](keputusan-teknis.md) untuk kenapa
menulis ulang antarmukanya dengan Rust justru merugikan.
- [ ] **Linux**: x86_64 dan arm64 (AppImage / .deb / Flatpak).
- [ ] **Windows**: x86_64; arm64 **perlu dicek** dukungan Flutter-nya saat
      dikerjakan.
- [ ] **macOS**: Apple Silicon (arm64); sediakan universal binary bila
      memungkinkan. Perlu penandatanganan dan notarisasi Apple.
- [ ] Aplikasi berjalan di latar (tray/menu bar) supaya API lokal tetap hidup
      selama menulis.
- [ ] Pembaruan otomatis untuk build desktop.

---

## Fase 11 — Sistem plugin

Tujuan: orang lain bisa menambah kemampuan ReadPaper tanpa mengubah kode
intinya — menambah tombol, menu, halaman pengaturan, dan fungsi baru.

### 11.1 Prasyarat
- [ ] **Bilah menu aplikasi** yang sekarang belum ada: **File, Edit, View,
      Tools, Plugins, Help**. Di desktop jadi menu bar sungguhan, di Android
      jadi laci/overflow dengan pengelompokan yang sama.
- [ ] Sistem *command*: setiap aksi inti diberi id dan bisa dipanggil dari
      menu, pintasan papan tik, atau plugin.

### 11.2 Bentuk plugin
- [ ] **Manifest `plugin.json`**: id, nama, versi, penulis, `minAppVersion`,
      ikon, daftar izin, titik masuk, dan bagian `contributes` yang bersifat
      deklaratif (menu, tombol, panel, halaman pengaturan) sehingga menambah
      UI tidak perlu menulis kode sama sekali.
- [ ] **Titik perluasan**:
      - tombol di bilah pembaca dan bilah ruang kerja
      - item menu di File/Edit/View/Tools/Plugins/Help
      - menu konteks pada teks yang dipilih dan pada anotasi
      - panel samping sendiri di pembaca dan di library
      - halaman pengaturan sendiri (form dideklarasikan di manifest)
      - kait peristiwa: `onItemOpen`, `onAnnotationCreated`, `onSync`,
        `onLibraryLoaded`
      - **API saran (suggestion)**: plugin menempelkan kartu saran pada
        rentang teks tertentu — inilah yang dipakai AI Detector dan Humanizer
        di Fase 12, dan yang membuat keduanya bisa ditulis orang lain juga.
- [ ] **Runtime: WebAssembly**, dijalankan lewat inti Rust (`wasm_run` →
      `wasmtime`, dengan `wasmi` sebagai cadangan di platform tanpa JIT).
      Plugin boleh ditulis dengan bahasa apa pun yang bisa dikompilasi ke WASM.
      Kode Dart tidak bisa dimuat saat aplikasi berjalan pada build AOT, jadi
      plugin berbentuk Dart memang tidak mungkin. Rinciannya KT-2 di
      [keputusan-teknis.md](keputusan-teknis.md) — **keputusan ini yang paling
      sulit dibatalkan**, karena begitu orang menulis plugin formatnya tidak
      bisa diganti.
- [ ] **Izin**: akses jaringan, baca/tulis library, baca berkas lampiran,
      papan klip — dideklarasikan di manifest dan diminta ke pengguna saat
      pemasangan.
- [ ] **Distribusi**: pasang dari berkas `.zip` atau dari URL; daftar plugin
      resmi berupa repositori git; pemeriksaan tanda tangan; pembaruan dan
      penonaktifan per plugin.
- [ ] **Dokumentasi & contoh**: satu plugin contoh yang bisa disalin, dan
      dokumen spesifikasi API yang diversikan.
- [ ] Mode pengembang: muat plugin dari folder, muat ulang tanpa menutup
      aplikasi, konsol log per plugin.

---

## Fase 12 — Plugin bawaan: AI Detector & Humanizer

Dua plugin pertama yang kita tulis sendiri, sekaligus jadi bukti bahwa API
Fase 11 cukup untuk dipakai orang lain.

### 12.1 Model interaksi
Meniru **model kartu saran** seperti yang dipakai Grammarly — yang ditiru
adalah cara berinteraksinya, yang bisa diamati langsung dari produknya, bukan
cara kerja dalamnya. **Catatan jujur: Grammarly tidak menerbitkan detail teknis
mesin deteksi maupun penulisan ulangnya**, jadi tidak ada spesifikasi resmi
yang bisa diikuti; yang bisa dicontoh hanya tata letak dan alur kerjanya.

- [ ] Panel saran di samping teks; setiap saran satu kartu berisi alasan,
      kutipan bagian yang disorot, dan usulan penggantinya.
- [ ] Menyorot kartu akan menyorot bagian teksnya, dan sebaliknya.
- [ ] **Terapkan satu per satu**, **pilih sebagian lewat kotak centang**, atau
      **Terapkan semua** sekaligus.
- [ ] Tolak saran (dan jangan tawarkan lagi untuk teks yang sama).
- [ ] Urungkan setelah diterapkan, termasuk setelah "terapkan semua".
- [ ] Pratinjau perbedaan sebelum-sesudah untuk setiap saran.

### 12.2 AI Detector
- [ ] **Dwibahasa sejak awal: Inggris dan Indonesia.**
- [ ] Riset paper dan rencana teknisnya sudah ditulis di
      [deteksi-ai.md](deteksi-ai.md): kandidat terkuat adalah pendekatan
      stylometri ringan (CNN ~25 MB, akurasi 97% pada korpus penulisnya) yang
      muat di dalam aplikasi; untuk bahasa Indonesia datanya harus dibuat
      sendiri. **Dua fitur ini saling melawan** — humanizer menjatuhkan
      akurasi pendeteksi sampai belasan persen, dan itu harus dikatakan di
      dalam aplikasi.
- [ ] Skor per paragraf, bukan satu vonis untuk seluruh dokumen.
- [ ] Wajib menampilkan tingkat keyakinan dan peringatannya: pendeteksi teks AI
      sering salah, terutama pada tulisan teknis dan pada penulis yang bahasa
      Inggrisnya bukan bahasa ibu. Hasilnya disajikan sebagai bahan
      pertimbangan, bukan tuduhan.
- [ ] Sumber teks: catatan, komentar, dan abstrak di dalam library; untuk PDF,
      teks hasil ekstraksi per halaman (lihat batasan di 12.4).

### 12.3 Humanizer
- [ ] **Dwibahasa sejak awal: Inggris dan Indonesia.**
- [ ] Usulan penulisan ulang per kalimat/paragraf, dengan pilihan nada
      (akademis, ringkas, lugas).
- [ ] Menjaga istilah teknis, kutipan, angka, dan sitasi agar tidak ikut
      diubah.
- [ ] Untuk bahasa Indonesia: perhatikan ragam baku vs. percakapan, dan
      jangan mengubah istilah serapan yang memang dipakai di bidangnya.

### 12.4 Batasan yang harus dipahami sejak awal
- [ ] **Teks di dalam PDF tidak bisa diubah begitu saja.** "Terapkan" hanya
      masuk akal untuk teks yang memang milik kita: catatan, komentar, abstrak,
      dan — nanti — dokumen di editor lewat Fase 10. Untuk badan PDF, hasilnya
      berupa usulan yang bisa disalin atau disimpan sebagai catatan, bukan
      penggantian di halaman.
- [ ] **Mesin model**: bisa lokal (Ollama / llama.cpp) atau lewat API.
      Halaman pengaturan plugin menyediakan pilihan penyedia, model, dan kunci
      API. Bahasa Indonesia perlu diuji terpisah — kualitas model untuk bahasa
      Indonesia jauh lebih beragam daripada untuk bahasa Inggris.
- [ ] **Privasi**: kalau teks dikirim ke layanan luar, katakan dengan jelas
      sebelum dikirim, dan sediakan mode yang sepenuhnya lokal.

---

## Lisensi & tata kelola

- [x] **AGPL-3.0-or-later** dipasang sebagai lisensi (`LICENSE`). Dipilih karena
      permintaannya jelas: boleh dipakai siapa saja, boleh dijual, tapi tidak
      boleh ditutup. AGPL menutup celah yang tidak ditutup GPL biasa — kalau
      seseorang menjalankan versi modifikasinya sebagai layanan jaringan, ia
      tetap wajib menyediakan sumbernya. Itu relevan justru karena ReadPaper
      berencana punya API lokal (Fase 10) dan kemungkinan app service untuk
      pemeriksa AI (Fase 12).
- [x] Notis lisensi tampil di layar Profil, bukan hanya di berkas.
- [x] `CONTRIBUTING.md`, templat issue dan pull request, CI, dan
      `scripts/setup-github-project.sh`.
- [x] **DCO** (`git commit -s`), bukan CLA — supaya tidak ada hak yang
      diserahkan ke siapa pun dan hambatan kontribusi tetap rendah.
- [x] **Lisensi API/SDK plugin**: AGPL-3.0, sama dengan intinya (diputuskan
      2026-09-25). Konsekuensinya disadari — plugin pihak ketiga ikut wajib
      AGPL dan itu menekan jumlah penulis plugin — tapi syaratnya memang apa
      pun yang dibangun di atas ReadPaper tetap terbuka, termasuk kalau dijual.
- [ ] Konsekuensi yang perlu diketahui: syarat App Store Apple selama ini
      dianggap bertabrakan dengan (A)GPL, jadi versi iOS tidak bisa
      didistribusikan di sana. Android, desktop, dan unduhan langsung tidak
      terpengaruh.
- [ ] Berkas `NOTICE` berisi daftar lisensi dependensi (saat ini semuanya MIT
      atau BSD-3-Clause, cocok dengan AGPL-3.0).

---

## Lintas fase — utang teknis

- [x] Uji unit parser Zotero + penulis anotasi (round-trip JSON byte-for-byte)
- [x] Uji unit backend GitHub API (clone, status, commit, push, pull, lampiran)
- [x] Uji unit pengurai progres git
- [x] Pemeriksaan kesetiaan catatan: blok anotasi hasil render dibandingkan
      dengan tulisan plugin pada seluruh library asli
- [ ] Uji widget untuk pohon koleksi dan alur anotasi
- [ ] Cache indeks library di disk + invalidasi berdasarkan mtime
- [ ] Penanganan berkas item rusak yang lebih informatif (saat ini dilewati diam-diam)
- [ ] Dukungan repositori tanpa `.zotero-sync/manifest.json` sudah ada, tapi belum diuji luas
- [ ] Lokalisasi (saat ini antarmuka berbahasa Indonesia saja) — dikerjakan di Fase 8
