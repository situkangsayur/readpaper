# ReadPaper — Backlog

Status per 2026-09-16. Fase 1 selesai dan teruji di desktop Linux; fase 4
sebagian besar terpasang (sinkronisasi Android), menunggu uji perangkat.

Legenda: `[x]` selesai · `[~]` sebagian · `[ ]` belum.

---

## Fase 1 — Baca, tandai, sinkron (MVP)

Tujuan: buka repo Zotero di GitHub, telusuri koleksi, baca PDF, beri stabilo
berwarna dan komentar, lalu commit & push perubahannya.

### 1.1 Sinkronisasi GitHub
- [x] Clone repo lewat **SSH** (`git@github.com:...`) dengan pilihan kunci privat per profil
- [x] Clone repo lewat **HTTPS** + personal access token (token disimpan di
      `credentials.json`, izin `600`, tidak pernah masuk ke URL remote)
- [x] `fetch` / `pull --rebase --autostash` / `commit` / `push`
- [x] `git lfs pull` untuk lampiran besar (`attachments-lfs/`)
- [x] Status working copy: jumlah perubahan lokal, ahead/behind, commit terakhir
- [x] Panel detail sinkronisasi: daftar perubahan, riwayat commit, log mentah git
- [x] PDF baru yang ditambahkan lewat GitHub otomatis muncul setelah `pull`
      (library dibaca ulang)
- [ ] Deteksi & bantuan penyelesaian konflik merge (saat ini hanya menampilkan pesan error git)
- [ ] Auto-fetch berkala di latar belakang
- [ ] Indikator progres yang lebih detail saat clone repo besar (persen objek)

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
- [ ] Pencarian khusus pengarang (facet daftar pengarang + jumlah karyanya;
      `LibraryIndex.creatorFacets()` sudah disiapkan)
- [ ] Filter gabungan: pengarang × tahun × jenis item × tag
- [ ] Halaman "profil pengarang": semua karya, koleksi tempat ia muncul, rentang tahun
- [ ] Pencarian lanjutan dengan operator (`author:`, `year:`, `tag:`, `type:`)
- [ ] Pengayaan metadata dari DOI (Crossref / OpenAlex) untuk item yang datanya kosong
- [ ] Ekstraksi metadata dari isi PDF ketika item tidak punya metadata sama sekali
- [ ] Ekspor sitasi (BibTeX / RIS / APA) per item atau per koleksi
- [ ] Statistik library: jumlah per tahun, per jenis, pengarang terbanyak

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
- [x] Editor profil menyesuaikan diri: di Android hanya menawarkan HTTPS + token
- [x] Build APK rilis (arm64)
- [ ] Uji end-to-end di perangkat dengan token GitHub sungguhan
- [ ] Penyimpanan token di keystore Android (sekarang di berkas privat aplikasi)
- [ ] Git LFS di Android (`attachments-lfs/`) — perlu endpoint LFS batch
- [ ] Penandatanganan rilis dengan keystore sendiri (sekarang debug key)
- [ ] **Rilis GitHub**: tag + Release berisi APK supaya bisa diunduh dari GitHub
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
- [ ] Unduh metadata awal lebih hemat (saat ini ±3.500 permintaan API untuk
      mirror pertama; kuota GitHub 5.000/jam). Ide: tunda `notes/**.md`
      (±1.740 berkas, separuh dari total permintaan) dan ambil satu catatan
      hanya ketika anotasi paper itu ditulis

---

## Lintas fase — utang teknis

- [x] Uji unit parser Zotero + penulis anotasi (round-trip JSON byte-for-byte)
- [x] Uji unit backend GitHub API (clone, status, commit, push, pull, lampiran)
- [ ] Uji widget untuk pohon koleksi dan alur anotasi
- [ ] Cache indeks library di disk + invalidasi berdasarkan mtime
- [ ] Penanganan berkas item rusak yang lebih informatif (saat ini dilewati diam-diam)
- [ ] Dukungan repositori tanpa `.zotero-sync/manifest.json` sudah ada, tapi belum diuji luas
- [ ] Lokalisasi (saat ini antarmuka berbahasa Indonesia, belum ada i18n)
