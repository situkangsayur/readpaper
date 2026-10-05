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
- [x] **Abstrak, penerbit, dan nama koleksi ikut dicari** oleh kata biasa.
      Pencocokannya ditulis sebagai penelusuran bidang satu per satu yang
      berhenti di kecocokan pertama, bukan satu string gabungan: pada library
      1.740 item dengan abstrak, membangun string itu ulang tiap ketikan
      adalah seluruh ongkos pencarian.
- [x] **Pencarian khusus pengarang**: panel berisi seluruh pengarang dengan
      jumlah karyanya, bisa disaring dan diurutkan A–Z atau terbanyak;
      mengetuk nama mengisi kotak cari dengan `pengarang:"Nama"`. Ini
      menjawab pertanyaan yang tidak bisa dijawab kotak cari — nama harus
      sudah diketahui sebelum bisa diketik.
- [x] **Filter gabungan** lewat operator yang bisa digabung bebas, mis.
      `pengarang:hendri tahun:2024 -tag:draf`.
- [ ] Halaman "profil pengarang": semua karya, koleksi tempat ia muncul, rentang tahun
- [x] **Pencarian lanjutan dengan operator**: `pengarang:`, `judul:`,
      `tahun:`, `tag:`, `jenis:`, `jurnal:`, `doi:`, `abstrak:`, `koleksi:` —
      nama bidang diterima dalam dua bahasa, karena nama bidang diketik dari
      ingatan dan tidak seharusnya orang menghafal bahasa mana yang dipilih
      aplikasi ini. Frasa dikutip dengan tanda kutip, `-` mengecualikan, dan
      prefiks yang belum ada isinya diabaikan supaya daftar tidak berkedip
      kosong setiap kali titik dua diketik. Ada dialog bantuan di kotak cari,
      karena tidak ada apa pun di layar yang memberi tahu operator ini ada.
      15 tes.
- [ ] Pengayaan metadata dari DOI (Crossref / OpenAlex) untuk item yang datanya kosong
- [ ] Ekstraksi metadata dari isi PDF ketika item tidak punya metadata sama sekali
- [ ] Ekspor sitasi per item atau per koleksi — dipindahkan ke Fase 9
- [x] **Statistik library** (2026-09-30): jumlah per tahun, per jenis,
      pengarang tersering, dan tag tersering, beserta angka yang paling sering
      mengejutkan — berapa persen item yang berkasnya benar-benar ada.
      Library yang separuhnya tanpa berkas adalah daftar bacaan, bukan
      perpustakaan, jadi angka itu memerah di bawah 50%. Item tanpa tahun dan
      tanpa judul dihitung terpisah alih-alih dipaksa masuk kelompok mana pun:
      keduanya biasanya sisa impor yang gagal, dan menyembunyikannya berarti
      tidak pernah diperbaiki. Batangnya digambar dari `FractionallySizedBox`,
      bukan dari pustaka grafik — yang dibutuhkan hanya perbandingan panjang.

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
- [~] **Rilis GitHub**: tag sudah ada sampai v0.2.2, tapi halaman Releases
      masih berhenti di v0.1.2 — `git push --tags` hanya membuat tag, Release
      adalah objek terpisah. `scripts/publish-releases.sh` menyusulnya sekali
      jalan dan aman diulang.
      Tertahan pada kredensial: butuh `gh auth login --scopes public_repo`
      (bukan `repo` penuh, dan **bukan** `project` — dua-duanya menyeret izin
      organisasi yang tidak diperlukan), atau `GH_TOKEN` berisi fine-grained
      token yang dibatasi ke repositori ini dengan izin *Contents: read and
      write*. Fine-grained token adalah yang paling sempit.
- [ ] Papan GitHub Project: dibuat dari web, bukan dari CLI — scope `project`
      itu tingkat organisasi dan tidak sepadan untuk sebuah papan. Labelnya
      tetap bisa dibuat `scripts/setup-github-project.sh`.
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
- [~] **Simpan sebagai PDF baru** — sudah ada, tapi *rata*: halaman dirender
      beserta anotasinya lalu ditaruh sebagai gambar di dalam PDF baru, dengan
      ukuran halaman asli dipertahankan. Berkas asli tidak disentuh sama
      sekali (hanya dibaca). Penulisnya ditulis sendiri (~130 baris,
      `simple_pdf_writer.dart`) karena yang dibutuhkan cuma satu XObject
      gambar per halaman; JPEG-nya disisipkan apa adanya sebagai `DCTDecode`.
      Diuji: `pdfinfo` membacanya PDF 1.4 A4 yang sah, poppler merendernya
      lengkap dengan stabilo dan ink.
      **Yang belum**: lapisan teksnya hilang, jadi salinan itu tidak bisa
      dicari atau disalin. Versi yang mempertahankan teks harus menulis
      anotasi PDF sungguhan lewat `FPDFPage_CreateAnnot` /
      `FPDFAnnot_AddInkStroke` / `FPDF_SaveAsCopy`.
- [ ] **Bahaya yang menghalangi ekspor PDF yang mempertahankan teks**: PDFium
      bukan thread-safe dan pdfrx menjalankannya di isolate-nya sendiri, jadi
      menulis anotasi dari isolate lain bisa merusak proses — bukan sekadar
      melempar eksepsi. Perlu diputuskan lebih dulu: memakai handle dan worker
      milik pdfrx (tidak dipublikasikan), atau menulis *incremental update*
      PDF sendiri di Dart murni — yang justru punya sifat bagus: berkas asli
      tetap menjadi awalan byte-for-byte dari berkas baru.
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
- [x] **Lompat langsung ke halaman**: nomor halaman di bilah atas sekarang
      bisa diketuk — di situlah mata mencari ketika ingin pindah halaman —
      membuka kotak isian nomor dan penggeser halaman. Nomor di luar
      jangkauan ditolak dengan menyebut jangkauannya, bukan dikosongkan
      diam-diam.
- [ ] Panel thumbnail halaman (belum).
- [x] **Daftar isi PDF** (outline bawaan berkas) di sheet yang sama, bertingkat
      dan menjorok sesuai kedalaman, mengetuk judul melompat ke *destination*
      aslinya — bukan sekadar ke awal halaman, jadi posisinya tepat. Judul
      tanpa tujuan tidak bisa diketuk.
      Diuji lewat widget test dengan outline buatan (6 tes, termasuk
      pemeriksaan bahwa anak benar-benar menjorok lebih dalam). **Belum diuji
      di perangkat dengan PDF yang benar-benar punya daftar isi** — berkas uji
      di ponsel hanya satu halaman tanpa outline.
- [x] **Reading mode**: bilah atas, petunjuk, dan panel anotasi disembunyikan,
      bilah sistem masuk mode imersif, dan tiga tombol bulat mengambang di atas
      halaman untuk warna, lompat halaman, dan keluar. Masuk mode baca
      mematikan mode penanda, catatan, dan pena — mode yang menggambar di
      halaman sambil menyembunyikan alat untuk membatalkannya adalah jebakan.
- [x] **Warna halaman**: Normal, Sepia, Redup, Balik warna — dipasang sebagai
      color filter di atas halaman, jadi dokumennya sendiri tidak diubah.
      Catatan: pada Balik warna, penanda ikut jadi warna komplemennya (kuning
      terbaca biru); itu konsekuensi membalik seluruh halaman, dikatakan di
      snackbar-nya, dan karena itu bukan mode bawaan.
- [ ] Gulir menerus dan kunci orientasi (belum).
- [x] **Layar tetap menyala saat membaca** — keping lampu di bilah atas
      menyalakannya, dan `dispose` mematikannya lagi supaya tidak ada layar
      yang menyala terus setelah pembacanya ditutup.
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

- [x] **Recent**: kartu "Terakhir dibaca" di atas daftar item, berisi judul,
      pengarang, tahun, halaman terakhir, dan berapa lama lalu. Disembunyikan
      saat sedang mencari — layar yang ditanyai sesuatu sebaiknya menjawabnya.
      Riwayat dari library lain tidak ditampilkan: klonanya mungkin tidak ada
      di disk, dan menawarkan paper yang tidak bisa dibuka lebih buruk
      daripada tidak menawarkannya.
- [~] **Riwayat baca**: kapan dibuka dan halaman terakhir sudah dicatat
      (maksimal 40 entri, karena ini tinggal di `config.json` yang dibaca tiap
      aplikasi dijalankan). Belum: berapa lama dibaca dan anotasi per sesi.
- [x] **Lanjutkan di halaman terakhir** saat paper dibuka lagi, dengan
      pemberitahuan halaman berapa. Penulisan riwayat ditunda 1,5 detik supaya
      membolak-balik dua puluh halaman menulis sekali, bukan dua puluh kali —
      dan `dispose` menuliskan yang tertunda, supaya keluar cepat tidak
      membuang halaman terakhirnya.
- [ ] **Pindahkan dokumen antar koleksi** (seret-lepas dan menu), termasuk
      menyalin ke koleksi lain tanpa memindahkan — Zotero mengizinkan satu item
      berada di banyak koleksi.
- [~] **Deteksi duplikat** (2026-09-30). Pencocokannya bertingkat dari yang
      pasti ke yang menduga: DOI, lalu ISBN, lalu judul + tahun + nama belakang
      pengarang pertama — ketiganya dinormalkan, dan ISBN-10 diubah ke ISBN-13
      supaya satu buku yang sama tidak tampak berbeda hanya karena dua salinan
      mencatatnya dengan panjang yang berbeda. Kecocokan lewat jalan mana pun
      menyatukan kelompok yang sama (union-find), jadi tiga salinan yang
      bertaut A–B lewat DOI dan B–C lewat judul tetap jadi satu.

      Diuji pada library sungguhan: **1.741 item → 147 kelompok, 384 salinan,
      dalam 65 milidetik**; satu paper masuk tujuh kali. Nol kelompok punya
      anotasi di lebih dari satu salinan, jadi tidak ada pekerjaan yang
      berisiko hilang.

      **Penggabungannya sengaja belum ada.** Menggabungkan berarti salah satu
      item hilang, dan library Zotero adalah pekerjaan bertahun-tahun yang
      dijaga byte-for-byte oleh plugin sinkronisasi. Layarnya menunjukkan
      kelompoknya berdampingan beserta alasannya, menandai salinan yang paling
      pantas dipertahankan, dan memperingatkan kalau anotasinya tersebar —
      lalu berhenti di situ, dan mengatakannya di layar.
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

### Dua aturan yang mengikat seluruh rancangan

Keduanya datang dari memakai Zotero dan Mendeley bertahun-tahun, bukan dari
membaca dokumentasinya (dicatat 2026-09-30):

1. **Daftar pustaka diturunkan dari dokumen, tidak pernah ditimbun.**
   Keluhannya persis: "ketika sitasi dikurangi atau sitasi satu reference
   sudah tidak ada, di daftar reference masih ada". Itu kelas bug yang lahir
   dari menyimpan daftar "item yang disitasi" di samping dokumen, lalu
   berharap daftar itu tetap sejalan dengan isi dokumen. Ia tidak akan pernah
   tetap sejalan — penulis menghapus paragraf, membatalkan perubahan, menempel
   dari dokumen lain.

   Jadi ReadPaper tidak boleh punya daftar seperti itu sama sekali. Setiap
   kali daftar pustaka dibangun, dokumennya **dipindai** dari awal, medan
   sitasinya dikumpulkan, dan daftar pustakanya dibuat **hanya** dari yang
   benar-benar ditemukan. Item yang sitasinya sudah tidak ada tidak bisa
   tertinggal, karena tidak ada tempat untuk tertinggal. Satu-satunya
   pengecualian adalah item yang sengaja ditandai "masuk daftar pustaka tanpa
   disitasi", dan penandanya pun disimpan **di dalam dokumen**, bukan di luar.

2. **Menyisipkan sitasi harus terasa ringan.** "Cara Zotero insert citasi
   masih agak berat, tapi lebih ringan dibanding Mendeley." Ukurannya bukan
   selera: dialognya harus muncul dan siap diketik dalam sepersekian detik,
   pencariannya berjalan sambil mengetik tanpa menunggu, dan menyisipkan satu
   sitasi tidak boleh menunggu seluruh dokumen dibangun ulang. Pembangunan
   ulang daftar pustaka — yang memang memindai seluruh dokumen — adalah
   perintah tersendiri, bukan ekor dari setiap penyisipan.

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

## Fase 13 — PDF lepas: buka, isi, tanda tangani, bagikan

Diminta sebagai prioritas tinggi. Menandai PDF yang dikirim orang, mengisi
formulir, dan menandatanganinya adalah pekerjaan yang sama dengan membaca
paper — tidak ada alasan itu jadi aplikasi lain.

- [x] **Buka PDF apa pun** dari perangkat, lewat tombol di daftar paper.
      Anotasinya ditahan di memori karena tidak ada item Zotero untuk
      ditulisi; selebihnya pembacanya sama persis
- [x] **Isi teks di halaman** (tombol Tt) — untuk mengisi formulir PDF yang
      tidak punya field sendiri. Kotaknya mengikuti panjang teks supaya
      jawaban panjang tidak terpotong
- [x] **Papan tanda tangan**: ditulis besar di lembar bersih lalu diperkecil
      ke tempatnya. Menandatangani langsung di halaman pada skala aslinya
      menghasilkan coretan gemetar, dan salah sedikit berarti mengurungkan
      di atas dokumen
- [x] **Simpan PDF** dan **Simpan sebagai…** (PDF, PNG, JPG)
- [x] **Bagikan** ke chat, surel, atau aplikasi lain
- [x] **Tambahkan ke koleksi tertentu supaya ikut sync GitHub** (2026-09-28).
      Item Zotero baru ditulis lengkap dengan lampirannya dan catatan
      pendampingnya, dalam format yang sama persis dengan tulisan plugin.
      Ujinya membaca kembali hasilnya lewat parser aplikasi sendiri — kalau
      bentuknya meleset sedikit saja, di situ ketahuannya — lalu dibuktikan
      pada library sungguhan di tablet: itemnya muncul di koleksi yang
      dipilih dan commit-nya terbentuk. `collections.json` ternyata tidak
      perlu disunting: keanggotaan koleksi disimpan di dalam berkas itemnya
- [ ] Sunting kembali teks yang sudah ditaruh (sekarang harus dihapus lalu
      dibuat ulang)
- [ ] Simpan tanda tangan supaya tidak perlu digambar ulang tiap kali

### Batasan Android yang ditemukan saat menguji

- [x] **"Simpan ke berkas ini" mustahil di Android.** Pemilih berkas Android
      menyerahkan **salinan di cache aplikasi**, bukan berkas yang dipilih;
      menimpanya terlihat berhasil dan tidak mengubah apa pun yang bisa
      dilihat pengguna. Karena itu di Android penyimpanan selalu lewat dialog
      sistem, dan menu pun berbunyi "Simpan PDF — pilih tempatnya sendiri".
      Di desktop, menulis di tempat tetap dilakukan dengan menyalin yang asli
      lebih dulu

### Bug lama yang ikut ketahuan

- [x] **Dialog komentar/catatan rusak sejak lama dan merender kotak abu-abu
      kosong.** Penyebabnya `const Spacer()` di dalam `AlertDialog.actions`,
      yang dirender `OverflowBar` dan tidak menerima `Expanded` — melempar
      eksepsi pada setiap build. Artinya "Stabilo + komentar", catatan, dan
      penyuntingan anotasi **tidak pernah benar-benar bisa dipakai**.
      Sekarang ada empat widget test yang menjaganya, termasuk satu yang
      memastikan tombol Simpan masih bisa diketuk pada layar pendek —
      keadaan yang terjadi persis ketika papan tik naik.


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

## Fase 14 — Papan tulis, presentasi, dan berkas lepas

Diminta 2026-09-28, sebagai satu kumpulan. Benang merahnya satu: ReadPaper
selama ini hanya bisa *membaca* apa yang sudah ada di library Zotero. Yang
diminta adalah membuat, mencoret, menyusun, dan menyimpan — tanpa
mengganggu struktur Zotero yang formatnya dijaga ketat.

Ukuran APK dinyatakan bukan halangan ("size tidak masalah jika memang harus
besar"), tetapi yang lebih kecil tetap lebih baik.

### Menyajikan dan mencoret

- [x] **Mode presentasi** (2026-09-28): satu halaman penuh layar, maju-mundur
      dengan ketukan di tepi kiri/kanan atau tombol. Halamannya dipasang
      seluruhnya (`PdfPageAnchor.all`), bukan selebar layar — yang menyajikan
      dilihat dari jauh, dan halaman yang terpotong di bawah adalah kalimat
      yang hilang
- [x] **Coret-coret saat menyajikan** (2026-09-28): pena bisa dinyalakan dari
      dalam mode menyajikan, dan saat aktif ketukan tepi tidak lagi mengganti
      halaman — satu coretan tidak boleh berubah jadi pindah halaman
- [ ] Hapus cepat coretan setelah satu halaman lewat
- [x] **Halaman kosong baru** untuk dicoreti, ditambahkan di akhir dokumen
      (2026-09-28). Halaman aslinya disalin sebagai objek PDF lewat pdfium,
      bukan digambar ulang jadi gambar: teksnya tetap bisa dicari dan
      disalin, dan berkasnya tidak membengkak. Yang tampil sejak itu adalah
      salinan kerja; berkas aslinya tidak disentuh sampai disimpan
- [ ] Menyisipkan di tengah, bukan hanya di akhir — perlu menggeser nomor
      halaman anotasi yang sudah ada

### Papan tulis sebagai jenis berkas sendiri

- [x] **Papan tulis berhalaman** (2026-09-28): lima warna latar, berlembar
      banyak, pena berwarna dengan empat ketebalan, **penghapus per goresan**,
      urungkan, dan kosongkan lembar. Disimpan sebagai **PDF** — satu lembar
      per halaman, ukuran A4 supaya bisa dicetak atau digabung dengan paper
      tanpa berbeda ukuran
- [x] Papan tulis baru dibuat **dari panel berkas**, sebelum ada PDF-nya sama
      sekali. Hasilnya mendarat di folder kerja, langsung terlihat, dan bisa
      diseret ke koleksi seperti berkas lain
- [ ] Ekspor per lembar sebagai gambar (PNG sudah ada di kode, belum ada
      tombolnya)
- [ ] Papan tulis yang sudah disimpan **dibuka dan disunting lagi** — perlu
      format yang menyimpan goresannya, bukan hanya PDF hasilnya (lihat
      Fase 15)

### Panel berkas di samping koleksi

- [x] Panelnya dibagi dua (2026-09-28): **pohon koleksi** di atas,
      **penjelajah berkas** di bawah
- [x] **Seret dan lepas** dari penjelajah berkas ke sebuah koleksi — barisnya
      menyala saat berkas melayang di atasnya, dan melepas di "Semua item"
      berarti masuk library tanpa koleksi. Diuji di tablet: berkas diseret,
      itemnya muncul di koleksi, commit-nya terbentuk
- [x] Di penjelajah berkas: **folder baru**, **masuk/keluar folder**, **buka
      folder kerja lain**, dan **salin berkas ke sini**
- [x] **Koleksi baru langsung dari "Tambahkan ke koleksi"** di pembaca
      (2026-10-04), di akar atau sebagai sub-koleksi. Koleksi tujuan sering
      belum ada — dokumen kuliah hari ini, misalnya — dan sebelumnya harus
      keluar ke pohon koleksi dulu. Lewat penulis `collections.json` yang sama,
      jadi tetap terbaca Zotero
- [ ] Seret **antar koleksi** (memindahkan item yang sudah ada di library)
- [x] **Papan tulis baru** dari panel ini (2026-09-28)
- [x] **Ganti nama** dan **hapus berkas** dari panel ini (2026-09-28)
- [ ] Berkas baru dan proyek baru dari panel ini
- [ ] Batasan yang ditemukan: Android menolak memberikan akses ke folder
      `Download` lewat pemilih **folder** ("Tidak dapat menggunakan folder
      ini"). Karena itu ada tombol **salin berkas ke sini** yang memakai
      pemilih **berkas** — yang tidak dibatasi — dan hasilnya justru lebih
      baik: satu salinan di folder kerja, bukan berkas di tempat yang bisa
      hilang

### Dua jenis akar koleksi

- [x] **Pohon koleksi boleh punya lebih dari satu akar**, dan tiap akar punya
      jenis: **paper** atau **catatan** (2026-09-28). Akar paper memakai nama
      library Zotero-nya, akar catatan bernama "Catatan". Keduanya berbagi satu
      pilihan: memilih koleksi catatan melepas koleksi paper, karena dua
      sorotan sekaligus membuat tidak jelas daftar mana yang sedang tampil
- [x] Catatan disimpan di **direktori terpisah** di dalam repositori, bukan di
      dalam struktur Zotero (2026-09-28) — `catatan/` di akar repositori,
      dengan `koleksi.json`, `item/<XX>/<KEY>.json`, dan
      `berkas/<XX>/<KEY>/<nama>`. Alasannya tegas: item Zotero punya properti
      rujukan dan bibliografi yang tidak berlaku untuk catatan, dan formatnya
      dijaga byte-for-byte oleh plugin `zotero-github-sync`. Zotero sendiri
      tidak mengenal catatan lepas semacam ini — ReadPaper mengenalnya, dan
      itu yang membuatnya berguna. Bentuk JSON-nya tetap meniru yang di
      sebelah (identasi tab, kunci terurut) supaya diff git tetap kecil
- [x] Menyimpan catatan **wajib** ke akar berjenis catatan; menolak dengan
      penjelasan kalau yang dipilih akar paper (2026-09-28). Aturannya satu
      tempat — `NoteTarget` — dan penolakannya menyebutkan sebabnya, bukan
      sekadar berkata tidak bisa. Berlaku di papan tulis ("Simpan sebagai
      catatan") dan saat berkas bukan-PDF dilepas di akar paper
- [x] Panel tengah mengikuti akar yang dipilih: daftar item Zotero untuk paper,
      daftar catatan untuk catatan (2026-09-28). Catatan tidak punya pengarang
      atau tahun, jadi memakai daftar yang sama hanya menghasilkan kolom kosong
- [x] Menghapus koleksi catatan **tidak** menghapus catatannya — isinya pindah
      ke "tanpa koleksi" (2026-09-28)
- [ ] Menyeret catatan antar koleksi langsung di pohon (sekarang lewat menu
      "Pindahkan ke koleksi" di daftar catatan)
- [ ] Membuka catatan Markdown di dalam aplikasi — sekarang hanya PDF; lihat
      bagian Markdown di bawah

### Markdown

- [x] **Baca dan sunting Markdown** (2026-09-28): penyunting dengan tiga mode —
      sunting, pratinjau, dan keduanya berdampingan di layar lebar. Tombol
      sisip untuk tajuk, tebal, miring, daftar, daftar tugas, kutipan, kode,
      tabel, dan diagram. Berkasnya dibaca dan ditulis langsung, jadi tidak
      pernah ada putaran tunggu yang menggantung
- [x] **Mermaid ditampilkan sebagai diagram dan bisa disunting** (2026-09-28).
      Digambar sendiri — tanpa WebView dan tanpa mermaid.js — karena catatan
      harus terbuka di tablet tanpa jaringan. Yang dikenali: `graph` dan
      `flowchart` dengan arah TD/TB/BT/LR/RL, bentuk `[]` `()` `([])` `{}`
      `(())`, garis solid/tebal/putus-putus, panah berlabel, dan komentar.
      **Mengetuk diagramnya di pratinjau membawa kursor ke sumbernya** — itu
      yang membuatnya bisa disunting dan bukan hanya dilihat
- [x] Jenis diagram lain (sequence, gantt, class) ditolak dengan menyebut
      sebabnya dan menampilkan sumbernya apa adanya (2026-09-28) — diagram
      yang salah gambar lebih menyesatkan daripada kode yang terbaca jujur
- [x] **Berkas baru** yang bisa disimpan sebagai **PDF atau Markdown**
      (2026-09-28): "Berkas Markdown baru" di panel berkas, "Catatan Markdown
      baru" di panel catatan, dan "Simpan sebagai PDF" dari dalam penyuntingnya
- [x] **Markdown → PDF** (2026-09-28) dengan **teks sungguhan**, bukan
      tangkapan layar: hasilnya masih bisa dicari dan disalin. Diagram ikut
      tergambar, dan labelnya pun tetap teks. Tata letak diagramnya satu
      perhitungan dengan yang di layar, jadi cetakannya tidak pernah berbeda
      dari pratinjaunya
- [x] Tanda baca yang tidak ada di font bawaan PDF — tanda pisah panjang,
      kutip melengkung, titik-titik, butir bulat — ditukar dengan padanan
      ASCII-nya (2026-09-28). Sebelumnya hilang **tanpa jejak**: kalimat
      bertanda pisah keluar dari cetakan dengan dua kata berdempetan
- [x] **PDF → Markdown** (2026-09-28), dari menu pembaca. Strukturnya ditebak
      dari geometri dengan aturan yang bisa dijelaskan: huruf yang lebih besar
      jadi tajuk, baris berdekatan disambung jadi paragraf, kata terpotong
      tanda hubung disatukan, butir jadi daftar, dan kepala/kaki halaman yang
      berulang dibuang. Hasilnya mendarat di folder kerja aplikasi — **bukan**
      di sebelah papernya, karena berkas asing di dalam ekspor Zotero
      mengacaukan struktur yang dijaga plugin sinkronisasi
- [x] PDF hasil pindaian dikatakan apa adanya: "tidak punya lapisan teks",
      bukan dilaporkan berhasil dengan berkas kosong (2026-09-28)
- [ ] Menyunting Mermaid lewat antarmuka, bukan lewat sumbernya
- [ ] Tabel di PDF → Markdown masih keluar sebagai teks biasa, bukan tabel

### Mengubah tulisan tangan jadi teks

- [ ] **Terjemahkan dokumen tulisan tangan** — PDF hasil pindaian atau tulisan
      tangan diubah jadi dokumen digital: teksnya jadi teks, gambarnya ikut
      diterjemahkan, keluarannya PDF atau Markdown. Ini yang paling berat di
      daftar ini dan pantas jadi tahap sendiri: butuh OCR tulisan tangan yang
      layak, dan keputusan apakah berjalan di perangkat atau lewat layanan
      (bandingkan pertimbangan yang sama di Fase 12)

### Layar dan kenyamanan

- [x] **Layar tetap menyala saat membaca** (2026-09-28), bisa dimatikan.
      Membaca paper berarti menatap satu halaman berpuluh detik tanpa
      menyentuh apa pun, dan layar yang mati di tengah kalimat memutus
      bacaan. Mati secara bawaan: itu memakan baterai, dan pantas jadi
      pilihan yang diambil sendiri

### Cetak dan integrasi sistem

- [x] **Cetak** (2026-09-28) lewat dialog cetak Android, yang juga memuat
      "Simpan sebagai PDF" — jadi yang tidak punya pencetak tetap mendapat
      sesuatu yang berguna. Anotasi yang belum menyatu dengan halaman
      dikatakan dulu, daripada mengejutkan di kertas
- [x] **ReadPaper jadi aplikasi pembuka PDF** (2026-09-28): intent filter
      untuk `VIEW` dan `SEND` dengan `application/pdf`. URI `content://`
      disalin ke cache di sisi Android lebih dulu — izinnya hanya berlaku
      selama Activity-nya hidup, jadi menyerahkan URI-nya apa adanya ke Dart
      akan gagal beberapa detik kemudian. Diuji dengan intent sungguhan:
      ReadPaper muncul di daftar "Buka dengan", dan PDF 32 halaman terbuka
      langsung di pembacanya

### Pena di pembaca

- [ ] **Penghapus** untuk coretan di halaman PDF — sekarang satu-satunya
      jalan adalah mengurungkan goresan terakhir atau membuang semuanya.
      Sama seperti di catatan: per goresan dan sebagian

### Anotasi yang bisa diatur ulang

- [x] Tanda tangan, coretan, dan catatan bisa **dipindah** (2026-09-27)
- [x] ...dan bisa **diubah ukurannya** serta **diputar** (2026-09-28), lewat
      dua pegangan di sudut bawah bingkainya. Keputusannya: titiknya memang
      ditulis ulang, tidak disimpan sebagai sudut di `rawPosition` —
      menyimpan sudut berarti menulis sesuatu yang tidak bisa dibaca Zotero
      lagi, dan itu harga yang tidak sepadan. Ketelitiannya dijaga dengan
      menerapkan seluruh gerakan **sekali** dari anotasi aslinya saat jari
      diangkat, bukan sedikit demi sedikit selama menyeret. Tebal penanya
      ikut diperbesar, karena tanda tangan yang digandakan dengan garis
      setipis semula terlihat seperti gambar yang ditarik
- [x] Hanya berlaku untuk tinta. Stabilo dan garis bawah disimpan Zotero
      sebagai kotak sejajar sumbu; memutarnya menghasilkan berkas yang tidak
      bisa dibaca kembali di sana
- [ ] Warna dan kepekatan anotasi yang sudah ada (lihat Fase 15)

### Urutan yang disarankan

1. Mode presentasi + coret-coret + halaman kosong (paling dekat dengan yang
   sudah ada, dan paling sering dipakai)
2. Panel berkas + seret ke koleksi (membuka jalan untuk sisa daftarnya)
3. Papan tulis berhalaman → PDF/gambar
4. ~~Dua jenis akar koleksi + catatan di direktori terpisah~~ (selesai)
5. ~~Markdown baca/sunting/Mermaid + konversi dua arah~~ (selesai)
6. Cetak + pembuka PDF bawaan
7. Ubah ukuran dan putar anotasi
8. OCR tulisan tangan

---

## Fase 15 — Catatan tulisan tangan yang jadi dokumen hidup

Diminta 2026-09-28. Ini bukan "OCR lalu selesai": yang diminta adalah
menulis dengan stylus berlembar-lembar seperti buku catatan, lalu mengubahnya
menjadi dokumen yang **komponennya masih bisa disentuh satu per satu**.

Bedanya dengan Fase 14 butir OCR: di sana keluarannya dokumen jadi (PDF atau
Markdown). Di sini keluarannya bisa disunting lagi — teks tetap teks,
diagram tetap objek, gambar tetap gambar, dan semuanya bisa digeser tanpa
merusak tata letak aslinya.

### Menulis

- [x] **Kanvas catatan berlembar-lembar** dengan stylus (2026-09-29): tambah
      lembar, berpindah lembar, hapus lembar. Lembarnya berukuran A4 dalam
      titik PDF dan diperkecil utuh ke layar, jadi satu koordinat berlaku di
      ponsel, di tablet, dan di dalam PDF — catatan yang ditulis di layar kecil
      tidak berpindah tempat saat dibuka di layar besar. Ada garis bantu
      polos/bergaris/kotak
- [x] Pena dengan **warna** dan **ketebalan**, dan **urungkan** (2026-09-29)
- [x] **Penghapus**, dua macam (2026-09-29):
      - *per goresan* — sentuh sebuah goresan, goresan itu hilang seluruhnya
      - *sebagian* — menghapus bagian yang dilewati, dan goresan yang dihapus
        di tengahnya benar-benar terbelah jadi dua
      Ukuran penghapusnya bisa diatur, dan hasilnya ikut bisa diurungkan.
      Satu jebakan yang ditemukan dan ditutup: goresan cepat hanya menyimpan
      titik yang berjauhan, dan penghapus yang hanya memeriksa titik akan
      melewatkan goresan yang jelas dilewatinya — ruas yang tersentuh
      dirapatkan dulu, hanya yang tersentuh
- [x] **Satu gerakan pena = satu komponen** (2026-09-29). Itu batas yang jujur
      untuk sekarang: mengelompokkan beberapa goresan jadi satu kata adalah
      pekerjaan pengenalan tulisan, dan menebaknya tanpa itu akan sering salah

### Mengubah jadi komponen

- [ ] **Teks tulisan tangan → teks sungguhan**, di tempat yang sama. Yang
      dijaga bukan hanya isinya, melainkan **posisinya**: tata letak yang
      kacau setelah konversi membuat hasilnya lebih buruk daripada
      tulisannya sendiri
- [ ] **Diagram → objek diagram** yang bisa digeser, bukan gambar mati
- [ ] **Gambar tetap gambar**, ikut pada posisinya
- [ ] Yang tidak dikenali **tetap sebagai tinta**, bukan dibuang. Konversi
      yang menghilangkan coretan adalah konversi yang merusak

### Menyunting hasilnya

Setiap komponen — teks, diagram, gambar, tinta — bisa (semuanya 2026-09-29):

- [x] **digeser** (drag and drop)
- [x] **diubah ukurannya**
- [x] **diputar**, dan sudutnya dibulatkan ke kelipatan 15° saat mendekatinya —
      tulisan yang hampir lurus lebih sering dimaksudkan lurus
- [x] **dihapus**
- [x] diubah **warnanya**
- [x] diubah **kepekatannya** (opacity)
- [x] dan semuanya bisa **diurungkan** — yang disimpan bukan daftar tindakan
      melainkan keadaan dokumennya, jadi tidak ada tindakan yang lupa
      didaftarkan dan membuat urungkan bohong
- [x] Satu gerakan tangan = satu langkah urungkan, bukan satu langkah per
      piksel (2026-09-29)

Catatan teknis yang sudah kelihatan sekarang — dan sudah dipatuhi: memutar dan
mengubah ukuran tidak dikerjakan dengan menulis ulang titik-titik tintanya,
karena memutar dua kali akan kehilangan ketelitian. Sudut, skala, dan
kepekatan disimpan sebagai sifat komponen, dan titiknya tetap seperti saat
ditulis. Ada uji yang menjaganya: memutar lalu menyimpan tidak boleh mengubah
satu pun titik.

### Menyimpan

- [x] **Markdown** (2026-09-29) — urutannya urutan baca, bukan urutan menulis,
      karena catatan ditulis melompat-lompat. Tinta tidak bisa jadi teks, jadi
      digambar ke PNG di sebelah berkasnya dan dirujuk sebagai gambar:
      membuangnya berarti catatannya hilang sebagian
- [x] **PDF** (2026-09-29) — satu lembar jadi satu halaman, tintanya digambar
      sebagai **garis vektor** (tetap tajam diperbesar, berkasnya jauh lebih
      kecil), teksnya tetap teks, diagramnya ikut tergambar
- [x] **Format sendiri yang bisa disunting lagi** (2026-09-29):
      `<nama>.catatan.json`. JSON dan bukan format biner karena catatan ini
      hidup di dalam repositori git — diff-nya terbaca, bisa di-merge, dan
      masih terbuka lima tahun lagi oleh apa pun yang bisa membaca JSON. Kunci
      diurut dan identasinya tab, sama seperti berkas lain di repositori ini.
      Berkas dari versi format yang lebih baru **ditolak dengan jelas**, bukan
      dibaca setengah-setengah lalu disimpan balik dalam keadaan rusak
- [x] Disimpan ke **koleksi catatan** tertentu (2026-09-29), lewat aturan
      `NoteTarget` yang sama dengan papan tulis — akar paper ditolak dengan
      penjelasan

### Yang belum: mengubah tulisan jadi komponen

Bagian "Mengubah jadi komponen" di atas belum dikerjakan sama sekali, dan itu
disengaja: semuanya bergantung pada keputusan di bawah. Yang sudah ada
sekarang adalah **wadahnya** — komponen teks, diagram, gambar, dan tinta yang
semuanya bisa disunting — jadi ketika pengenalannya datang, yang perlu ditulis
hanya bagian yang mengubah tinta jadi komponen lain, bukan seluruh dokumennya.

### Yang perlu diputuskan sebelum dikerjakan

- Pengenalan tulisan tangan berjalan **di perangkat** atau lewat layanan?
  Pertimbangannya sama dengan Fase 12: yang di perangkat menjaga tulisan
  tetap milik penulisnya, yang di layanan jauh lebih akurat. Bahasa
  Indonesia dan Inggris keduanya harus terbaca
- Bagaimana membedakan "ini diagram" dari "ini coretan biasa" tanpa menebak
  terlalu berani. Salah tebak yang mengubah coretan jadi kotak rapi lebih
  menyebalkan daripada tidak mengubah apa-apa

---

## Fase 16 — Menulis yang terasa enak

Diminta 2026-09-29, semuanya dari mencoba yang sudah jadi. Bukan fitur besar
melainkan hal-hal yang membuat alatnya benar-benar dipakai.

### Kertas dan warna

- [x] **Kertas papan tulis bisa tegak dan mendatar** (2026-09-29), per lembar —
      satu papan boleh mencampur, karena satu penjelasan bisa butuh daftar
      tegak dan bagan mendatar sekaligus. Arahnya dipilih saat membuat papan
      dan bisa diputar kapan saja. Memutar kertas **membawa coretannya**:
      memutar kertas tanpa memutar isinya berarti coretan yang tadinya di dalam
      kertas mendadak keluar dari tepi — hilang tanpa pernah dihapus
- [x] **Alternatif warna lebih banyak** (2026-09-29): empat belas warna
      bernama, satu daftar yang sama untuk papan tulis dan buku catatan.
      Namanya ikut disebut karena bulatan warna saja sulit dibedakan di layar
      kecil — apalagi hijau dan hijau muda
- [x] **Kertas buku catatan juga** (2026-09-29): **A5, A4, A3, A2, A1**, tegak
      atau mendatar, **per lembar** — satu buku boleh mencampur A5 tegak untuk
      tulisan dan A3 mendatar untuk bagan. Lembar baru mewarisi kertas lembar
      yang sedang dibuka. Memutar lembar membawa isinya (memutar empat kali
      kembali persis, dan titik tintanya tidak pernah ditulis ulang);
      memperbesar kertas memberi ruang tanpa membengkakkan tulisan, dan
      memperkecil yang membuat sesuatu keluar kertas **dikatakan** — bukan
      dirapikan diam-diam, karena memindahkannya sendiri akan mengacaukan tata
      letak yang sudah diatur
- [x] PDF yang dijadikan buku catatan memilih kertas **terdekat** dengan
      halaman aslinya beserta arahnya (2026-09-29): halaman A4 mendatar
      mendarat di kertas A4 mendatar, bukan dipaksa tegak lalu menyisakan dua
      pita kosong

### Bangun, panah, dan penghubung

- [x] **Bangun dua dimensi**: kotak, bulat, belah ketupat, segitiga, garis,
      dan **panah** (2026-09-29). Ada di papan tulis (jadi goresan) dan di buku
      catatan (jadi komponen yang bisa digeser, diubah ukuran, diputar)
- [x] Bangun di buku catatan **tidak menyimpan titik**: bentuknya dihitung
      ulang dari kotaknya, jadi diubah ukurannya tetap rapi — bukan
      titik-titik lama yang ditarik melar (2026-09-29)
- [x] **Menghubungkan satu objek dengan objek lain** (2026-09-29): ketuk benda
      pertama, ketuk benda kedua. Yang disimpan **rujukan kedua ujungnya**,
      bukan koordinat — menyimpan koordinat berarti garisnya tertinggal di
      tempat lama begitu bendanya digeser, dan penghubung yang tidak mengikuti
      bukan penghubung. Ujungnya berhenti di tepi kedua benda, bukan di
      tengahnya
- [x] Membuang sebuah benda ikut membuang penghubung yang menempel padanya, dan
      penghubung yang ujungnya hilang dibuang saat berkasnya dibaca — bisa
      terjadi setelah dua orang menyunting catatan yang sama (2026-09-29)

### Stylus

- [x] **Goresan dihaluskan** (2026-09-29) dengan kurva kuadratik yang melewati
      titik tengah antar titik. Titik dari layar selalu bersudut — jari dan
      stylus melaporkan posisinya beberapa puluh kali per detik — dan garis
      lurus di antaranya membuat tulisan terlihat patah-patah, paling terasa
      pada huruf melingkar dan tanda tangan. Kurva yang sama dipakai di layar,
      di PNG, dan di PDF, jadi cetakannya tidak pernah berbeda
- [x] **Penolak telapak tangan** (2026-09-29): sakelar "jari boleh menggambar".
      Dimatikan berarti hanya stylus yang menggambar — dan itulah penolak
      telapak tangan yang sebenarnya, karena sentuhan tangan tidak pernah
      sampai ke kanvas. Tetikus tetap diizinkan, supaya layar tanpa stylus
      tetap bisa dipakai
- [x] **Tebal goresan mengikuti tekanan stylus** (2026-09-29). Tekanan menulis
      biasa — sekitar separuh — menghasilkan tebal pena yang dipilih, jadi
      angka di menu tetap berarti sesuatu; menekan menebalkan, menyentuh ringan
      menipiskan, dan batas bawahnya tidak nol karena garis yang hilang saat
      tangan melemah terasa seperti pena yang rusak. Hanya untuk stylus: banyak
      layar melaporkan tekanan tetap untuk jari, dan mengikutinya membuat tebal
      berubah tanpa sebab. Tebal per titik hanya disimpan kalau tekanannya
      memang berubah, dan ikut terbawa saat goresan dipotong penghapus atau
      kertasnya diputar

### Menata koleksi

- [x] **Seret catatan antar koleksi** di pohon (2026-09-29), dan **seret item
      paper antar koleksi** juga — keanggotaan koleksi Zotero tersimpan di
      dalam berkas itemnya (`zotero.collections` dan `meta.collections`), dan
      keduanya ikut diperbarui
- [x] Lepasan yang tidak pantas **ditolak dengan penjelasan**: catatan ke akar
      paper, paper ke akar catatan, berkas bukan-PDF ke akar paper
      (2026-09-29)
- [x] **Sub-koleksi bisa dibuat langsung** dari tombol di barisnya (2026-09-29).
      Sebelumnya hanya lewat tekan-lama, dan yang tidak pernah menekan lama
      tidak pernah menemukannya — itu memang yang terjadi
- [x] **Membuat koleksi paper baru** dari dalam aplikasi, berikut
      sub-koleksinya (2026-09-29). Ini satu-satunya tempat ReadPaper menulis
      berkas **struktur** Zotero (`collections.json`), jadi pagarnya rapat:
      yang sudah ada tidak pernah diubah maupun diurutkan ulang — entri baru
      ditambahkan di ujung dengan bentuk tulisan yang sama persis seperti
      plugin (array beridentasi tab, kunci terurut, `parentKey: null` untuk
      akar, `relations: {}`), jadi diff-nya hanya satu blok yang bertambah.
      Dibuktikan pada `collections.json` sungguhan berisi 61 koleksi: dibaca
      lalu ditulis ulang dengan penulis yang sama menghasilkan berkas yang
      **sama byte-for-byte**. Nama kembar di bawah induk yang sama ditolak,
      begitu juga nama bergaris miring — itu pemisah jalur koleksi di berkas
      ini. Berkas yang isinya bukan daftar koleksi ditolak dengan mengatakan
      menolak, bukan ditimpa
- [ ] Mengganti nama dan menghapus koleksi paper. Menghapus lebih berat
      daripada membuat: item yang jadi yatim harus diputuskan mau ke mana, dan
      itu keputusan sendiri

### Menulis dan memilih

- [x] **Zum dua jari di kanvas catatan** (2026-09-29), dengan tombol "pas ke
      layar" untuk mengembalikannya. Dikerjakan sendiri, **bukan** dengan
      `InteractiveViewer`: pengenal gerakannya ikut bersaing untuk seretan satu
      jari, dan akibatnya terukur — awal setiap goresan hilang sekitar enam
      puluh piksel sebelum kanvas menang di arena, dan seretan pendek seperti
      satu ketukan penghapus tidak pernah sampai sama sekali. Cubitannya
      dihitung langsung dari peristiwa pointer, jadi tidak ada arena yang perlu
      dimenangkan. Jari kedua yang mendarat juga membuang goresan yang sedang
      ditarik — jari kedua berarti memperbesar, bukan menggambar
- [x] **Kotak pilih** (2026-09-29): dengan alat Pilih, seretan di ruang kosong
      menarik kotak, dan semua benda yang **tersentuh** kotaknya jadi terpilih —
      tersentuh, bukan harus termuat seluruhnya, karena menuntut coretan panjang
      masuk penuh membuat memilih hampir tidak mungkin. Lalu bisa langsung
      dihapus sekaligus
- [x] **Tombol hapus di bingkai komponen bisa ditekan lagi** (2026-09-29).
      Terlihat tapi tidak bisa ditekan untuk benda yang menempel di tepi
      lembar: pegangan bingkai duduk di luar kotak benda, dan anak yang
      digambar di luar batas induknya tidak pernah menerima sentuhan. Lembar
      catatan sekarang punya ruang di sekelilingnya seluas pegangannya
- [x] Hal yang sama diperbaiki di **pembaca** (2026-09-29): pegangan anotasi
      yang menempel di tepi halaman ditahan tetap di dalam halaman, dan
      pergeserannya dibayar balik oleh jarak dalamnya supaya bingkainya tetap
      pas di anotasinya

### Pembaca

- [x] **PDF hasil suntingan bisa disimpan ke folder kerja** (2026-09-29) — folder
      yang sama dengan tempat papan tulis dan PDF yang disalin masuk tinggal,
      beserta sub-foldernya. Sebelumnya di Android satu-satunya jalan adalah
      dialog simpan sistem, dan berkas yang keluar dari sana tidak pernah muncul
      lagi di panel berkas: "sudah disimpan" tetapi tidak ketemu. Dialog sistem
      tetap ada sebagai pilihan "Tempat lain…"
- [x] Satu definisi folder kerja dipakai bersama panel berkas dan setiap layar
      yang menyimpan (2026-09-29) — sebelumnya tiap tempat menghitungnya sendiri


- [x] **Halaman pertama mode menyajikan terpasang di tengah dan penuh layar**
      (2026-09-29). Dua sebab, keduanya terukur: dokumennya dulu dibuat lebih
      lebar dari halamannya sehingga pemasangan awal memilih zum yang
      mengecilkan, dan `goToPage` di pdfrx membatasi zumnya pada zum yang sedang
      berlaku (`zoomMax: _currentZoom`) sehingga halaman yang sudah kecil tidak
      pernah bisa membesar. Sekarang lewat `goToArea` pada kotak halamannya, dan
      pemasangannya diulang sekali setelah tata letaknya benar-benar berlaku
- [x] **Zum tetap ada di mode menyajikan** (2026-09-29): cubitan diizinkan lagi,
      plus tombol perkecil/perbesar/pas-ke-layar di bilahnya. Yang membuatnya
      terasa seperti slide bukan mengunci gerakan, melainkan tata letak satu
      halaman per layar dan tombol "pas ke layar" yang selalu ada
- [x] **Urungkan saat menyajikan membuang goresan terakhir**, bukan seluruh
      gambar (2026-09-29). Garis nyasar dari telapak tangan dulu hanya bisa
      dibuang dengan mengurungkan semuanya, karena seluruh coretan di satu
      halaman jadi satu anotasi
- [x] **Sakelar "Stylus saja" ada juga di mode menyajikan**, dan nilainya
      **disimpan** (2026-09-29) — ini sifat perangkatnya, bukan pilihan sesaat,
      dan memilihnya ulang setiap kali membuka dokumen adalah cara tercepat
      membuat orang berhenti memakainya
- [x] **Menyimpan bisa dari dalam mode menyajikan** (2026-09-29): ke berkas itu
      sendiri atau sebagai PDF baru. Coretan yang dibuat saat menjelaskan
      sering justru yang paling berharga, dan sebelumnya harus keluar dulu untuk
      menyimpannya — kalau ingat
- [x] Goresan yang belum jadi anotasi ikut disimpan lebih dulu (2026-09-29):
      menyimpan sambil pena masih aktif dulu menghasilkan berkas tanpa coretan
      yang baru dibuat


- [x] **Tombol hapus anotasi bekerja untuk PDF yang dibuka lepas** (2026-09-29).
      Sebabnya satu pagar `item == null` di pembungkus konfirmasinya: PDF dari
      panel berkas, dari koleksi catatan, atau lewat "buka dengan" tidak punya
      item Zotero, jadi tong sampahnya tidak melakukan apa pun sama sekali —
      sementara geser, ubah ukuran, dan putar jalan, karena jalurnya lain
- [x] **Mode menyajikan benar-benar satu halaman per layar** (2026-09-29):
      halamannya diberi jarak setinggi halaman terpanjang, jadi halaman
      sebelumnya dan berikutnya tidak lagi menyembul di atas dan di bawah
- [x] **Penolak telapak tangan di pembaca** (2026-09-29): sakelar "Stylus saja"
      di bilah alat. Tangan yang bertumpu di layar sambil menulis dengan stylus
      dulu meninggalkan garisnya sendiri, dan itu cukup untuk membuat orang
      berhenti memakai penanya
- [x] **Lembar kosong bisa disisipkan di tengah** (2026-09-29), bukan hanya di
      akhir: "n halaman setelah halaman ini" atau "di akhir dokumen".
      Menambahkan di akhir saja memaksa yang sedang menjelaskan melompat ke
      belakang dokumen, dan catatannya kehilangan tempat dalam ceritanya

### Panel berkas

- [x] **Bisa dilipat ke bawah** (2026-09-29): panel berkas berguna saat sedang
      memasukkan sesuatu, dan di waktu lain hanya mempersempit pohon koleksi
- [x] **Kepalanya diringkas dari tujuh ikon jadi empat** (2026-09-29): naik satu
      tingkat, satu menu **Buat baru** (papan tulis, buku catatan, berkas
      Markdown, folder), salin berkas ke sini, dan buka folder lain. Tujuh ikon
      berdesakan di panel selebar 300 titik adalah sebab kenapa "buat folder"
      dan "buka berkas" tidak pernah ketemu
- [x] Tombol yang butuh folder kerja **tidak lagi mati tanpa keterangan**
      (2026-09-29) — dikatakan apa yang kurang


- [x] **Kendali mode menyajikan pindah ke bawah** (2026-09-29). Di kanan atas ia
      bertengkar dengan tempat yang bukan miliknya: lubang kamera dan bilah
      status yang disembunyikan mode imersif tetap memakan sentuhan di sana,
      jadi tombol keluar dan ganti halaman terlihat tetapi tidak selalu bisa
      ditekan. Sekarang satu bilah di bawah, di atas bilah navigasi: halaman
      sebelumnya, nomor halaman, berikutnya, pena, **urungkan**, tambah lembar
      kosong, dan keluar
- [x] **Ganti halaman tetap bisa saat mode coret-coret** (2026-09-29) lewat
      bilah itu — ketuk tepi memang tetap dilepas selama pena aktif, karena satu
      coretan tidak boleh berubah jadi ganti halaman
- [x] **Urungkan ada di mode menyajikan** (2026-09-29): sebelumnya harus keluar
      dari mode menyajikan dulu untuk mencarinya — di depan orang
- [x] Keping mode baca juga diletakkan memakai `viewPadding`, bukan `SafeArea`
      (2026-09-29): mode imersif membuat jarak amannya nol padahal lubang
      kameranya masih di sana

### Catatan

- [x] **Telapak tangan tidak lagi menggerakkan kanvas di mode "Stylus saja"**
      (2026-09-29). Yang ditolak dulu hanya menggambar, sementara tangan yang
      bertumpu tetap terhitung sebagai jari kedua — jadi kanvasnya mencubit
      sendiri tepat saat tangan mendarat, keadaan yang justru hendak dihindari.
      Sekarang di mode itu sentuhan tangan tidak menyentuh apa pun: tidak
      menggambar, tidak mencubit, tidak menggeser
- [x] **Tombol zum (+/−) dan pas ke layar** (2026-09-29) — karena di mode
      "Stylus saja" cubitan memang ikut dilepas, dan tanpa tombol tidak ada
      jalan memperbesar
- [x] **Benda yang baru ditaruh langsung terpilih** dan alatnya pindah ke Pilih
      (2026-09-29): gambar, teks, dan diagram yang baru disisipkan dulu tidak
      bisa digeser, diubah ukuran, diputar, atau dihapus sampai alatnya diganti
      sendiri — dan tidak ada yang mengatakan bahwa itu yang kurang

- [x] **Gambar di koleksi catatan bisa dibuka** (2026-09-29) — bisa diperbesar
      dua jari dan dibagikan. Sebelumnya ketukannya hanya menjawab "belum bisa
      dibuka", padahal gambar adalah bentuk catatan yang paling sering datang
      dari luar: pindaian, tangkapan layar, foto papan tulis
- [x] **Alat penempel mengatakan langkah berikutnya** (2026-09-29): memilih alat
      teks, gambar, diagram, atau penghubung menyebut apa yang harus diketuk
      sesudahnya. Tanpa itu, memilih alat gambar lalu menunggu terasa seperti
      "tidak bisa", padahal yang kurang hanya satu ketukan di lembarnya
- [x] Gambar yang tidak menyerahkan jalur berkas — beberapa penyedia berkas
      Android hanya memberi URI — dikatakan sebabnya, bukan didiamkan
      (2026-09-29)


- [x] **Mode menyajikan benar-benar seperti slide** (2026-09-29): gulir bebas
      dan cubit dilepas sama sekali, jadi halamannya tidak bisa tergeser
      setengah karena tangan menyenggol. Berganti halaman lewat ketuk tepi,
      geseran ke samping, atau tombolnya — dan tiap halaman dipaskan penuh
      layar lagi, termasuk halaman yang ukurannya berbeda dari sebelumnya
- [x] **Lembar kosong bisa ditambahkan dari dalam mode menyajikan**
      (2026-09-29), lalu langsung dicoreti di situ — tanpa keluar dari mode
      menyajikan dan tanpa mencari menu
- [x] **Sakelar jari/stylus tidak lagi terbaca seperti alat** (2026-09-29).
      Sebelumnya ia duduk di antara tombol alat dengan ikon pena; ditekan, lalu
      bingung kenapa tidak bisa menggambar. Sekarang berdiri di ujung bilah
      sebagai keping bernama ("Jari + stylus" / "Stylus saja"), alat yang sedang
      dipegang disebut di kepala layar, dan menyeret dengan alat yang tidak
      menggambar **mengatakan** alat apa yang aktif — diamnya yang paling
      membingungkan
- [x] **Halaman PDF bisa disisipkan sebagai lembar catatan** (2026-09-29), di
      tengah buku, setelah lembar yang sedang dibuka — bukan hanya saat sebuah
      PDF dijadikan buku catatan seluruhnya
- [x] **Bilah bawah tidak lagi tertutup taskbar Android** (2026-09-29). Ini
      sebab sebenarnya dari "catatan tidak bisa mendatar": tombol ukuran kertas
      dan arahnya ada, tetapi bilahnya duduk di bawah bilah navigasi sistem —
      terlihat, sentuhannya diambil sistem, dan yang memakainya menyimpulkan
      fiturnya tidak ada. Berlaku untuk buku catatan dan papan tulis
- [x] Kertas dan arahnya **dipindah ke depan** di bilah itu, dan ikut disebut di
      kepala layar (2026-09-29): sebelumnya keduanya paling ujung di bilah yang
      bisa tergulir, jadi di layar sempit tidak pernah terlihat sekalipun

- [x] **Bilah pembaca tidak lagi bertumpuk** (2026-09-29). Di layar sempit
      tombolnya pindah ke baris sendiri di bawah judul: AppBar memberi judulnya
      kotak tetap, dan keterangan dokumen — jumlah anotasi dan nomor halaman —
      tertutup tombol-tombol di atasnya
- [x] **Tambah lembar kosong jadi tombol tetap**, bukan hanya di dalam menu
      simpan (2026-09-29): yang mau menambah lembar catatan tidak sedang
      berpikir tentang menyimpan
- [x] **PDF jadi buku catatan** (2026-09-29): tiap halaman jadi alas satu
      lembar, plus lembar kosong di belakang untuk catatan tambahan, dan
      seluruhnya bisa disunting lagi lalu disimpan sebagai PDF atau Markdown.
      Halamannya jadi gambar, dan itu memang harga yang dibayar — teks PDF
      tidak bisa jadi komponen teks tanpa pengenalan tata letak yang belum ada.
      Yang mau teksnya ikut terbaca memakai "Ubah ke Markdown"

- [x] **Ganti warna tidak lagi mewarnai ulang coretan sebelumnya** (2026-09-29).
      Satu anotasi `ink` Zotero menyimpan satu warna untuk semua jalurnya, jadi
      selama coretan masih terkumpul di satu anotasi, mengganti warna berarti
      mengganti warna semuanya. Sekarang mengganti warna — atau ketebalan —
      menutup dulu anotasi yang sedang terkumpul, dan garis berikutnya mulai
      anotasi baru dengan warna baru
- [x] **Jari tetap milik halaman selama pena aktif** (2026-09-29), dalam mode
      "Stylus saja": jari menggeser dan mencubit dokumen, stylus menulis. Ini
      menuntut membalik tempat penangkapan goresan. Apa pun yang menerima
      pointer **di depan** penampil PDF — `GestureDetector` maupun `Listener`,
      sekalipun dibatasi ke stylus — membuat sentuhan jari tidak pernah sampai
      ke penampilnya; terbukti di tablet: dokumennya sama sekali tidak bisa
      digeser. Jadi lapisan tintanya tidak lagi menyentuh pointer sama sekali
      (`IgnorePointer`, hanya melukis), dan goresan stylus ditangkap oleh
      `Listener` yang **membungkus** penampil — ia hanya menyimak, tidak pernah
      menghalangi. Titiknya dipetakan ke halaman lewat kotak halaman yang
      dicatat saat lapisannya dibangun
- [x] Goresan yang sedang ditarik **dicat ulang tanpa membangun ulang layar**
      (2026-09-29): stylus mengirim titik seratus kali sedetik, dan `setState`
      sebanyak itu terasa tersendat persis di saat kelancaran paling dibutuhkan

- [x] **Telapak tangan tidak lagi memutus goresan stylus** (2026-09-29). Bug
      yang membuat stylusnya terasa "kadang jalan kadang tidak": penangkap
      goresan mengakhiri goresan pada **setiap** pointer yang terangkat, bukan
      hanya pointer milik stylus. Telapak tangan yang bertumpu di layar —
      justru keadaan yang dilayani mode "Stylus saja" — turun dan naik
      berkali-kali selama tangan bergerak, jadi tiap kali itu terjadi goresan
      yang sedang ditarik dipotong, dan yang baru satu dua titik dibuang.
      Akibat lanjutannya: karena goresannya tidak pernah mendarat,
      `_pendingInk` tetap kosong sehingga **tombol Urungkan dan tong sampah di
      bilah pena ikut mati** — terlihat ada, tidak bisa ditekan. Sekarang
      goresan terikat pada satu pointer, dan hanya pointer itu yang
      mengakhirinya
- [x] **Tombol warna di bilah pena ikut menutup goresan** (2026-09-29).
      Perbaikan "ganti warna tidak mewarnai ulang coretan lama" sebelumnya
      hanya mengenai tombol warna di bilah atas; tombol di bilah pena — yang
      justru dipakai sambil menggambar — masih mengganti `_color` langsung

- [x] **Separuh halaman tidak bisa ditulisi setelah lama dipakai**
      (2026-10-03), di mode "Stylus saja". Kotak halaman yang dipakai untuk
      menentukan goresan jatuh di halaman mana dicatat saat lapisan halaman
      dibangun — dan halaman yang sudah keluar layar tidak dibangun lagi, jadi
      kotaknya tertinggal di tempat terakhir ia terlihat. Setelah menggulir
      cukup lama, kotak basi itu menutupi separuh halaman yang sedang dibuka
      dan goresannya mendarat di halaman lain yang tidak terlihat. Sekarang
      kotaknya dihitung dari tata letak dan zum yang sedang berlaku setiap
      kali stylus turun
- [x] **Alat pena ada di bilah bawah mode menyajikan** (2026-10-03): warna,
      tebal, urungkan, buang, stylus saja, dan Selesai. Bilah pena di atas
      tidak muncul lagi saat menyajikan — tanpa AppBar ia duduk di bawah bilah
      status dan lubang kamera, jadi Selesai dan Buang di ujung kanannya
      terlihat tetapi sentuhannya diambil sistem. Bilah bawahnya bisa digulir
      ke samping kalau layarnya sempit
- [x] **Telapak tangan tidak lagi menggeser halaman** di mode "Stylus saja"
      (2026-10-03). Jari memang tetap milik halaman, tetapi sentuhan yang
      datang saat stylus melayang di dekat layar, sedang menulis, atau baru
      diangkat (800 ms), atau yang bidang sentuhnya selebar telapak, dianggap
      telapak: selama ada satu, geser dan cubit dimatikan

- [x] **"Jadikan buku catatan" di pembaca benar-benar menjadikan buku catatan**
      (2026-10-04). Menunya ada, pengubahnya ada, tetapi keduanya tidak pernah
      disambungkan: pilihannya jatuh ke cabang bawaan dan malah membagikan PDF
- [x] **Lampiran paper library tidak lagi bisa ditimpa** dari desktop
      (2026-10-04). "Simpan ke berkas ini" dulu muncul juga untuk paper
      library: anotasinya dileburkan ke halaman — di Zotero tampil dua kali —
      dan salinan `.asli.pdf` ditaruh di dalam struktur Zotero. Sekarang paper
      library selalu disimpan sebagai PDF baru

- [x] **Bagikan ada di setiap layar dokumen** (2026-10-04): penyunting
      Markdown (sebagai `.md` atau PDF), buku catatan dan papan tulis (sebagai
      PDF, tanpa harus menyimpannya dulu), serta panel berkas dan daftar
      catatan. Sebelumnya hanya pembaca PDF dan penampil gambar. Buku catatan
      selalu dibagikan sebagai PDF — penerimanya tidak punya ReadPaper

- [x] **Membaca EPUB** (2026-10-04): satu bab per layar, daftar isi (nav EPUB 3
      atau NCX EPUB 2), ukuran huruf, tiga warna halaman, posisi diingat per
      buku, dan terdaftar di "Buka dengan" Android. Pengurainya ditulis
      sendiri — paket EPUB yang ada menuntut `image` dan `xml` versi lama.
      Dua jebakan EPUB Gutenberg ditangani: `<a id/>` yang menutup sendiri
      (HTML membacanya sebagai tautan yang tak pernah ditutup, seluruh bab
      jadi biru) dan sampul dalam `<svg><image>`
- [ ] Stabilo dan catatan di EPUB, ditulis sebagai anotasi Zotero (CFI)
- [x] **Persiapan iPhone/iPad** (2026-10-04): platform iOS, "Buka dengan" untuk
      PDF dan EPUB, berkas masuk lewat kanal yang sama dengan Android, dan
      alur kerja CI di runner macOS yang menghasilkan `.ipa` tanpa tanda
      tangan untuk dipasang lewat Sideloadly dengan Apple ID gratis
- [ ] Build iOS pertama di CI dan uji di iPhone sungguhan

- [x] **"Tambahkan ke koleksi" gagal di desktop** (2026-10-04). Clone desktop
      ramping — folder lampiran dikecualikan sparse checkout — dan `git add .`
      menolak PDF baru di sana ("outside of your sparse-checkout definition"),
      sehingga seluruh commit-nya gagal. Ditemukan saat menulis dokumentasi,
      dibuktikan dengan git sungguhan, dan kini `git add --sparse` di clone
      ramping

### Ganti nama dan hapus — diminta 2026-10-04, dikerjakan 2026-10-05

- [x] **Folder di panel berkas**: menu ⋮ dengan Buka, Ganti nama, dan Hapus
      folder. Hapus menyebut jumlah berkas di dalamnya ("Hapus 12 berkas") dan
      menolak menghapus folder kerja itu sendiri
- [x] **Koleksi paper (Zotero)**: Ubah nama, Pindahkan ke…, dan Hapus koleksi
      lewat ⋮. Kuncinya tetap; `path` koleksi dan keturunannya dihitung ulang,
      jalur di `meta.collections` item anggotanya ikut, dan `dateModified` item
      hanya berubah bila keanggotaannya di Zotero memang berubah. Hapus tidak
      menghapus paper — hanya melepasnya, seperti di Zotero — dan menanyakan
      nasib sub-koleksinya: ikut terhapus, atau naik satu tingkat. Pindah
      menolak masuk ke keturunan sendiri. Diuji pada salinan library asli
      (61 koleksi, 1.741 item): ganti nama koleksi bersarang mengubah tiga baris
      `collections.json` dan satu jalur di satu item, tidak lebih
- [x] **Koleksi catatan**: menu yang sama sekarang lewat ⋮ yang terlihat, bukan
      hanya tekan lama
- [x] Setiap perubahan di-commit dengan pesan yang menyebut namanya
      ("Ubah nama koleksi: jejakin/projects → proyek"), dan bentrok antar
      perangkat ditangani penggabung JSON yang sama dengan pull
- [x] Uji: nama kembar, kosong, dan bergaris miring; pindah ke keturunan
      sendiri; hapus dengan dan tanpa sub-koleksi; item yang tidak tersentuh
      tidak ditulis ulang
- [ ] Ganti nama koleksi memindai semua item (±2 detik pada 1.741 item di
      desktop). Indeks keanggotaan di memori akan membuatnya seketika

- [x] **Layar Repositori kosong di semua platform** (2026-10-05). Footer versi
      di bawahnya memakai Column dengan tinggi maksimum, dan sebagai
      bottomNavigationBar ia mengambil seluruh layar: daftar profil setinggi
      nol, tombol "Tambah repositori" tertutup. Akibatnya repo dan token tidak
      bisa disunting, dan repo kedua tidak pernah bisa ditambahkan — sehingga
      pengalih repositori di bilah atas, yang hanya aktif bila ada lebih dari
      satu, tidak pernah muncul. Dilaporkan dari CachyOS, direproduksi dengan
      rilis Linux di Xvfb, dan dijaga uji widget

- [x] **PDF tersimpan tidak lagi jadi gambar seluruhnya** (2026-10-05).
      Simpan, Simpan sebagai PDF, dan Bagikan dulu merender setiap halaman jadi
      JPEG: teks tidak bisa dicari atau disalin, tabel jadi foto. Sekarang
      halaman aslinya dibiarkan apa adanya lewat pdfium, dan anotasi
      ditambahkan sebagai objek vektor: stabilo transparan dengan campuran
      multiply (teks di bawahnya tetap terbaca dan bisa dipilih), coretan
      sebagai jalur, isian Tt sebagai teks PDF, komentar sebagai catatan tempel
      PDF. Merender jadi gambar tinggal jalan terakhir untuk PDF yang tidak
      bisa ditulisi pdfium

### Banyak repositori — diminta 2026-10-05, dikerjakan di 0.24.0

- [x] **Ukuran tiap repositori** di layar Repositori, di pengalih repositori, dan
      di lembar pindah: jumlah item dan koleksi (dihitung dari berkasnya, bukan
      dari angka plugin yang basi), ukuran di disk, lampiran yang sudah
      diunduh, berapa yang belum terkirim, dan berapa yang baru di GitHub.
      Dihitung di isolate tersendiri
- [x] **Pengalih repositori selalu terbuka**, juga dengan satu repo, dan punya
      "Kelola repositori…" — dari situ repo kedua ditambahkan
- [x] **Pindahkan atau salin paper ke koleksi di repositori lain**, dari panel
      detail. Item, anotasi, lampiran (`attachments/` dan `attachments-lfs/`),
      dan catatan plugin ikut; `libraryID`, `libraryName`, dan `zoteroURI`
      diganti mengikuti library tujuan. Satu commit di tiap repo
- [x] **Pindahkan atau salin koleksi beserta sub-koleksi dan paper-nya**, dari
      menu ⋮. Kunci koleksi yang sudah dipakai di tujuan diberi kunci baru dan
      keanggotaannya dipetakan. Saat memindah, paper yang juga ada di koleksi
      lain di asal tetap di sana, hanya dilepas
- [x] **Tidak pernah setengah jadi, tidak pernah kehilangan PDF**: semua item
      diperiksa lebih dulu, dan pemindahan ditolak — dengan alasannya — bila
      ada lampiran yang belum diunduh atau masih penunjuk Git LFS
- [x] Diuji dengan dua repositori git sungguhan lewat controller yang sama
      dengan layar, dan dicoba lewat antarmuka build Linux
- [x] **Memindah catatan dan koleksi catatan ke repositori lain** (0.24.1),
      dari menu catatan dan menu ⋮ koleksi catatan. Seluruh folder berkas
      catatan ikut — buku catatan menyimpan gambar halamannya di sana, dan
      tanpa itu tiba sebagai lembar kosong. Kunci yang terpakai di tujuan
      diganti; nama koleksi kembar ditolak sebelum apa pun ditulis
- [ ] Mengunduh lampiran yang belum ada secara otomatis sebelum memindah,
      daripada meminta membuka papernya dulu
- [ ] Seret dan lepas antar repositori

- [x] **Penghapus dan tinta putih untuk pena** (2026-10-05). Sakelar penghapus
      di bilah pena, juga di bilah bawah mode menyajikan: goresan yang disapu
      dibuang utuh, baik yang belum disimpan maupun yang sudah jadi anotasi
      tinta — coretan yang habis goresannya ikut dihapus — dan semuanya bisa
      diurungkan. Sapuannya terlihat sebagai jejak abu-abu, dan titik sapuan
      dirapatkan supaya stylus yang bergerak cepat tidak melompati garis tipis.
      Ujung penghapus stylus langsung menghapus. Warna pena bertambah putih
      ("tip-ex" di halaman putih) dan hitam; stabilo tidak, karena stabilo
      putih tidak menandai apa pun

### Sinkronisasi

- [x] **Pull yang bentrok tidak lagi menggantung, dan tidak lagi menimpa**
      (2026-10-04). Di laptop CachyOS, pull berhenti karena `koleksi.json`
      diubah di laptop dan tablet. Rebase-nya ditinggal menggantung, setiap
      pull berikutnya gagal dengan "rebase-merge directory", dan simpan
      anotasi berikutnya meng-commit penanda konflik sehingga JSON-nya rusak.
      Sekarang rebase yang tertinggal dicadangkan lalu dipulihkan, bentrok JSON
      digabung per kunci, dan commit tidak pernah terjadi di tengah rebase. Di
      Android dan iOS, pull tidak lagi menimpa berkas yang diubah lokal.
      Diuji pada salinan repo laptop itu: 8 koleksi tergabung, cabangnya lurus

- [x] **Satu berkas yang ditolak GitHub tidak lagi menahan semua yang lain**
      (2026-10-03). Pengiriman berhenti di 20/32 pada sebuah buku PDF, dan
      karena antreannya terus bertambah, setiap percobaan gagal di tempat yang
      sama dengan antrean yang makin panjang (635 perubahan). Sekarang berkas
      yang ditolak (422, atau di atas 100 MB) disisihkan, yang lain tetap
      terkirim dalam satu commit, dan yang ditolak tetap di antrean dengan
      namanya dan alasan GitHub disebut. Isi yang sama tidak diunggah ulang
      hanya untuk ditolak lagi
- [x] Berkas yang dibuat lalu dihapus sebelum sempat terkirim tidak lagi
      diminta dihapus di GitHub — GitHub menolak seluruh pohon untuk itu — dan
      berkas di antrean yang isinya sudah sama dengan GitHub tidak diunggah
- [x] Batas kecepatan sekunder GitHub (403/429 dengan `Retry-After`) ditunggu
      lalu dicoba lagi, dan tidak lagi tampil sebagai "token perlu izin"
- [ ] Blob yang sudah terunggah diingat, supaya pengiriman yang terputus di
      tengah tidak mengulang dari awal

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
