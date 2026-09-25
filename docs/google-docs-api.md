# Sitasi di Google Docs — cara mendapatkan dan memakai API-nya

Status: rencana. Belum ada kodenya. Bagian dari Fase 10 di [backlog](backlog.md).

## Kenapa Google Docs beda sendiri

LibreOffice, OnlyOffice, dan Word bisa memanggil ReadPaper yang berjalan di
komputer yang sama lewat `127.0.0.1`. Google Docs tidak bisa: add-on Google
Docs ditulis dengan Apps Script, dan Apps Script **berjalan di server Google**,
bukan di komputer pengguna. Dari sana `127.0.0.1` adalah server Google itu
sendiri, bukan mesin Anda. Jadi pola "editor memanggil ReadPaper" tidak
mungkin di Google Docs.

Dua jalan yang tersisa:

| | Cara kerja | Kelebihan | Kekurangan |
|---|---|---|---|
| **A. Ekstensi peramban** | Ekstensi menyuntik tombol ke halaman Google Docs dan menjembatani ke ReadPaper lokal. Ini yang dipakai Zotero. | Tidak perlu izin Google apa pun; dokumen tidak pernah diakses dari luar peramban | Harus dibuat untuk Chrome dan Firefox, ikut aturan toko ekstensi, dan rapuh terhadap perubahan HTML Google Docs |
| **B. Google Docs API langsung dari ReadPaper** | ReadPaper sendiri yang menulis ke dokumen lewat API resmi, dengan izin OAuth dari pengguna | Satu basis kode, API resmi dan stabil, jalan dari desktop maupun Android, suntingan langsung terlihat di dokumen yang sedang dibuka | Perlu proyek Google Cloud, layar izin, dan verifikasi aplikasi kalau mau dipakai umum |

**Usulan: jalan B.** Alasannya bukan karena lebih mudah, tapi karena jalan A
menambah dua produk baru (ekstensi Chrome dan Firefox) yang harus dirawat
terpisah, sementara jalan B memakai API yang memang didukung Google dan bisa
dipakai ulang oleh versi Android.

---

## Bagian 1 — Mendapatkan aksesnya

Semua langkah di bawah gratis. Yang perlu disiapkan: satu akun Google.

### 1. Buat proyek Google Cloud

<https://console.cloud.google.com/> → **Select a project** → **New project**.
Beri nama, misalnya `readpaper`. Tidak perlu menautkan penagihan; Docs API
tidak menagih.

### 2. Nyalakan API-nya

**APIs & Services → Library**, lalu nyalakan:

- **Google Docs API** — membaca dan menyunting isi dokumen
- **Google Drive API** — hanya diperlukan untuk memilih dokumen lewat Picker
  dan membuat dokumen baru

### 3. Isi layar izin (OAuth consent screen)

**APIs & Services → OAuth consent screen**:

- **User type: External** (kecuali semua penggunanya satu organisasi Workspace)
- Nama aplikasi, email dukungan, email pengembang, logo
- Tautan beranda dan **kebijakan privasi** — wajib kalau nanti diajukan
  verifikasi
- **Test users**: selama status masih *Testing*, hanya alamat email yang
  didaftarkan di sini yang bisa memakainya, maksimal 100 akun

### 4. Pilih scope sesempit mungkin

Ini keputusan yang paling berpengaruh ke seberapa repot nanti.

| Scope | Artinya | Akibatnya |
|---|---|---|
| `.../auth/drive.file` | Hanya berkas yang dibuat oleh aplikasi atau yang dipilih pengguna lewat Picker | Dianggap tidak sensitif — **tanpa verifikasi** |
| `.../auth/documents` | Melihat dan menyunting **seluruh** dokumen Google milik pengguna | Sensitif — perlu verifikasi Google sebelum bisa dipakai umum |
| `.../auth/drive` | Seluruh Drive | Restricted — verifikasi paling berat, termasuk asesmen keamanan pihak ketiga |

**Pakai `drive.file`.** Docs API menghormati scope itu untuk dokumen yang
dibuka pengguna lewat Google Picker, dan itu memang persis yang dibutuhkan:
ReadPaper hanya perlu menulis ke dokumen yang sedang ditulis penggunanya, bukan
ke seluruh Drive-nya. Konsekuensinya alurnya harus lewat Picker, bukan daftar
dokumen buatan sendiri.

> Klasifikasi sensitif/restricted sesekali berubah. **Konfirmasi ulang di
> layar consent screen saat mendaftar** — di sana tiap scope diberi label.

### 5. Buat OAuth client ID

**APIs & Services → Credentials → Create credentials → OAuth client ID**.
Buat satu per platform:

- **Desktop app** — untuk Linux, Windows, macOS
- **Android** — perlu nama paket (`com.situkangsayur.readpaper`) dan sidik
  jari SHA-1 dari keystore penandatangan. **Keystore rilis dan keystore debug
  berbeda sidik jarinya**, jadi daftarkan keduanya

Unduh JSON-nya. Perlu diketahui: *client secret* di aplikasi desktop dan
mobile **bukan rahasia** — siapa pun bisa membongkarnya dari binernya. Google
tahu itu; karena itu alur yang benar memakai PKCE, bukan mengandalkan
kerahasiaan secret.

### 6. Alur login

Gunakan **Authorization Code + PKCE dengan loopback redirect**:

1. ReadPaper membuka port acak di `127.0.0.1`
2. Membuka peramban sistem ke URL otorisasi Google, dengan
   `redirect_uri=http://127.0.0.1:<port>/` dan `code_challenge`
3. Pengguna menyetujui di peramban
4. Google mengarahkan balik ke loopback tadi membawa `code`
5. ReadPaper menukar `code` + `code_verifier` menjadi access token dan
   refresh token

Alur lama `urn:ietf:wg:oauth:2.0:oob` (salin-tempel kode) **sudah dimatikan
Google** — jangan dipakai.

### 7. Dua jebakan yang mahal kalau baru ketahuan belakangan

- **Refresh token kedaluwarsa dalam 7 hari** selama aplikasi masih berstatus
  *Testing*. Jadi selama pengembangan, login akan minta diulang tiap minggu.
  Ini bukan bug. Hilang setelah aplikasi dipublikasikan.
- **Layar "Google hasn't verified this app"** akan muncul untuk siapa pun di
  luar daftar test user. Kalau ReadPaper mau dipakai umum dengan scope
  sensitif, verifikasi wajib: butuh kebijakan privasi, domain yang terbukti
  milik kita, dan **video demo** yang memperlihatkan tiap scope dipakai untuk
  apa. Prosesnya bisa makan berminggu-minggu. Memakai `drive.file` menghindari
  seluruh urusan ini.

### 8. Simpan tokennya dengan benar

Refresh token setara kata sandi. Simpan di penyimpanan aman sistem
(`flutter_secure_storage`: Keystore di Android, Keychain di macOS, DPAPI di
Windows, Secret Service di Linux) — **jangan** di `config.json` seperti token
GitHub sekarang.

---

## Bagian 2 — Memakai API-nya

Hanya ada dua panggilan yang benar-benar dipakai.

### `documents.get`

Mengembalikan seluruh dokumen sebagai JSON: paragraf, gaya, tabel, footnote,
dan **named range**. Ini yang dipakai untuk menemukan sitasi yang sudah ada
sebelum memperbaruinya.

### `documents.batchUpdate`

Satu daftar permintaan yang dijalankan berurutan. Yang relevan:

| Permintaan | Untuk apa |
|---|---|
| `insertText` | Menyisipkan teks sitasi |
| `deleteContentRange` | Menghapus teks sitasi lama saat gaya diganti |
| `updateTextStyle` | Superscript untuk Vancouver, miring untuk judul |
| `createNamedRange` | Menandai rentang sebagai "ini sitasi ReadPaper" |
| `deleteNamedRange` | Melepas tanda itu saat sitasi dihapus |
| `createParagraphBullets` | Penomoran daftar pustaka |
| `insertPageBreak` | Memulai halaman daftar pustaka |
| `createFootnote` | Sitasi catatan kaki (gaya Chicago). **Perlu dicek** batasannya — Docs melarang footnote di tempat tertentu seperti header, footer, dan di dalam footnote lain |

**Indeks bergeser setiap penyisipan.** Ini sumber bug paling sering. Susun
permintaan **dari belakang dokumen ke depan**, supaya penyisipan di bawah
tidak menggeser posisi yang belum diproses.

### Menyimpan identitas sitasi di dalam dokumen

Ini bagian yang membuat "perbarui semua sitasi" mungkin. Teks `[1]` tidak
cukup — kita perlu tahu `[1]` itu item Zotero yang mana, halaman berapa, dan
anotasi mana yang dirujuk.

Google Docs tidak punya tempat penyimpanan khusus untuk aplikasi. Yang ada:
**named range**. Rencananya:

- Setiap sitasi dibungkus named range bernama `READPAPER_CIT_<uuid>`
- Muatannya (kunci item, halaman, kunci anotasi, prefiks/sufiks, apakah masuk
  daftar pustaka) disimpan di named range terpisah berisi JSON yang
  dikompresi dan di-base64, ditaruh di akhir dokumen dengan teks berukuran
  sangat kecil
- Nama named range ada batas panjangnya dan **boleh sama** untuk beberapa
  rentang, jadi jangan menyimpan muatan di dalam namanya. Kalau JSON-nya
  melebihi batas satu rentang, pecah bernomor: `READPAPER_DATA_1`,
  `READPAPER_DATA_2`, dan seterusnya

Akibat yang disengaja: dokumennya **mandiri**. Orang lain yang juga memakai
ReadPaper bisa membuka dokumen yang sama dan memperbarui sitasinya, karena
semua yang dibutuhkan ada di dalam dokumen, bukan di komputer penulis aslinya.

### Kuota

Ada batas permintaan per menit per proyek dan per pengguna, terlihat di
**APIs & Services → Quotas**. Jangan mengandalkan angka yang ditulis di
dokumen ini; angkanya berubah. Yang penting sejak awal: satu `batchUpdate`
berisi banyak permintaan jauh lebih hemat daripada banyak `batchUpdate`
berisi satu permintaan.

---

## Urutan pengerjaan

1. Buat proyek Cloud, client ID Desktop, login PKCE, tampilkan nama akun.
   Tanpa menyentuh dokumen sama sekali. Ini membuktikan bagian yang paling
   sering macet.
2. `documents.get` atas satu dokumen yang dipilih lewat Picker, tampilkan
   jumlah paragrafnya.
3. Sisipkan teks polos lewat `batchUpdate`.
4. Named range + muatan JSON, lalu baca lagi dan buktikan utuh.
5. Baru setelah itu: sitasi sungguhan lewat mesin CSL dari Fase 9.

## Sumber

- [OAuth 2.0 Policies — Google for Developers](https://developers.google.com/identity/protocols/oauth2/policies)
- [Sensitive scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)
- [Restricted scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/restricted-scope-verification)
- [Configure the OAuth consent screen and choose scopes](https://developers.google.com/workspace/guides/configure-oauth-consent)
- [Choose Google Drive API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth)
- [OAuth 2.0 Scopes for Google APIs](https://developers.google.com/identity/protocols/oauth2/scopes)
