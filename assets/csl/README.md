# Gaya dan locale CSL

Berkas di folder ini **bukan** karya ReadPaper. Semuanya diambil apa adanya
dari proyek [Citation Style Language](https://citationstyles.org/), sumber yang
sama yang dipakai Zotero dan Mendeley. Itu disengaja: daftar pustaka yang
dibuat ReadPaper harus sama persis dengan yang dibuat Zotero dari item yang
sama, karena orang yang sama akan membandingkan keduanya.

## Lisensi

Gaya dan locale CSL berlisensi
[Creative Commons Attribution-ShareAlike 3.0](https://creativecommons.org/licenses/by-sa/3.0/),
terpisah dari lisensi AGPL-3.0-or-later milik ReadPaper sendiri. Tiap berkas
`.csl` menyebutkan penulis dan lisensinya di dalam blok `<info>`-nya.

## Isi

`styles/` — gaya sitasi, diambil dari
<https://github.com/citation-style-language/styles>:

| Berkas | Dipakai untuk |
|---|---|
| `ieee.csl` | Teknik dan informatika; bernomor, `[1]` |
| `vancouver.csl` | Kedokteran dan kesehatan; bernomor. Diambil dari <https://www.zotero.org/styles/vancouver> — di repositori gaya ia dibangun oleh generator, jadi tidak ada sebagai berkas sendiri |
| `american-medical-association.csl` | AMA, kedokteran; bernomor superskrip |
| `apa.csl` | Psikologi dan ilmu sosial; pengarang-tahun |
| `harvard-cite-them-right.csl` | Harvard; pengarang-tahun |
| `chicago-author-date.csl` | Chicago; pengarang-tahun |
| `modern-language-association.csl` | MLA, humaniora; pengarang-halaman |

`locales/` — istilah dan bentuk tanggal per bahasa, diambil dari
<https://github.com/citation-style-language/locales>:

| Berkas | Isi |
|---|---|
| `locales-en-US.xml` | "et al.", "in", "edition", nama bulan Inggris |
| `locales-id-ID.xml` | "dkk.", "dalam", "edisi", nama bulan Indonesia |

## Memperbarui

Gaya CSL berubah ketika penerbitnya mengubah aturan. Mengambil versi baru
cukup mengunduh ulang berkasnya; tidak ada yang perlu disunting di sini, dan
**tidak boleh** ada yang disunting — gaya yang ditambal sendiri akan
menghasilkan daftar pustaka yang berbeda dari Zotero, dan itu persis yang
hendak dihindari. Kalau sebuah gaya salah, perbaikannya dikirim ke hulu.
