# Keputusan teknis

Catatan keputusan yang sulit diubah setelah dipakai orang. Satu bagian satu
keputusan: apa yang diputuskan, kenapa, dan apa yang dikorbankan.

---

## KT-1 — Rust untuk inti, Flutter tetap untuk antarmuka

**Status:** disetujui 2026-09-25.

### Yang diminta

Desktop sebaiknya native supaya ringan, dan Rust disebut sebagai pilihan —
kecuali ada yang lebih ringan.

### Tiga pilihan

| | Bentuk | Ukuran & bobot | Biaya |
|---|---|---|---|
| **A** | Flutter untuk semua platform (sekarang) | Biner Linux ~40 MB, memakai GTK; bukan yang paling ringan tapi wajar | Nol. Sudah jalan |
| **B** | Desktop ditulis ulang dengan Rust (Slint, egui, GTK-rs, atau Tauri) | Paling ringan. Slint/egui bisa di bawah 10 MB | **Dua basis kode antarmuka.** Setiap fitur dikerjakan dua kali, selamanya. Ini yang membunuh proyek kecil |
| **C** | Antarmuka tetap Flutter, **inti dipindah ke Rust** lewat `flutter_rust_bridge` | Mendekati B untuk bagian yang memang berat, karena yang berat memang bukan tombolnya | Sedang. Satu antarmuka, satu inti, dipakai semua platform termasuk Android |

### Keputusan: C

Alasannya: yang membuat ReadPaper terasa berat bukan widget-nya, melainkan
pekerjaan di belakangnya — mengurai 1.740 berkas item, operasi PDFium,
mesin CSL, sandbox plugin, dan nanti inferensi model pendeteksi. Semua itu
justru **lebih baik di Rust**, dan semuanya bisa dipindah ke Rust tanpa
menyentuh satu widget pun.

Menulis ulang antarmukanya dengan Rust akan memberi penghematan puluhan
megabita sekali, lalu menagih biaya dua kali kerja untuk setiap fitur
sesudahnya — sementara Fase 5 sampai 12 masih panjang. Itu pertukaran yang
buruk.

Yang dipindah ke Rust, berurutan sesuai manfaatnya:

1. **Sandbox plugin** (lihat KT-2) — memang tidak ada pilihan lain
2. **Mesin CSL** — `citeproc` ada implementasi Rust-nya, dipakai Fase 9 dan 10
3. **Operasi PDF** — gabung anotasi, ekspor, render
4. **Pendeteksi AI** — inferensi model ringan di CPU
5. **Parser Zotero** — paling akhir; yang sekarang sudah cukup cepat di
   `Isolate.run`, jadi memindahkannya belum tentu terasa

Kalau nanti ternyata **inti Rust sudah menanggung hampir semuanya** dan yang
tersisa di Flutter tinggal lapisan tipis, opsi B jadi jauh lebih murah dan
boleh ditinjau ulang. Urutan di atas memang disusun supaya pintu itu tidak
tertutup.

### Yang dikorbankan

- `flutter_rust_bridge` menambah langkah build dan toolchain Rust untuk
  semua kontributor
- Perlu build silang: `linux-x64`, `linux-arm64`, `windows-x64`,
  `macos-arm64`, dan `android-arm64`
- Kesalahan di Rust bisa membuat proses mati, bukan sekadar lempar
  eksepsi Dart

---

## KT-2 — Plugin berbentuk WebAssembly, dijalankan runtime Rust

**Status:** disetujui 2026-09-25. Ini keputusan yang **paling sulit
dibatalkan**: begitu orang menulis plugin, formatnya tidak bisa diganti.

### Kenapa bukan Dart

Build AOT tidak bisa memuat kode Dart saat berjalan. Plugin berbentuk Dart
tidak mungkin, titik.

### Kenapa WASM, bukan JavaScript

Rencana sebelumnya adalah sandbox JavaScript (QuickJS). WASM lebih baik untuk
tujuan yang diminta:

- **Plugin boleh ditulis dengan bahasa apa pun** yang bisa dikompilasi ke
  WASM — Rust, Go, C, AssemblyScript, Zig, bahkan JavaScript lewat
  interpreter yang dikompilasi ke WASM. Ini penting kalau tujuannya "orang
  lain bisa bikin plugin"
- **Sandbox-nya betulan.** Modul WASM tidak punya akses berkas atau jaringan
  kecuali kita yang memberikannya, satu per satu
- **Jalan sama** di Android, Linux, Windows, dan macOS

### Cara memasangnya

Sudah ada jalur yang terbukti: paket Dart
[`wasm_run`](https://pub.dev/packages/wasm_run) menjalankan WASM lewat
`wasmtime` (dengan JIT) atau `wasmi` (interpreter murni), dengan pengikatan
`flutter_rust_bridge` — persis pola KT-1.

`wasmi` penting: ada platform yang melarang JIT. Rencananya `wasmtime` di
desktop dan Android, `wasmi` sebagai cadangan.

Untuk lapisan di atasnya, **Extism** layak dilihat: ia kerangka kerja plugin
di atas WASM, lengkap dengan PDK untuk banyak bahasa, jadi tidak perlu
merancang cara oper data dari nol. **Perlu dicek**: Extism tidak punya SDK
host untuk Dart, jadi kalau dipakai, host-nya ada di sisi Rust.

### Bentuk plugin

Satu berkas `.zip` berisi:

- `plugin.json` — manifes: id, nama, versi, `minAppVersion`, izin, dan bagian
  `contributes` yang **deklaratif** (menu, tombol, panel, halaman pengaturan).
  Plugin yang hanya menambah menu tidak perlu menulis kode sama sekali
- `plugin.wasm` — logikanya, kalau ada
- Ikon dan berkas terjemahan

### Izin

Dideklarasikan di manifes, ditanyakan saat pemasangan, dan bisa dicabut:
`library:read`, `library:write`, `attachments:read`, `net:<domain>`,
`clipboard`, `fs:<folder>`. Modul yang tidak meminta jaringan secara teknis
**tidak bisa** menjangkau jaringan — bukan sekadar dilarang aturan.

### Lisensi SDK

**AGPL-3.0, sama dengan intinya** (diputuskan 2026-09-25). Usulan Apache-2.0
ditolak karena bertabrakan dengan syarat yang sudah ditetapkan: apa pun yang
dibangun di atas ReadPaper harus tetap terbuka, termasuk plugin pihak ketiga
dan termasuk kalau dijual.

Biaya yang disadari: sebagian penulis plugin tidak mau terikat AGPL, jadi
jumlah plugin akan lebih sedikit daripada kalau SDK-nya permisif. Itu
pertukaran yang memang dipilih. Hak ciptanya di tangan pemilik proyek, jadi
keputusan ini bisa dilonggarkan kemudian — arah sebaliknya tidak bisa.

---

## KT-3 — Google Docs lewat API resmi, bukan ekstensi peramban

**Status:** disetujui 2026-09-25. Rinciannya di [google-docs-api.md](google-docs-api.md).

Ringkasnya: add-on Google Docs berjalan di server Google dan tidak bisa
menghubungi ReadPaper di `127.0.0.1`, jadi pola yang dipakai LibreOffice dan
Word tidak bisa ditiru. Dari dua jalan yang tersisa, API resmi dipilih karena
jalan satunya berarti merawat dua ekstensi peramban selamanya. Scope
`drive.file` dipakai supaya tidak terkena kewajiban verifikasi Google.

---

## KT-4 — Pendeteksi AI: ringan di perangkat dulu, layanan belakangan

**Status:** disetujui 2026-09-25. Rinciannya dan papernya di
[deteksi-ai.md](deteksi-ai.md).

Satu hal ditambahkan saat persetujuan: kedua fitur memang bersifat adversarial,
tapi **dipakai bergantian, tidak pernah dipicu bersamaan**. Tidak ada alur yang
menjalankan humanizer lalu langsung memeriksanya dengan pendeteksi sendiri.
Konsekuensinya untuk antarmuka: keduanya panel terpisah dengan sesi terpisah,
dan menjalankan salah satunya menutup hasil yang lain supaya tidak terbaca
sebagai "sudah lolos pemeriksaan".
