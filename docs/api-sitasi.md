# Sitasi di Word dan OnlyOffice — kontrak

Dokumen ini mengikat tiga bagian yang dikerjakan terpisah: **server lokal di
ReadPaper desktop**, **plugin OnlyOffice**, dan **add-in Microsoft Word**.
Ketiganya harus bisa diganti tanpa menyentuh yang lain selama kontrak ini
dipegang.

## Rancangan singkat

```
 Word / OnlyOffice                         ReadPaper desktop
 ┌──────────────────────────────┐          ┌──────────────────────────┐
 │ add-in / plugin (JavaScript) │  HTTP    │ server lokal 127.0.0.1   │
 │  ├─ citeproc-js  ◄───────────┼─ gaya ───┤  ├─ cari item            │
 │  ├─ inti ReadPaper (sama)    │  locale  │  ├─ CSL-JSON item        │
 │  └─ lapisan editor           │  item    │  ├─ anotasi (lokator)    │
 └──────────────────────────────┘          │  └─ gaya & locale CSL    │
                                           └──────────────────────────┘
```

- **Mesin sitasinya citeproc-js**, berjalan di dalam add-in. Itu mesin yang
  dipakai Zotero sendiri, sehingga sitasi dan daftar pustaka dari ReadPaper sama
  persis dengan buatan Zotero untuk item yang sama — syarat yang sudah ditulis
  di `assets/csl/README.md`.
- **ReadPaper hanya menyediakan data**: mencari item, CSL-JSON-nya, anotasinya,
  dan berkas gaya serta locale yang sudah dibundel.
- **Dokumen menyimpan sitasinya sendiri**, lengkap dengan salinan data item.
  Dokumen tetap bisa dibuka, dan sitasinya diperbarui ulang, tanpa ReadPaper
  berjalan — gaya terakhir dan data item ada di dalamnya.

## Dua aturan dari backlog Fase 10

1. **Daftar pustaka diturunkan dari dokumen, tidak pernah ditimbun.** Setiap
   kali diperbarui, seluruh dokumen dipindai, semua sitasi dikumpulkan sesuai
   urutan kemunculannya, dan daftar pustaka dibuat **hanya** dari yang
   ditemukan. Tidak ada daftar "item yang disitasi" di luar sitasi itu sendiri.
   Pengecualiannya satu: item yang sengaja dimasukkan tanpa disitasi, dan
   catatannya disimpan di dalam dokumen.
2. **Menyisipkan sitasi harus ringan.** Dialog siap diketik dalam sepersekian
   detik, pencarian berjalan sambil mengetik, dan menyisipkan satu sitasi tidak
   menunggu seluruh dokumen dibangun ulang. Membangun ulang daftar pustaka
   adalah perintah tersendiri.

## Server lokal

- Alamat: `http://127.0.0.1:23121` (Zotero memakai 23119; yang ini sengaja
  berbeda supaya keduanya bisa berjalan bersamaan). Hanya mendengarkan di
  `127.0.0.1`, tidak pernah di semua antarmuka.
- Hanya di **desktop** (Linux, Windows, macOS). Android dan iOS tidak punya
  Word atau OnlyOffice desktop yang bisa memakainya.
- **Token**: dibuat acak sekali per pemasangan, disimpan di `credentials.json`,
  ditampilkan di pengaturan ReadPaper untuk disalin ke add-in. Bisa dibuat
  ulang. Setiap permintaan kecuali `GET /api/ping` wajib membawa
  `Authorization: Bearer <token>`; tanpa itu `401`.
  Alasannya: tanpa token, situs web mana pun yang dibuka di peramban yang sama
  bisa membaca library seseorang lewat `127.0.0.1`.
- **CORS**: `Access-Control-Allow-Origin` memantulkan `Origin` permintaan,
  `Access-Control-Allow-Headers: Authorization, Content-Type`,
  `Access-Control-Allow-Methods: GET, POST, OPTIONS`, dan untuk preflight juga
  `Access-Control-Allow-Private-Network: true` (Chromium meminta itu sebelum
  halaman https boleh memanggil alamat lokal). Token yang menjaga, bukan CORS.
- Semua jawaban JSON berkodekan UTF-8, kecuali gaya dan locale (XML).
- Galat: `{"error": "<pesan berbahasa Indonesia>"}` dengan kode HTTP yang
  sesuai (`400`, `401`, `404`, `500`).

### Endpoint

`GET /api/ping` — tanpa token.
```json
{"app": "ReadPaper", "version": "0.25.0", "api": 1, "library": "My Library"}
```
`library` adalah nama library yang sedang terbuka, atau `null`.

`GET /api/search?q=<teks>&limit=<n>` — cari di library yang sedang terbuka:
judul, nama pengarang, tahun, abstrak. Tanpa `q`, item terbaru. `limit`
bawaan 25, paling banyak 100.
```json
{"items": [
  {"key": "2T4TVLLZ", "title": "Barren plateaus in ...", "creators": "McClean, Boixo, Smelyanskiy dkk.",
   "year": "2018", "type": "journalArticle", "collections": ["PhD/QML"], "annotationCount": 3}
]}
```

`POST /api/items` dengan `{"keys": ["2T4TVLLZ", ...]}` — CSL-JSON tiap item,
dibuat oleh `CslJson.of`. `id` setiap item sama dengan kuncinya.
```json
{"items": [{"id": "2T4TVLLZ", "type": "article-journal", "title": "...", "author": [...], "issued": {...}}],
 "missing": []}
```

`GET /api/items/<key>/annotations` — anotasi sebuah item, untuk memilih bagian
yang disitasi:
```json
{"annotations": [
  {"key": "AB12CD34", "type": "highlight", "color": "#ffd400", "text": "...",
   "comment": "...", "pageLabel": "12"}
]}
```

`GET /api/styles` — gaya yang dibundel, dari `assets/csl/styles.json`:
```json
{"styles": [{"id": "vancouver-nlm", "title": "Vancouver - NLM (citation-sequence)",
             "kind": "independent", "format": "numeric", "parent": null}]}
```

`GET /api/styles/<id>` — XML gaya itu (`application/xml`). Untuk gaya dependen
yang dikirim adalah **gaya induknya**, karena citeproc-js butuh gaya independen.

`GET /api/locales/<tag>` — XML locale (`id-ID`, `en-US`). Tag yang tidak ada
dijawab dengan `en-US`, bukan `404`: sitasi tanpa locale lebih buruk daripada
sitasi berbahasa Inggris.

## Data di dalam dokumen

Bentuknya sama untuk Word dan OnlyOffice. Bagaimana menyimpannya mengikuti
kemampuan masing-masing editor (lihat bagian editor di bawah).

**Sitasi** — satu content control per sitasi:
```json
{"v": 1, "id": "c-7f3a9b", "items": [
  {"key": "2T4TVLLZ", "itemData": { /* CSL-JSON lengkap */ },
   "locator": "12-14", "label": "page", "prefix": "lihat", "suffix": "",
   "suppressAuthor": false, "annotationKey": "AB12CD34"}
 ],
 "noBib": false}
```
- `itemData` adalah salinan, supaya dokumen bisa diperbarui tanpa ReadPaper.
  Saat ReadPaper tersedia, perintah "perbarui" mengambil data terbaru.
- `annotationKey` mencatat anotasi yang dipilih sebagai bookmark sitasi,
  bila ada. Lokatornya diisi dari `pageLabel` anotasi itu.
- `noBib: true` = sitasi ini tidak memasukkan itemnya ke daftar pustaka.

**Daftar pustaka** — satu content control, tempat daftar pustaka dibangun.

**Pengaturan dokumen**:
```json
{"v": 1, "style": "vancouver-nlm", "locale": "id-ID",
 "uncited": [{"key": "...", "itemData": { /* CSL-JSON */ }}]}
```
`uncited` adalah item yang sengaja masuk daftar pustaka tanpa disitasi.

## Perintah di add-in

Sama di kedua editor:

- **Sisipkan sitasi** — cari (judul/pengarang/abstrak), pilih satu atau
  beberapa item, opsional pilih anotasi sebagai bookmark atau isi halaman,
  prefiks/sufiks, sembunyikan pengarang. Sitasi disisipkan dengan nomor atau
  teks sementara yang dihitung dari sitasi yang sudah ada; tidak menunggu
  pembangunan ulang.
- **Sunting sitasi** — kursor di dalam sebuah sitasi.
- **Daftar pustaka** — sisipkan di posisi kursor, atau bangun ulang.
- **Perbarui semua** — pindai dokumen, render ulang semua sitasi dan daftar
  pustaka sesuai urutan kemunculan (gaya bernomor jadi berurutan lagi).
- **Gaya** — pilih dari `/api/styles`, lalu perbarui semua.
- **Tambah ke daftar pustaka tanpa disitasi** dan kebalikannya.
- **Jadikan teks biasa** — buang semua content control, tinggalkan teksnya.

## Pemetaan ke editor

- **OnlyOffice** — plugin (`config.json` + HTML/JS) di
  `integrations/onlyoffice/`, dipaket jadi `.plugin`. Sitasi berupa content
  control inline; daftar pustaka berupa content control blok.
- **Microsoft Word** — add-in Office.js (manifest XML + task pane) di
  `integrations/word/`. Halaman task pane harus disajikan lewat **https**;
  disajikan dari GitHub Pages repositori ini. Halaman https boleh memanggil
  `http://127.0.0.1` di Chromium/WebView2 (Word Windows, Word web di Chrome dan
  Edge). Word di macOS memakai Safari/WKWebView, yang perlu diuji tersendiri.
- Kode bersama — pemanggil API, citeproc-js, pengelolaan klaster sitasi dan
  penomoran — ada di `integrations/core/` dan dipakai keduanya apa adanya.
