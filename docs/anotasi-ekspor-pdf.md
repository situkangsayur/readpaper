# Ekspor komentar & menggabungkannya kembali ke PDF

Status: rencana. Bagian dari Fase 5 di [backlog](backlog.md).

Yang diminta: komentar dan saran bisa diekspor, PDF lama bisa digabung dengan
komentar baru, dan hasilnya **bisa dimuat lagi nanti** — jadi formatnya harus
benar, entah ditaruh sebagai catatan kaki atau di halaman tambahan.

Syarat "bisa dimuat lagi" itu yang menentukan semua keputusan di bawah.

---

## Masalahnya

Ada dua kebutuhan yang saling tarik-menarik:

1. **Bisa dibaca siapa saja.** Orang yang menerima PDF-nya belum tentu punya
   ReadPaper. Komentarnya harus terlihat di Acrobat, di Preview macOS, di
   pembaca PDF ponsel, dan saat dicetak.
2. **Bisa dimuat lagi tanpa kehilangan apa pun.** Warna persis, kunci Zotero,
   `dateAdded`, `sortIndex`, teks terkutip apa adanya. Kalau satu saja hilang,
   memuat ulang lalu menyimpan akan merusak library.

Menulis komentar sebagai teks biasa di halaman memenuhi syarat 1 dan gagal
total di syarat 2 — teks tidak bisa diurai balik menjadi anotasi dengan
kunci dan tanggal yang sama.

## Keputusan: tiga lapis dalam satu berkas

Satu PDF hasil ekspor berisi tiga hal sekaligus. Ketiganya dibuat dari sumber
yang sama, jadi tidak mungkin berbeda isi.

### Lapis 1 — Anotasi PDF sungguhan

Setiap stabilo, garis bawah, coretan, dan catatan ditulis sebagai anotasi PDF
asli lewat PDFium:

| Anotasi ReadPaper | Subtype PDF |
|---|---|
| Stabilo | `/Highlight` |
| Garis bawah | `/Underline` |
| Coretan bebas | `/Ink` |
| Catatan di halaman | `/Text` (ikon catatan) dengan `/Popup` |
| Komentar pada stabilo | `/Contents` pada anotasi stabilonya |

Ini yang membuat komentarnya terlihat di pembaca PDF mana pun, lengkap dengan
warnanya, tanpa mengubah halaman aslinya sedikit pun. `/T` (penulis) diisi
nama dari profil, `/CreationDate` dan `/M` diisi dari `dateAdded` dan
`dateModified` Zotero.

### Lapis 2 — Lampiran JSON di dalam PDF

PDF bisa membawa berkas di dalamnya (*embedded file attachment*). Di situ
ditaruh `readpaper-annotations.json`: **anotasi Zotero apa adanya**, format
yang sama persis dengan yang ditulis ke library.

Ini yang menjawab "bisa dimuat lagi". ReadPaper membaca lampiran itu, bukan
menebak-nebak dari anotasi PDF. Tidak ada yang hilang karena tidak ada yang
diterjemahkan.

Kalau lampirannya tidak ada — misalnya PDF-nya dianotasi orang lain di
Acrobat — ReadPaper jatuh ke lapis 1 dan mengurai anotasi PDF-nya, dengan
konsekuensi: kunci Zotero dibuat baru, dan `sortIndex` dihitung ulang.

Versi format ditulis di dalam JSON-nya (`"readpaperFormat": 1`) supaya berkas
lama tetap bisa dibuka setelah formatnya berkembang.

### Lapis 3 — Halaman lampiran "Catatan"

Halaman tambahan **di belakang** dokumen, berisi daftar bernomor semua
komentar: nomor halaman, kutipan teks yang ditandai, warna, penulis, tanggal,
dan isi komentarnya.

Gunanya untuk dibaca dan dicetak. Setiap butir diberi tautan balik ke posisi
aslinya, dan di halaman aslinya diberi penanda kecil bernomor di margin.

**Kenapa halaman belakang, bukan catatan kaki di halaman yang sama:** PDF
tidak punya konsep catatan kaki. Menaruh teks di bagian bawah halaman berarti
menimpa apa pun yang sudah ada di sana — dan pada paper dua kolom yang padat,
itu hampir pasti menutupi isi. Halaman lampiran tidak pernah merusak apa pun.

Catatan margin sebagai pilihan tambahan tetap masuk akal untuk paper yang
marginnya lebar, dan dicatat sebagai opsi, bukan bawaan.

---

## Mode penyimpanan

| Mode | Hasil | Berkas asli |
|---|---|---|
| **Simpan sebagai baru** | `<nama>.annotated.pdf` | Tidak disentuh |
| **Resave** | Menimpa berkas yang sama | Disalin dulu ke `<nama>.orig.pdf` sebelum ditimpa |
| **Ekspor rata (flatten)** | Anotasi digambar menjadi bagian halaman | Untuk dikirim ke orang yang pembacanya tidak menampilkan anotasi. **Tidak bisa dimuat balik** — harus dikatakan jelas di dialognya |

---

## Menggabungkan komentar baru ke PDF yang sudah pernah diekspor

Ini alur yang paling mudah merusak data, jadi aturannya tegas:

1. Baca `readpaper-annotations.json` dari PDF tujuan
2. Cocokkan dengan anotasi di library **berdasarkan kunci Zotero**, bukan
   posisi
3. Untuk tiap kunci: yang `dateModified`-nya lebih baru yang menang
4. Kunci yang hanya ada di satu sisi ikut masuk
5. Kunci yang **hilang** dari library tidak otomatis dihapus dari PDF —
   tampilkan dan minta keputusan. Menghapus catatan orang diam-diam jauh
   lebih buruk daripada menyisakan satu catatan basi
6. Tulis ulang ketiga lapisnya dari hasil gabungan, jangan menambal

Karena pencocokannya lewat kunci, menggabungkan berkali-kali tidak pernah
menghasilkan komentar ganda.

---

## Ekspor tanpa PDF

Untuk dibaca di luar, komentar dan saran juga bisa diekspor sebagai:

- **Markdown** — satu berkas per paper, dikelompokkan per halaman; formatnya
  sama dengan catatan yang ditulis `zotero-github-sync`, jadi bisa langsung
  masuk library sebagai catatan
- **CSV** — halaman, jenis, warna, kutipan, komentar, tanggal
- **JSON** — isi yang sama dengan lampiran lapis 2, untuk dipakai alat lain

---

## Saran dari plugin (Fase 12)

Saran dari AI Detector dan Humanizer **bukan** anotasi Zotero dan tidak boleh
ikut tertulis ke library. Saran disimpan terpisah, dan:

- Saat diekspor ke PDF, saran ditulis sebagai anotasi `/Text` dengan penulis
  bernama plugin yang membuatnya, dan **selalu** masuk ke halaman lampiran
  dengan label yang jelas bahwa itu usulan mesin, bukan catatan penulis
- Di JSON lapis 2 ditaruh di bagian `"suggestions"`, terpisah dari
  `"annotations"`, supaya pemuatan ulang tidak pernah salah mengira saran
  sebagai anotasi yang dibuat manusia

---

## Yang perlu diuji sebelum dianggap selesai

- [ ] PDF hasil ekspor dibuka di Acrobat, Preview macOS, Okular, dan pembaca
      PDF bawaan Android — anotasi terlihat, warnanya benar
- [ ] Ekspor lalu muat lagi menghasilkan anotasi yang **byte-for-byte sama**
      saat ditulis balik ke library
- [ ] Gabung dua kali berturut-turut tidak menggandakan apa pun
- [ ] PDF 400 halaman dengan 500 anotasi selesai dalam waktu wajar di ponsel
- [ ] PDF hasil ekspor yang dianotasi lagi di Acrobat masih bisa dimuat
