# Pendeteksi AI & Humanizer — apa kata penelitian terbaru

Status: riset, belum ada kode. Bagian dari Fase 12 di [backlog](backlog.md).

Yang diminta: cari paper terbaru dengan akurasi tinggi yang bisa dipasang
**ringan di dalam aplikasi**; kalau tidak kuat, buat dulu layanannya.
Keduanya untuk **bahasa Inggris dan Indonesia**.

---

## Hal yang harus dibaca lebih dulu

Dua fitur yang diminta — pendeteksi AI dan humanizer — **saling melawan**.
Itu bukan pendapat; itu hasil pengukuran, dan besarnya mengejutkan:

- Parafrase sederhana menurunkan akurasi deteksi hingga **12–15%**
- Satu model parafrase (Dipper) menurunkan akurasi DetectGPT dari **70,3%
  menjadi 4,6%**
- Enam pendeteksi besar yang diuji bersama rata-rata hanya **39,5%** akurat,
  dan turun ke **17,4%** pada teks yang sudah sedikit diubah untuk mengelabui
- [AuthorMist](https://arxiv.org/pdf/2503.08716) menunjukkan sebuah model
  bisa dilatih khusus untuk menembus pendeteksi

Artinya: angka 97% yang akan Anda lihat di bawah berlaku pada teks mentah
keluaran LLM. Begitu teks itu lewat humanizer — termasuk humanizer milik
ReadPaper sendiri — angkanya jatuh. Ini harus dikatakan di dalam aplikasi,
bukan disembunyikan.

Masalah kedua, yang lebih serius untuk pengguna kita:

- Studi Stanford 2023: pendeteksi menandai hingga **97%** esai TOEFL
  (penulis non-penutur asli) sebagai buatan AI
- Satu studi atas 135.389 pasang dokumen menemukan tingkat positif palsu
  antar 13 pendeteksi berkisar dari **0% sampai 100%**
- [Style as a Confound](https://arxiv.org/pdf/2608.26710) (2026) menelusuri
  sebabnya: gaya tulis non-penutur asli lebih mudah ditebak, dan itu persis
  sinyal yang dipakai pendeteksi

Pengguna ReadPaper adalah peneliti Indonesia yang menulis dalam bahasa
Inggris. Mereka justru kelompok yang paling sering disalahtuduh. Karena itu
keluaran fitur ini **tidak boleh berupa vonis**.

---

## Paper yang paling cocok untuk dipasang di dalam aplikasi

### NEULIF — stylometri + pengklasifikasi ringkas

[A Lightweight Approach to Detection of AI-Generated Texts Using Stylometric
Features](https://arxiv.org/abs/2511.21744) (Aityan, Claster, Emani, Rais,
Tran)

| | |
|---|---|
| Cara kerja | Teks dipecah menjadi ciri stylometri dan keterbacaan, lalu diklasifikasi CNN ringkas atau Random Forest |
| Akurasi | CNN **97%**, F1 ~0,95, ROC-AUC **99,5%** · RF **95%**, F1 ~0,94 |
| Ukuran model | CNN **~25 MB** · RF **~10,6 MB** |
| Kebutuhan | CPU biasa, tanpa GPU |
| Data uji | Korpus Kaggle "AI vs Human" |
| Bahasa | **Tidak disebutkan** — hampir pasti hanya Inggris |

Inilah kandidat terkuat: seukuran itu muat di dalam APK, jalan di ponsel,
dan akurasinya setara pendeteksi berbasis transformer yang jauh lebih berat.

Dua peringatan jujur: hasilnya dari **satu** korpus Kaggle, dan paper ini
belum diuji pihak lain seluas pendeteksi yang lebih tua. Angka 97% itu perlu
kita buktikan sendiri sebelum dipercaya.

### Untuk bahasa Indonesia

Tidak ada yang sekelas NEULIF. Yang tersedia:

- **[M4](https://arxiv.org/pdf/2305.14902)** — tolok ukur deteksi lintas
  generator, domain, dan bahasa; jadi acuan cara mengevaluasi
- **[MultiGhostBench](https://arxiv.org/pdf/2609.02379)** (2026) — teks
  panjang, multibahasa, dengan pergeseran distribusi
- **[IndicDetect](https://arxiv.org/pdf/2608.29919)** (2026) — Hindi, Telugu,
  Tamil. Bukan Indonesia, tapi metodenya paling dekat dengan situasi kita:
  bahasa dengan data terbatas
- **[Deteksi teks AI bahasa Indonesia dengan deep
  learning](https://github.com/kevin-wijaya/AI-Generated-Text-Detection-with-Deep-Learning-Approach-on-Indonesian-Text)**
  — LSTM, GRU, Bi-LSTM, Bi-GRU, dan IndoBERT, dengan dataset berita Indonesia
  yang dipasangkan dengan artikel buatan ChatGPT. Yang paling langsung bisa
  dipakai, tapi datanya berita 2018 dan generatornya ChatGPT lama — jauh dari
  tulisan akademik 2026
- **[Are AI Detectors Good Enough?](https://arxiv.org/pdf/2410.14677)** —
  survei mutu dataset; wajib dibaca sebelum melatih apa pun, karena banyak
  dataset deteksi ternyata cacat

**Kesimpulannya: untuk bahasa Indonesia, datanya harus kita buat sendiri.**
Teks akademik Indonesia (abstrak, pendahuluan) dipasangkan dengan keluaran
beberapa model terbaru atas prompt yang sama. Ini pekerjaan nyata, bukan
tempelan, dan harus dijadwalkan sebagai pekerjaan tersendiri.

---

## Rencana

### Tahap 1 — Di dalam aplikasi, bahasa Inggris

Ikuti NEULIF: ciri stylometri + keterbacaan, pengklasifikasi ringkas,
diekspor ke ONNX dan dijalankan lewat inti Rust (lihat
[KT-1](keputusan-teknis.md)). Target: di bawah 30 MB, satu paragraf selesai
di bawah 100 ms di ponsel, tanpa jaringan.

Kalau hasil reproduksi kita jauh di bawah angka papernya, **katakan apa
adanya dan jangan rilis fiturnya** dengan angka pinjaman.

### Tahap 2 — Di dalam aplikasi, bahasa Indonesia

Ciri stylometri **tidak bisa dipakai lintas bahasa** — panjang kata,
kekayaan kosakata, dan rumus keterbacaan semuanya berbeda perilakunya. Model
terpisah, data terpisah, ambang terpisah.

Urutannya: kumpulkan dan terbitkan datasetnya lebih dulu (itu sendiri
sumbangan yang berguna), baru latih.

### Tahap 3 — Layanan, hanya kalau perlu

Kalau tahap 1 dan 2 tidak mencapai mutu yang layak, barulah
`readpaper-detect`: layanan Rust + ONNX Runtime yang menjalankan model lebih
besar (XLM-R atau IndoBERT yang dikuantisasi). Aplikasi memakainya **hanya
kalau pengguna menyalakannya**, dan harus mengatakan dengan jelas bahwa
teksnya dikirim keluar. Mode sepenuhnya lokal tetap ada dan tetap jadi
bawaan.

Karena ReadPaper berlisensi AGPL, layanan ini pun wajib terbuka sumbernya —
memang itu maksudnya.

### Humanizer

Bukan pengklasifikasi, jadi bukan soal model kecil: perlu model generatif.
Rencananya penyedia bisa dipilih — lokal lewat Ollama/llama.cpp, atau API.
Kualitas bahasa Indonesia harus diuji terpisah; kemampuan model untuk bahasa
Indonesia jauh lebih beragam daripada untuk bahasa Inggris.

---

## Aturan tampilan yang tidak bisa ditawar

Ini bagian dari fiturnya, bukan hiasan:

1. **Skor per paragraf**, tidak pernah satu vonis untuk seluruh dokumen
2. **Rentang keyakinan** ditampilkan, bukan satu angka telanjang
3. **Tidak ada kata "AI-generated" sebagai pernyataan fakta.** Yang
   ditampilkan: "gaya tulisan paragraf ini mirip keluaran model" — karena
   itulah yang sebenarnya diukur
4. **Peringatan positif palsu** ditampilkan di tempat, bukan disembunyikan di
   pengaturan, khususnya untuk teks bahasa Inggris yang ditulis penutur
   non-asli
5. **Tidak ada ekspor "laporan" yang tampak seperti bukti.** Alat ini untuk
   penulis memeriksa tulisannya sendiri, bukan untuk menuduh orang lain

---

## Sumber

- [A Lightweight Approach to Detection of AI-Generated Texts Using Stylometric Features](https://arxiv.org/abs/2511.21744)
- [M4: Multi-generator, Multi-domain, and Multi-lingual Black-Box Machine-Generated Text Detection](https://arxiv.org/pdf/2305.14902)
- [MultiGhostBench: A Multilingual Benchmark for Long-Form LLM-Generated Text Attribution under Distribution Shifts](https://arxiv.org/pdf/2609.02379)
- [IndicDetect: Evaluating Cross-Lingual LLM-Generated Text Detection for Hindi, Telugu, and Tamil](https://arxiv.org/pdf/2608.29919)
- [Are AI Detectors Good Enough? A Survey on Quality of Datasets With Machine-Generated Texts](https://arxiv.org/pdf/2410.14677)
- [Style as a Confound: False Positives in AI Detection of Non-Native Academic Writing](https://arxiv.org/pdf/2608.26710)
- [AuthorMist: Evading AI Text Detectors with Reinforcement Learning](https://arxiv.org/pdf/2503.08716)
- [AI-Generated Text Detection with Deep Learning Approach on Indonesian Text](https://github.com/kevin-wijaya/AI-Generated-Text-Detection-with-Deep-Learning-Approach-on-Indonesian-Text)
- [Evaluating the accuracy and reliability of AI content detectors in academic contexts](https://link.springer.com/article/10.1007/s40979-026-00213-1)
- [AI Detector False Positive Rates: What Independent Research Shows in 2026](https://gowinston.ai/how-often-are-ai-detectors-wrong/)
