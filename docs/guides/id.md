# AxonTube

[English](en.md) · [简体中文](zh-Hans.md) · [繁體中文](zh-Hant.md) · [日本語](ja.md) · [한국어](ko.md) · [Español](es.md) · [Français](fr.md) · [Deutsch](de.md) · [Italiano](it.md) · [Português](pt.md) · [Русский](ru.md) · [العربية](ar.md) · [हिन्दी](hi.md) · [Türkçe](tr.md) · [Tiếng Việt](vi.md) · [ไทย](th.md) · **Bahasa Indonesia** · [Nederlands](nl.md) · [Polski](pl.md) · [Українська](uk.md) · [Svenska](sv.md) · [Dansk](da.md) · [Suomi](fi.md) · [עברית](he.md)

[README · English](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

**Pelajari bahasa-bahasa dunia lebih cepat dengan AI.**

Versi 0.5.3 · Pratinjau kode sumber · Kompilasi dari kode sumber

Jadikan YouTube kelas bahasa pribadi Anda. Gunakan takarir dan terjemahan otomatis YouTube untuk belajar dari video favorit Anda: baca dua bahasa berdampingan, putar ulang setiap kalimat, dan simpan materi yang penting bagi Anda.

**24 bahasa antarmuka · Takarir multibahasa**

24 adalah jumlah pilihan bahasa antarmuka. Bahasa takarir bergantung pada trek yang tersedia untuk video terpilih; ini bukan janji untuk fasih dalam 24 bahasa.

## Tangkapan layar

Tangkapan layar diambil dari aplikasi 0.5.3 yang sebenarnya. Bahasa antarmuka dalam gambar diberi label terpisah dari bahasa dokumen ini.

### Sambutan dan alur kerja utama

![Sambutan dan alur kerja utama](../assets/interface-en.png)

Empat tindakan bilah alat, dua pemilih takarir yang terlihat, slogan yang dilokalkan, dan status nonaktif yang jelas sebelum video dibuka. — Tangkapan layar aplikasi berbahasa Inggris

### Latihan yang berfokus pada kalimat

![Latihan yang berfokus pada kalimat](../assets/interface-study.png)

demo.mp4 — Pencarian kalimat, klik untuk melompat ke waktunya, kalimat sebelumnya / berikutnya, putar ulang, pengulangan, kecepatan pemutaran, dan mengikuti kalimat saat ini. — Tangkapan layar aplikasi berbahasa Inggris

### Takarir pertama dan kedua

![Takarir pertama dan kedua](../assets/interface-caption-languages.png)

Tangkapan nyata antarmuka bahasa Inggris yang memperlihatkan menu pilihan takarir independen, dengan bawaan bahasa Inggris dan Tionghoa Tradisional. — Tangkapan layar aplikasi berbahasa Inggris

### Buka tautan YouTube

![Buka tautan YouTube](../assets/interface-youtube-dialog.png)

Tangkapan nyata dialog tautan dalam antarmuka bahasa Inggris. Membuka tautan akan memulai pemutaran dan meminta pasangan takarir yang dipilih. — Tangkapan layar aplikasi berbahasa Inggris

## Mulai menggunakan

### 1. Buka YouTube

Tempel tautan video. Takarir yang tersedia diminta secara otomatis, dengan bahasa Inggris sebagai trek pertama dan Tionghoa Tradisional sebagai trek kedua. Pengambilan pertama mungkin memerlukan sekitar 1–2 menit; ketersediaannya tidak dijamin.

### 2. Pilih dan berlatih

Gunakan dua menu pilihan takarir yang terlihat. Klik sebuah kalimat untuk melompat ke sana, putar ulang, atau aktifkan pengulangan kalimat.

### 3. Simpan atau ekspor

Simpan Video memungkinkan Anda memilih folder untuk media yang dapat diakses dan takarir yang tersedia. Ekspor Takarir Dwibahasa membuat Word, TXT, atau SRT dari takarir yang sudah dimuat.

### 4. Sesuaikan dengan kebutuhan Anda

Ubah bahasa antarmuka, kecepatan pemutaran, ukuran takarir, dan pergeseran waktu tiap trek. Aplikasi mengingat pilihan bahasa antarmuka dan takarir.

## Fitur yang tersedia

### Dua trek takarir yang independen

Bahasa bawaan adalah Inggris dan Tionghoa Tradisional; pilih dari takarir asli dan terjemahan otomatis yang tersedia untuk video saat ini. Takarir trek pertama yang berhasil dimuat tetap dapat digunakan jika trek kedua gagal.

### Latihan yang berfokus pada kalimat

Pencarian kalimat, klik untuk melompat ke waktunya, kalimat sebelumnya / berikutnya, putar ulang, pengulangan, kecepatan pemutaran, dan mengikuti kalimat saat ini.

### Video dengan takarir tersinkron

Penyimpanan tetap tersedia saat takarir dimuat. Setiap operasi membuat folder baru berisi video yang dapat diakses; jika takarir tersedia, trek SRT bertanda waktu dan berkas bacaan dwibahasa ditambahkan. Penyimpanan video tanpa takarir juga didukung. Hasil yang belum selesai tetap berada di folder .partial.

### Ekspor Word, TXT, dan SRT

Ekspor takarir yang tersedia dengan pergeseran waktu yang sudah diterapkan. Word dan TXT memasangkan teks berdasarkan tumpang tindih waktu. Jika hanya satu trek yang dimuat, isinya tetap dapat diekspor.

### Antarmuka dalam 24 bahasa

Menu, pesan status, dan slogan belajar berganti bahasa bersama. Bahasa Arab dan Ibrani mendukung tata letak dari kanan ke kiri; mengganti bahasa antarmuka tidak mengubah isi takarir.

### Pemutaran lokal dan kontrol yang jelas

Buka berkas media dan takarir lokal dari menu Berkas. Tindakan yang tidak tersedia diredupkan disertai alasan; mode terpilih disorot dan diberi tanda centang; penyimpanan menampilkan status sibuk.

## Manfaatnya

### Dari menonton ke berlatih dalam beberapa langkah

Empat tindakan pada bilah alat menjaga alur utama tetap langsung: YouTube → Simpan Video → Takarir → Bahasa. Tidak perlu tombol tambahan untuk mengambil takarir.

### Materi belajar yang dapat disimpan

Takarir bertanda waktu dan berkas Word / TXT yang mudah dibaca mendukung latihan menyimak dan peninjauan kembali nanti. Ekspor menggunakan tujuan baru dan mempertahankan berkas asli.

### Bekerja secara lokal, tanpa kunci API AI

Media lokal dan takarir tersimpan dapat digunakan luring. YouTube menyediakan takarir situs dan terjemahan otomatis; aplikasi tidak mengumpulkan telemetri, tidak mengunggah media lokal, dan tidak memerlukan kunci API AI berbayar.

## Masalah dan batasan yang belum teratasi

### P0 · Ketersediaan takarir dan video YouTube

**Verifikasi layanan langsung**

Pemeriksaan langsung terakhir terhalang persyaratan YouTube untuk masuk / verifikasi bot. Keberhasilan pengunduhan daring dalam kondisi saat ini belum dibuktikan. Verifikasi pada jaringan yang akan digunakan dan berbagai video yang representatif diperlukan sebelum rilis publik.

### P1 · Penyematan dan video yang dibatasi berdasarkan akun

**Batasan platform**

Sebagian kreator atau video tidak mengizinkan pemutaran tersemat. Google SSO di dalam aplikasi belum diterapkan; pintasan peramban menggunakan sesi masuk dan pemutaran yang terpisah. Batasan ini tidak dapat dinyatakan sudah teratasi.

### P1 · Penandatanganan dan pengujian pada lebih banyak Mac

**Distribusi dan kompatibilitas**

Paket ditandatangani secara ad-hoc, tanpa notarisasi Developer ID. Apple Silicon dengan macOS 26.5.2 telah diuji; macOS 27 dan Mac Intel belum. macOS 14 adalah target penerapan, bukan bukti bahwa setiap versi sudah diuji.

### P2 · Kualitas unduhan dan ketepatan takarir

**Batasan format dan kualitas**

Penyimpanan menggunakan satu aliran lengkap berisi audio dan video, tanpa menggabungkan aliran resolusi tinggi yang terpisah. Pemutaran lokal bergantung pada dukungan codec. Konversi opsional dengan FFmpeg mungkin tidak mempertahankan trek audio tambahan, HDR, dan takarir tertanam. Impor ASS/SSA hanya mengambil teks. Takarir otomatis, terjemahan, dan pemasangan dwibahasa berbasis waktu dapat mengandung kesalahan.

### P2 · Riwayat belajar dan alat pembelajaran

**Belum diterapkan**

Pemulihan riwayat pemutaran, koleksi kosakata, tinjauan berjarak, OCR, dan ekstraksi takarir gambar belum diterapkan. Preferensi bahasa yang tersimpan bukan berarti kemajuan belajar ikut tersimpan.

### P2 · Tinjauan bahasa oleh penutur asli

**Tinjauan editorial**

Seluruh 24 pilihan bahasa antarmuka dan slogan yang dilokalkan lulus pemeriksaan pergantian bahasa. Ini membuktikan cakupan dan perilaku, bukan bahwa setiap terjemahan sudah ditinjau secara profesional oleh penutur asli.

## Yang sudah diverifikasi

Untuk 0.5.3: 105 pemeriksaan inti, 138 asersi model, 29 pemeriksaan takarir, 60 pemeriksaan penyimpanan video, dan 317 asersi antarmuka native lulus. Seluruh 24 bahasa dipilih di menu yang sebenarnya; enam bahasa antarmuka dan tata letak ringkas bahasa Jerman telah ditinjau.

Pemutaran lokal, ekspor, transisi status, dan dialog simpan native telah diverifikasi. Data uji luring dan pengujian penyimpanan dengan pembantu tiruan tidak membuktikan bahwa YouTube saat ini mengizinkan pengunduhan takarir atau video secara daring. Tidak ada kredensial pengguna yang diimpor.

[Catatan verifikasi terperinci](../VERIFICATION.md) · [README · EN](../../README.md) · [README · 简体中文](../../README.zh-CN.md)

[HTML (offline)](../product-guide.html#id)

Aplikasi berlisensi MIT; pemberitahuan komponen pihak ketiga tetap dipertahankan. AxonTube tidak berafiliasi dengan YouTube, Google, atau Apple.

Tanggal dokumen: 2026-10-11
