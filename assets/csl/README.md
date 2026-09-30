# Gaya dan locale CSL

Berkas di folder ini **bukan** karya ReadPaper. Semuanya diambil apa adanya
dari proyek [Citation Style Language](https://citationstyles.org/), sumber yang
sama yang dipakai Zotero dan Mendeley. Itu disengaja: daftar pustaka yang
dibuat ReadPaper harus sama persis dengan yang dibuat Zotero dari item yang
sama, karena orang yang sama akan membandingkan keduanya.

`styles.json` adalah daftarnya, dan ia **ditulis oleh perkakas, bukan tangan**.

## Menambah gaya

```sh
scripts/csl-style.py add ieee apa vancouver-nlm   # id-nya, bukan nama berkas
scripts/csl-style.py update                        # ambil ulang semua
scripts/csl-style.py list
scripts/csl-style.py check                         # tanpa jaringan
```

Yang disebut adalah **id gaya** di repositori resmi — nama file tanpa `.csl` —
dan perkakasnya yang memutuskan sisanya: mencarinya sebagai gaya independen
lalu sebagai gaya dependen, membaca `<info>`-nya, menyimpannya dengan nama
sesuai id **di dalam berkasnya**, dan mengambil induknya kalau ia dependen.

`scripts/csl-style.py check` juga dijalankan sebagai uji Dart
(`test/csl_catalog_test.dart`), jadi daftar yang rusak ketahuan di `flutter
test`, bukan saat seseorang memilih gaya di tengah menulis.

## Dua jenis gaya, dan kenapa itu penting

Gaya CSL tidak selalu berisi aturannya sendiri:

- **Independen** — berisi seluruh aturan sitasi dan daftar pustakanya.
- **Dependen** — hanya nama beserta penunjuk ke induknya. Sendirian ia tidak
  bisa merender apa pun.

Gaya dependen tetap ditawarkan ke penulis dengan namanya sendiri, karena itu
nama yang dicari orang; yang dipakai merender adalah aturan induknya.

## Vancouver: ada dua, dan tidak ada yang bernama "vancouver"

Ini jebakan yang nyata, dan sudah hampir membuat ReadPaper membawa berkas yang
isinya bukan yang tertulis di namanya.

Di repositori resmi **tidak ada** `vancouver.csl`. Yang ada dua gaya dependen:

| Id | Judul | Induknya |
|---|---|---|
| `vancouver-nlm` | Vancouver - NLM (citation-sequence) | `nlm-citation-sequence` |
| `vancouver-ama` | Vancouver - AMA | `american-medical-association` |

Dan `https://www.zotero.org/styles/vancouver` **mengalihkan diam-diam** ke
`nlm-citation-sequence`. Mengunduhnya dengan `curl -L` lalu menyimpannya
sebagai `vancouver.csl` menghasilkan berkas yang ber-id
`nlm-citation-sequence` tetapi bernama `vancouver` — persis kelas kesalahan
yang paling sulit ditemukan nanti, karena semuanya tampak benar sampai
daftar pustakanya dibandingkan dengan Zotero.

Karena itu `csl-style.py` menamai berkasnya menurut id di dalam berkasnya,
bukan menurut nama yang diketik, dan mengatakannya kalau keduanya berbeda.

## Lisensi

Gaya dan locale CSL berlisensi
[Creative Commons Attribution-ShareAlike 3.0](https://creativecommons.org/licenses/by-sa/3.0/),
terpisah dari lisensi AGPL-3.0-or-later milik ReadPaper sendiri. Tiap berkas
`.csl` menyebutkan penulis dan lisensinya di dalam blok `<info>`-nya.

Isi gayanya **tidak boleh disunting**. Gaya yang ditambal sendiri akan
menghasilkan daftar pustaka yang berbeda dari Zotero, yaitu persis yang hendak
dihindari. Kalau sebuah gaya salah, perbaikannya dikirim ke hulu.

## Isi sekarang

Jalankan `scripts/csl-style.py list` untuk daftar yang sebenarnya. Saat
ditulis: IEEE, APA, Harvard (Cite Them Right), Chicago author-date, MLA, AMA,
NLM/Vancouver citation-sequence, beserta dua gaya Vancouver di atas; locale
Indonesia dan Inggris.
