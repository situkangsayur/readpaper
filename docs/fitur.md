# Fitur ReadPaper

Dokumen ini untuk orang yang memakai ReadPaper, bukan yang membangunnya: apa
saja yang bisa dikerjakan, dan kenapa itu berguna. Tiap butir sengaja pendek.
Cara melakukannya langkah demi langkah ada di
[panduan-pengguna.md](panduan-pengguna.md); cara kerjanya di dalam ada di
[panduan-teknis.md](panduan-teknis.md) dan [architecture.md](architecture.md).

Ditulis untuk versi 0.23.4 (2026-10-04). Yang belum ada dicatat di
[backlog.md](backlog.md); ringkasannya ada di bagian terakhir dokumen ini.

Satu hal yang perlu diketahui lebih dulu: ReadPaper **tidak menggantikan
Zotero**. Ia membaca dan menulisi library Zotero yang sudah disinkronkan ke
GitHub oleh plugin `zotero-github-sync`, dan menjaga supaya Zotero tetap bisa
membacanya kembali. Semua fitur di bawah tunduk pada aturan itu.

---

## Library dan koleksi

- **Beberapa repositori sekaligus.** Pengalih di bilah atas menunjukkan isi dan
  ukuran tiap repositori: item, koleksi, ruang di disk, lampiran yang sudah
  diunduh, dan yang belum terkirim. Paper dan koleksi, beserta sub-koleksi,
  anotasi, dan PDF-nya, bisa **dipindahkan atau disalin** ke koleksi di
  repositori lain, dengan satu commit di tiap repositori. Begitu juga catatan
  dan koleksi catatan, termasuk buku catatan beserta gambar halamannya.
- **Pohon koleksi ala Zotero.** Koleksi bertingkat yang bisa dibuka dan
  ditutup, jumlah item per koleksi, "Semua item", "Tanpa koleksi", dan pilihan
  menyertakan item sub-koleksi. Bentuknya sama dengan yang dilihat di Zotero,
  jadi tidak perlu belajar susunan baru.
- **Dua akar: paper dan Catatan.** Di atas ada library Zotero; di bawahnya akar
  bernama **Catatan** untuk catatan lepas, papan tulis, dan buku catatan.
  Catatan disimpan di folder `catatan/` tersendiri di repositori yang sama,
  di luar ekspor Zotero, karena Zotero tidak mengenal catatan yang tidak
  menempel pada paper dan formatnya dijaga ketat oleh plugin.
- **Membuat koleksi paper dan sub-koleksi** langsung dari aplikasi. Ditulis ke
  `collections.json` dengan bentuk yang sama persis seperti tulisan plugin,
  jadi Zotero tetap membacanya. Nama kembar di tempat yang sama dan nama
  bergaris miring ditolak.
- **Ganti nama, pindahkan, dan hapus koleksi paper** lewat tombol ⋮. Kuncinya
  tetap, jadi keanggotaan paper tidak hilang. Menghapus koleksi melepas paper
  dari koleksi itu, tanpa menghapusnya, sama seperti di Zotero.
- **Pemasang Windows** (`readpaper-<versi>-windows-x64-setup.exe`) ke
  Program Files, dengan git bawaan, pintasan Start menu, dan "Buka dengan" untuk
  PDF/EPUB. Versi berikutnya memperbarui di tempat yang sama, termasuk folder
  yang dulu diisi dari zip. Pengaturan dan clone di
  `%USERPROFILE%\.local\share\readpaper` tidak pernah disentuh. Zip portabel
  tetap tersedia.
- **Tandai di semua platform**: tombol "Tandai" ada juga di desktop. Seret
  mouse di atas teks, dan teksnya langsung distabilo.
- **Android: repo baru langsung diambil, Tarik selalu terlihat.** Menyimpan
  repositori baru langsung mengambil library-nya, dan bilah atas menampilkan
  "Ambil library" selama belum diambil. Tombol Tarik berdiri sendiri, juga di
  layar sempit. Mematikan "Unduh PDF hanya saat dibuka" kini berlaku di
  Android: semua PDF diunduh sesudah ambil dan pull.
- **Impor folder menjadi koleksi.** Seret atau pilih satu folder: folder itu
  menjadi koleksi, subfoldernya menjadi sub-koleksi, dan semua jenis berkas
  masuk, ke Zotero sebagai item berlampiran atau ke Catatan sebagai catatan,
  sesuai tempat lepasnya. Koleksi bernama sama dipakai ulang, dan seluruh impor
  menjadi satu commit.
- **Penampil gambar dan tabel.** CSV, TSV, dan Excel (.xlsx) tampil sebagai
  tabel berlembar. Jenis berkas lain dibuka dengan aplikasi bawaan sistem di
  desktop.
- **Hapus koleksi selalu dikonfirmasi**, dengan peringatan merah dan rincian
  isi bila koleksinya tidak kosong. Berlaku untuk koleksi paper maupun catatan.
- **Menambah PDF ke koleksi** langsung dari pohon: **⋮ → Tambahkan PDF ke
  sini…** (beberapa sekaligus), tombol di akar library, atau di desktop dengan
  **menyeret PDF dari pengelola berkas** (Nautilus, Dolphin, Explorer) ke
  koleksinya. Berkas yang diseret ke panel berkas disalin ke folder kerja.
- **Memindahkan paper antar koleksi** dengan menyeretnya di pohon. Keanggotaan
  koleksi Zotero tersimpan di berkas itemnya, dan itu yang diperbarui.
- **Koleksi catatan** bisa dibuat, diganti nama, dan dihapus. Menghapus
  koleksi catatan tidak menghapus catatannya: isinya pindah ke "Tanpa
  koleksi".
- **Daftar paper** dengan judul, pengarang, tahun, jenis, dan lencana
  berkas/anotasi/catatan; bisa diurutkan menurut judul, tahun, pengarang,
  tanggal ditambahkan, atau jumlah anotasi.
- **Pencarian beroperator**: `pengarang:`, `judul:`, `tahun:`, `tag:`,
  `jenis:`, `jurnal:`, `doi:`, `abstrak:`, `koleksi:`, frasa dalam tanda kutip,
  dan `-` untuk mengecualikan. Nama bidang boleh bahasa Inggris juga
  (`author:`, `title:`, ...). Kata biasa ikut mencari di abstrak, jurnal, tag,
  dan nama koleksi. Ikon tanda tanya di kotak cari membuka daftarnya.
- **Panel pengarang**: semua nama beserta jumlah karyanya, bisa disaring dan
  diurutkan. Berguna ketika namanya belum teringat persis, karena kotak cari
  hanya bisa mencari yang sudah diketahui.
- **Terakhir dibaca**: kartu di atas daftar paper, dan paper yang dibuka lagi
  dilanjutkan di halaman terakhir.
- **Kemungkinan duplikat**: dicocokkan lewat DOI, lalu ISBN, lalu judul + tahun
  + pengarang pertama. Layarnya menandai salinan yang paling pantas
  dipertahankan dan memperingatkan kalau anotasinya tersebar, tetapi **tidak
  menghapus atau menggabungkan apa pun** — penggabungan tetap dikerjakan di
  Zotero, karena menghapus item dari library adalah keputusan yang tidak bisa
  diurungkan.
- **Statistik library**: per tahun, per jenis, pengarang dan tag tersering, dan
  berapa persen item yang berkasnya benar-benar ada. Item tanpa judul atau
  tanpa tahun dihitung terpisah, supaya sisa impor yang gagal kelihatan.
- **Ekspor ke BibTeX** untuk naskah LaTeX: tombol ⋮ di koleksi paper menulis
  `<nama koleksi>.bib` ke folder kerja, dan **Salin BibTeX** di panel detail
  menyalin satu entri. Kunci sitasinya stabil, jadi mengekspor ulang tidak
  mematahkan `\cite{…}` yang sudah ada: `Citation Key:` di kolom Extra (dari
  Better BibTeX) dipakai apa adanya, selain itu `pengarang` + `tahun` + kata
  judul pertama, mis. `mcclean2018barren`. Data diambil dari CSL-JSON yang sama
  dengan sitasi di Word dan OnlyOffice.
- **Menghapus dokumen dari library**, dari bagian paling bawah panel detail,
  dengan konfirmasi. Pasangan dari "tambahkan ke koleksi": yang masuk karena
  salah pencet bisa dicabut lagi.

## Membaca

- **Pembaca EPUB**: satu bab per layar, daftar isi bertingkat, ukuran huruf,
  dan tiga warna halaman (Terang, Sepia, Gelap). Bab, posisi gulir, ukuran
  huruf, dan warnanya diingat per buku. ReadPaper muncul di pilihan **Buka
  dengan** untuk EPUB, dan lampiran EPUB di library kini bisa dibaca.
- **Penampil PDF** dengan pilihan teks, zum, dan bilah gulir. Nomor halaman di
  bilah atas bisa diketuk untuk **lompat ke halaman** dan membuka **daftar
  isi** bawaan berkas (kalau berkasnya punya).
- **PDF diunduh saat dibuka.** Yang diambil pertama kali hanya metadata
  library; PDF menyusul satu per satu lewat tombol **Unduh** di panel detail.
  Library dengan ratusan PDF tidak perlu diunduh seluruhnya ke tablet.
- **Mode baca**: semua bilah hilang, tinggal tiga tombol bulat untuk warna
  halaman, lompat halaman, dan keluar. Masuk mode baca mematikan alat tulis,
  supaya tidak ada yang menggambar sementara tombol urungkannya tersembunyi.
- **Warna halaman**: Normal, Sepia, Redup, Balik warna. Dipasang sebagai saring
  warna di atas halaman, jadi dokumennya tidak berubah. Pada Balik warna,
  warna penanda ikut terbalik (kuning terbaca biru).
- **Layar tetap menyala** selama membaca, bisa dinyalakan dari ikon lampu.
  Mati secara bawaan karena memakan baterai.
- **Membuka PDF apa pun** dari perangkat, bukan hanya dari library: lewat
  tombol "Buka PDF dari perangkat ini" di daftar paper, dari panel berkas, atau
  lewat "Buka dengan" dari aplikasi lain (Android, dan pengelola berkas di
  Linux dan Windows). PDF seperti ini disebut
  *PDF lepas*; anotasinya ditahan di memori sampai disimpan.
- **Tampilan menyesuaikan perangkat**: satu panel di ponsel, daftar di samping
  paper di tablet tegak, dan koleksi + daftar + paper di tablet mendatar atau
  desktop.

## Menandai dan menulis

- **Stabilo, garis bawah, dan komentar** dalam delapan warna palet Zotero.
  Semuanya ditulis balik sebagai anotasi Zotero, jadi muncul juga di Zotero
  setelah plugin menariknya.
- **Mode Tandai** untuk layar sentuh: nyalakan, sapukan jari di atas teks, dan
  begitu jari diangkat teksnya langsung berwarna. Lebih cepat daripada memilih
  teks lalu memilih tombol, untuk paper yang ditandai banyak.
- **Catatan tempel di halaman**, ditaruh dengan satu ketukan.
- **Panel anotasi**: semua kutipan dan komentar di dokumen itu, ketuk untuk
  melompat ke tempatnya, pensil untuk mengubah warna atau komentar.
- **Pena**: gambar bebas dengan warna dan ketebalan pilihan. Satu gambar
  disimpan sebagai satu anotasi tinta Zotero, yang hanya mengenal satu tebal
  per gambar — karena itu di pembaca tebalnya tetap, tidak mengikuti tekanan
  stylus (di papan tulis dan buku catatan, tekanan dipakai). Mengganti warna
  di tengah jalan tidak mewarnai ulang coretan sebelumnya.
- **Stylus saja** (penolak telapak tangan): hanya stylus yang menggambar; jari
  tetap menggeser dan mencubit halaman. Sentuhan yang datang saat stylus
  sedang dekat layar, atau yang bidangnya selebar telapak, tidak menggeser
  halaman. Pilihannya disimpan, karena ini sifat perangkat, bukan pilihan
  sesaat.
- **Memindah, mengubah ukuran, dan memutar** tinta, tanda tangan, dan catatan
  yang sudah ditaruh. Stabilo dan garis bawah tidak bisa diputar, karena Zotero
  menyimpannya sebagai kotak lurus.
- **Pena tidak tertukar dengan seleksi.** Selama pena aktif, seleksi teks dan
  ketukan dimatikan. Stylus yang berhenti sebentar di atas kata tidak lagi
  memblok teks, memunculkan bilah stabilo, atau membuat catatan di tengah
  menulis, termasuk saat menyajikan.
- **Pindah halaman, salin, potong, dan tempel anotasi.** Anotasi terpilih bisa
  diseret ke halaman lain: bayangannya mengikuti jari dengan nomor halaman
  tujuan, dan penampil menggulir sendiri ketika jari ditahan di tepi atas atau
  bawah. Untuk halaman yang jauh ada **Ke halaman…**. **Salin**, **Potong**, dan
  **Tempel** (juga Ctrl+C, Ctrl+X, Ctrl+V di desktop) bekerja di bilah bawah;
  tempelan jatuh di halaman yang sedang dibuka, di posisi yang sama dengan
  aslinya, dan bergeser sedikit bila di sana sudah ada yang persis sama. Papan
  klipnya bertahan setelah pembaca ditutup, jadi bisa ditempel di paper lain.
  Semuanya bisa diurungkan.
- **Urungkan** untuk langkah terakhir, dan selama pena aktif untuk goresan
  terakhir saja.
- **Isi teks di halaman** (ikon Tt) untuk mengisi formulir PDF yang tidak punya
  kolom isian sendiri.
- **Tanda tangan**: ditulis besar di papan tersendiri, lalu diperkecil ke
  tempatnya. Menandatangani langsung pada skala halaman menghasilkan coretan
  gemetar.
- **Tambah halaman kosong** di tengah ("n halaman setelah halaman ini") atau di
  akhir dokumen, untuk dicoreti. Halaman aslinya disalin sebagai objek PDF,
  jadi teksnya tetap bisa dicari. Yang berubah adalah salinan kerja; berkas
  aslinya tidak disentuh sampai disimpan.
- **Simpan, Simpan sebagai, dan bagikan.** Simpan yang pertama selalu
  **Simpan sebagai**: pilih nama dan folder, dan berkas yang dibuka tidak
  disentuh. Simpan berikutnya langsung menimpa berkas hasil itu (Ctrl+S;
  Ctrl+Shift+S untuk nama lain). Bila nama tujuan sudah ada, ReadPaper
  bertanya **Ya** atau **Tidak** dulu, dengan peringatan lebih keras bila yang
  akan ditimpa adalah berkas aslinya. PDF hasilnya tetap berisi teks asli;
  coretan, stabilo, dan gambar tempelan ditambahkan di atasnya. Tersedia juga
  ekspor halaman sebagai PNG/JPG pada 72/144/288 dpi, cetak, bagikan ke aplikasi
  lain, dan ubah teks PDF menjadi Markdown.
- **Peringatan sebelum keluar.** Keluar dari PDF lepas yang coretannya belum
  disimpan, atau dengan goresan pena yang belum selesai, memunculkan pilihan
  **Simpan…**, **Keluar tanpa menyimpan**, atau **Batal**. Peringatan ini
  berlaku untuk tombol kembali maupun saat menutup jendela di desktop.
- **Gambar di halaman.** Gambar bisa ditempel dari papan klip, mis. "Salin
  gambar" di peramban (Ctrl+V; di Android lewat tombol gambar), atau dipilih
  dari berkas. Gambar ditaruh di tengah bagian halaman yang terlihat, lalu bisa
  digeser, diubah ukurannya dengan rasio tetap, disalin, dan dipindah halaman.
  Saat disimpan ke PDF, ia menjadi objek gambar sungguhan. Pada paper library,
  gambar disimpan di `catatan/gambar-halaman/<kunci lampiran>/` dan tidak
  pernah ditulis ke ekspor Zotero, karena anotasi gambar Zotero adalah
  tangkapan wilayah halaman, bukan tempelan.
- **Tambahkan ke koleksi** untuk PDF lepas: berkasnya disalin ke library,
  dibuatkan item Zotero, dan di-commit. Koleksi tujuan bisa dibuat langsung
  dari lembar yang sama ("Koleksi baru…", atau sub-koleksi di dalam koleksi
  yang ada).

- **Penghapus pena** yang membuang goresan utuh, termasuk coretan yang sudah
  tersimpan, dan bisa diurungkan.
- **Urungkan dan ulangi** untuk semua perubahan anotasi dan goresan, dengan
  Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y di desktop. **Tinta putih dan hitam** di palet pena.

## Menyajikan

- **Mode menyajikan**: satu halaman penuh layar, tanpa halaman tetangga yang
  menyembul. Ganti halaman lewat ketuk tepi kiri/kanan, geser ke samping, atau
  tombol. Tiap halaman dipaskan ke layar; gulir bebas dimatikan supaya
  halamannya tidak tergeser setengah karena tersenggol.
- **Bilah bawah** berisi semua yang diperlukan tanpa keluar dari mode: halaman
  sebelumnya/berikutnya, perkecil, perbesar, pas ke layar, pena, urungkan,
  stylus saja, simpan, tambah lembar kosong, dan keluar. Ditaruh di bawah
  karena bagian atas layar dipakai lubang kamera dan bilah status, yang
  mengambil sentuhan.
- **Coret-coret saat menjelaskan**: saat pena aktif, bilah bawah berganti
  menjadi tebal, warna, urungkan goresan terakhir, buang, stylus saja, dan
  **Selesai**. Ketuk tepi tidak mengganti halaman selama pena aktif, supaya
  satu coretan tidak berubah jadi pindah halaman; tombol halaman tetap bisa.
- **Lembar kosong dari dalam mode menyajikan**, langsung bisa dicoreti.
- **Menyimpan dari dalam mode menyajikan**, karena coretan yang dibuat saat
  menjelaskan sering yang paling berharga. Goresan yang belum selesai ikut
  disimpan lebih dulu.

## Catatan, papan tulis, buku catatan, dan Markdown

- **Bagikan ke aplikasi lain** dari setiap layar dokumen: PDF, Markdown,
  papan tulis, dan buku catatan, juga dari panel berkas dan daftar catatan.
  Papan tulis dan buku catatan dikirim sebagai PDF, karena penerimanya hampir
  pasti tidak punya ReadPaper. Di Linux belum ada lembar bagikan sistem; yang
  muncul adalah letak berkasnya.
- **Jadikan buku catatan** dari pembaca: tiap halaman PDF jadi alas satu
  lembar yang bisa ditulisi, PDF aslinya tidak disentuh.
- **Papan tulis**: lembar bebas dengan lima warna latar, pena berwarna,
  bangun 2D (kotak, bulat, belah ketupat, segitiga, garis, panah), penghapus
  per goresan, dan urungkan. Kertas A4, tegak atau mendatar per lembar.
  Disimpan sebagai PDF di folder kerja, atau langsung sebagai catatan.
- **Buku catatan**: dokumen berlembar yang komponennya tetap bisa disunting —
  tinta, teks, gambar, diagram, bangun, dan penghubung. Tiap komponen bisa
  digeser, diubah ukuran, diputar (menempel ke kelipatan 15°), diubah warna dan
  kepekatannya, dan dihapus. Kertas A5 sampai A1, tegak atau mendatar, per
  lembar.
- **Penghubung** antar benda di buku catatan menyimpan rujukan kedua ujungnya,
  jadi garisnya ikut ketika bendanya digeser.
- **Dua penghapus**: per goresan, dan sebagian (memotong bagian yang dilewati).
- **Kotak pilih** untuk menghapus beberapa benda sekaligus.
- **Zum dua jari** dan tombol perkecil/perbesar/pas ke layar; di mode "Stylus
  saja" tangan sama sekali tidak menyentuh kanvas.
- **Halaman PDF sebagai lembar catatan**: sisipkan halaman sebuah PDF sebagai
  alas lembar, lalu tulisi di atasnya.
- **Format sendiri yang bisa dibuka lagi**: `<nama>.catatan.json`, JSON biasa
  supaya diff git-nya terbaca. Bisa juga disimpan sebagai Markdown (tinta jadi
  gambar PNG) atau PDF (tinta jadi garis vektor).
- **Penyunting Markdown** dengan tiga tampilan (sunting, pratinjau, keduanya),
  tombol sisip untuk tajuk, tebal, miring, daftar, daftar tugas, kutipan, kode,
  tabel, dan diagram.
- **Diagram Mermaid** digambar sendiri oleh aplikasi, tanpa jaringan. Yang
  dikenali `graph` dan `flowchart`; jenis lain ditampilkan sebagai kode apa
  adanya dengan keterangan. Mengetuk diagram di pratinjau memindahkan kursor ke
  sumbernya.
- **Markdown ke PDF** dengan teks sungguhan (bisa dicari dan disalin), dan
  **PDF ke Markdown** yang menebak tajuk, paragraf, dan daftar dari tata letak.
  PDF hasil pindaian dikatakan tidak punya lapisan teks.
- **Catatan lepas di akar Catatan**: buku catatan baru, catatan Markdown baru,
  atau berkas apa pun (PDF, gambar, Markdown) ditambahkan dari berkas atau
  diseret dari panel berkas. Gambar bisa dibuka, diperbesar, dan dibagikan.

## Berkas

- **Panel berkas** di bawah pohon koleksi, menjelajahi **folder kerja**
  ReadPaper. Folder kerja berada di luar repositori: isinya tidak ikut
  tersinkron sampai diseret ke sebuah koleksi.
- **Buat baru**: papan tulis, buku catatan, berkas Markdown, atau folder.
- **Salin berkas ke sini** dari mana pun di perangkat. Di Android ini jalan
  utama, karena Android menolak memberi akses ke folder seperti `Download`
  lewat pemilih folder.
- **Ganti nama dan hapus berkas**, masuk dan keluar folder, buka folder kerja
  lain.
- **Seret ke koleksi**: PDF yang dilepas di koleksi paper menjadi item Zotero
  di koleksi itu; berkas apa pun yang dilepas di akar Catatan menjadi catatan.
  Lepasan yang tidak pantas ditolak dengan alasannya — misalnya berkas
  bukan-PDF di akar paper.
- **Panel bisa dilipat** ketika tidak sedang memasukkan berkas.

## Sitasi

- **Sitasi di Word dan OnlyOffice.** ReadPaper desktop menjalankan server
  lokal bertoken (`127.0.0.1:23121`). Add-in Word dan plugin OnlyOffice 9.0+
  mencari paper di library, termasuk anotasinya sebagai penanda halaman. Sitasi
  dan daftar pustaka dirender citeproc-js, mesin yang sama dengan Zotero, dengan
  gaya yang dibundel (APA, Vancouver, IEEE, Harvard, dan lainnya). Daftar pustaka
  selalu dibangun ulang dari sitasi yang ada di dokumen, dan data sitasinya
  ikut tersimpan di dokumen. Rinciannya di `docs/api-sitasi.md` dan
  `integrations/README.md`.

## Sinkronisasi

- **Profil repositori**: beberapa repositori bisa didaftarkan dan dipindah kapan
  saja. Tiap profil punya folder sendiri, jadi berpindah tidak mengunduh ulang.
- **Ambil library**: hanya metadata yang diunduh di awal (pada library 1.740
  item, sekitar 23 MB di desktop dan 19 MB di Android); PDF menyusul saat
  dibuka. Unduhan yang terputus bisa dilanjutkan dari tempatnya berhenti.
- **Periksa, tarik, kirim**: tiga tombol di bilah atas (di layar sempit, satu
  menu). Lencana menunjukkan berapa commit baru di GitHub dan berapa perubahan
  lokal yang menunggu.
- **Satu perubahan, satu commit.** Setiap anotasi, koleksi baru, atau catatan
  yang disimpan langsung di-commit dengan pesan yang terbaca. Pilihan **Push
  otomatis setelah menyimpan anotasi** di profil mengirimnya seketika.
- **Detail sinkronisasi**: daftar perubahan lokal, riwayat commit, dan log
  mentah, untuk menjawab "macet atau jaringan putus?".
- **Pesan galat yang bisa ditindaklanjuti**: token kurang izin, kuota habis,
  branch sudah bergerak, berkas terlalu besar — masing-masing dengan pesan
  sendiri, bukan satu pesan umum.
- **Berkas yang ditolak GitHub disisihkan**, tidak menahan yang lain. Yang
  ditolak tetap menunggu di antrean dengan nama dan alasannya.
- **Tidak pernah memaksa.** Kalau GitHub sudah punya commit lebih baru,
  pengiriman ditolak dan diminta menarik dulu.

## Platform

| | Android (tablet/ponsel) | Linux | Windows |
|---|---|---|---|
| Bentuk | APK arm64 | `.tar.gz`, `.deb`, `PKGBUILD` | zip portabel |
| Sinkronisasi | GitHub REST API, tanpa git | `git` sistem | `git` sistem |
| Akses | HTTPS + token saja | SSH atau HTTPS + token | SSH atau HTTPS + token |
| PDF lampiran ke GitHub | **tidak dikirim** | dikirim lewat git | dikirim lewat git |
| Git LFS | belum | ya, kalau `git-lfs` terpasang | ya, kalau `git-lfs` terpasang |
| Simpan PDF | Simpan sebagai ke folder kerja/dialog, lalu Simpan menimpa hasilnya | Simpan sebagai ke folder mana pun, lalu Simpan menimpa hasilnya | sama dengan Linux |
| Tempel gambar dari papan klip | ya | ya (`wl-paste` atau `xclip`) | ya |

Yang paling penting dari tabel itu: **di Android, lampiran PDF tidak pernah
dikirim ke GitHub.** Berkas di `attachments-lfs/` disimpan di repositori sebagai
penunjuk LFS, dan mengirim PDF-nya lewat API akan merusak LFS repositori;
berkas di `attachments/` sering puluhan megabita dan ditolak API. Anotasi,
koleksi, item baru, dan catatan tetap terkirim dari Android. PDF-nya sendiri
harus masuk lewat git di komputer.

Windows dibangun di runner GitHub Actions dan belum ditandatangani, jadi
SmartScreen memperingatkan saat dibuka. macOS belum ada.

iPhone dan iPad sedang disiapkan: runner macOS di GitHub Actions membangun
`.ipa` yang belum ditandatangani, yang dipasang sendiri dengan Apple ID gratis
lewat Sideloadly atau AltStore (lihat bagian iOS di
[panduan-teknis.md](panduan-teknis.md)). Sinkronisasinya sama dengan Android,
lewat GitHub REST API. Belum pernah dicoba di perangkat sungguhan.

---

## Batasan yang diketahui

Diringkas dari butir yang belum selesai di [backlog.md](backlog.md):

- **Konflik merge** belum dibantu; yang muncul hanya pesan galat git.
- **Tidak ada fetch otomatis** di latar belakang; periksa perubahan dengan
  tangan.
- **Pengiriman yang terputus mengulang dari awal** — blob yang sudah terunggah
  belum diingat.
- **Mirror pertama di Android** memakan sekitar 3.500 permintaan API untuk
  library 1.740 item, mendekati kuota GitHub 5.000 per jam.
- **Token di Android** disimpan di berkas privat aplikasi, belum di keystore.
  APK masih ditandatangani dengan kunci debug.
- **Belum ada pencarian teks di dalam PDF**, panel thumbnail halaman, atau
  tingkat zum yang tersimpan per paper.
- **Pena di pembaca belum punya penghapus**; coretan dibuang lewat urungkan,
  buang, atau panel anotasi.
- **Salin teks tidak bisa selama mode Tandai aktif** — matikan dulu.
- **Mengganti nama dan menghapus koleksi paper** belum ada; membuat sudah.
- **Penggabungan duplikat** sengaja tidak dikerjakan.
- **PDF hasil simpan tidak punya lapisan teks**, dan teks yang sudah ditaruh di
  halaman harus dihapus lalu dibuat ulang untuk diubah.
- **Tanda tangan belum bisa disimpan** untuk dipakai ulang.
- **Tulisan tangan belum bisa diubah jadi teks** (Fase 14–15).
- **EPUB belum bisa distabilo.** Bukunya bisa dibaca, tetapi anotasi EPUB
  Zotero (penanda CFI) belum ditulis. Format ebook lain (MOBI, DjVu) belum
  bisa dibuka.
- **Antarmuka hanya bahasa Indonesia** (dwibahasa di Fase 8).
- **Sitasi ke Word/LibreOffice/OnlyOffice/Google Docs** sedang dikerjakan;
  mesinnya belum selesai (Fase 9–10).
