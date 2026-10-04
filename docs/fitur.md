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
- **Menghapus dokumen dari library**, dari bagian paling bawah panel detail,
  dengan konfirmasi. Pasangan dari "tambahkan ke koleksi": yang masuk karena
  salah pencet bisa dicabut lagi.

## Membaca

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
  (di Android) lewat "Buka dengan" dari aplikasi lain. PDF seperti ini disebut
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
- **Simpan dan bagikan**: simpan PDF beranotasi (ke folder kerja, atau tempat
  lain lewat dialog sistem), simpan halaman sebagai PNG/JPG pada 72/144/288
  dpi, cetak, bagikan ke aplikasi lain, atau ubah teks PDF menjadi Markdown.
  PDF hasil simpan berisi halaman sebagai gambar, jadi teksnya tidak lagi bisa
  dicari — berkas asli tetap ada.
- **Tambahkan ke koleksi** untuk PDF lepas: berkasnya disalin ke library,
  dibuatkan item Zotero, dan di-commit. Koleksi tujuan bisa dibuat langsung
  dari lembar yang sama ("Koleksi baru…", atau sub-koleksi di dalam koleksi
  yang ada).

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
| Simpan ke berkas yang sama | tidak (selalu lewat folder kerja/dialog) | ya, aslinya disalin dulu | ya, aslinya disalin dulu |

Yang paling penting dari tabel itu: **di Android, lampiran PDF tidak pernah
dikirim ke GitHub.** Berkas di `attachments-lfs/` disimpan di repositori sebagai
penunjuk LFS, dan mengirim PDF-nya lewat API akan merusak LFS repositori;
berkas di `attachments/` sering puluhan megabita dan ditolak API. Anotasi,
koleksi, item baru, dan catatan tetap terkirim dari Android. PDF-nya sendiri
harus masuk lewat git di komputer.

Windows dibangun di runner GitHub Actions dan belum ditandatangani, jadi
SmartScreen memperingatkan saat dibuka. macOS dan iOS belum ada.

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
- **EPUB dan format lain** belum bisa dibaca; hanya PDF.
- **Antarmuka hanya bahasa Indonesia** (dwibahasa di Fase 8).
- **Sitasi ke Word/LibreOffice/OnlyOffice/Google Docs** sedang dikerjakan;
  mesinnya belum selesai (Fase 9–10).
