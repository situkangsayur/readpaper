# Inti sitasi bersama

Kode di folder ini dipakai apa adanya oleh plugin OnlyOffice
(`../onlyoffice/`) dan add-in Word (`../word/`). Tanpa bundler: setiap berkas
adalah `<script>` biasa yang memasang satu global, sekaligus modul CommonJS
untuk uji Node.

| Berkas | Global | Isi |
|---|---|---|
| `vendor/citeproc.js` | `CSL` | citeproc-js, mesin sitasi Zotero |
| `citations.js` | `ReadPaperCitations` | bentuk data kontrak, tag, custom XML, menjalankan citeproc, HTML → run berformat |
| `readpaper-api.js` | `ReadPaperApi` | pemanggil server `127.0.0.1:23121`, token, cache gaya/locale |
| `controller.js` | `ReadPaperController` | semua perintah (sisip, sunting, perbarui semua, daftar pustaka, gaya, tanpa disitasi, teks biasa) di atas "adapter" editor |
| `ui.js`, `ui.css` | `ReadPaperUI` | panel berbahasa Indonesia |

Urutan memuatnya: `vendor/citeproc.js`, `citations.js`, `readpaper-api.js`,
`controller.js`, `ui.js`.

## citeproc-js

- Versi: **citeproc 2.4.63** dari npm (`CSL.PROCESSOR_VERSION` 1.4.61), paket
  resmi citeproc-js oleh Frank Bennett. Versinya juga tercatat di
  `vendor/CITEPROC_VERSION`.
- Paket npm hanya membawa `citeproc_commonjs.js`. Satu-satunya perubahan:
  baris terakhir `module.exports = CSL` dibungkus pengecekan `typeof module`
  supaya berkas yang sama bisa dimuat di peramban. Selebihnya byte demi byte
  sama.
- Diperbarui dengan `scripts/vendor-citeproc.sh [versi]`.
- Lisensi: CPAL-1.0 atau AGPL-3.0 (pilih salah satu), lihat
  `vendor/LICENSE-citeproc.txt`. ReadPaper memakainya di bawah AGPL.

## Uji

```sh
cd integrations
npm ci
npm test
```

Uji memakai gaya dan locale CSL asli dari `assets/csl/`, jadi keluaran yang
diuji sama dengan yang dikirim server ReadPaper.
