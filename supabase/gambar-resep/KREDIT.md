# Kredit foto resep contoh

Foto untuk 6 resep di `supabase/seed.sql`, diambil dari Wikimedia Commons.
Semua foto **diperkecil menjadi lebar 800 px dan disimpan ulang sebagai JPEG**
oleh tim Racik. Lisensinya tetap mengikuti lisensi aslinya di bawah. Foto
berlisensi CC BY-SA boleh dipakai ulang hanya dengan lisensi yang sama.

Aplikasi menampilkan nama pembuat dan lisensinya di bawah foto, di halaman
detail resep (`lib/core/photo_credits.dart`).

| File | Pembuat | Lisensi | Sumber |
|------|---------|---------|--------|
| nasi-goreng.jpg | shankar s. dari Dubai | [CC BY 2.0](https://creativecommons.org/licenses/by/2.0) | [Nasi Goreng Kampung (11967588375).jpg](https://commons.wikimedia.org/wiki/File:Nasi_Goreng_Kampung_(11967588375).jpg) |
| gado-gado.jpg | Piknikdong | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Gado gado jakarta.jpg](https://commons.wikimedia.org/wiki/File:Gado_gado_jakarta.jpg) |
| soto-ayam.jpg | Sakurai Midori | [CC BY-SA 3.0](https://creativecommons.org/licenses/by-sa/3.0/) | [Soto ayam.JPG](https://commons.wikimedia.org/wiki/File:Soto_ayam.JPG) |
| rendang.jpg | Midori | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0) | [Rendang daging sapi asli Padang.JPG](https://commons.wikimedia.org/wiki/File:Rendang_daging_sapi_asli_Padang.JPG) |
| pisang-goreng.jpg | Iloveporotta | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0) | [Banana Fritters and tea.jpg](https://commons.wikimedia.org/wiki/File:Banana_Fritters_and_tea.jpg) |
| sayur-bening-bayam.jpg | Midori | [CC BY 3.0](https://creativecommons.org/licenses/by/3.0) | [Sayur bening bayam jagung.JPG](https://commons.wikimedia.org/wiki/File:Sayur_bening_bayam_jagung.JPG) |

## Cara memasang

Lihat `supabase/foto-resep-contoh.sql`: unggah file-file ini ke Storage
`food-images/resep/`, lalu jalankan file SQL itu di SQL Editor.

Foto resep baru cukup diunggah lewat form admin di aplikasi. Foto akan
masuk ke `food-images/foods/` dan `image_url` terisi otomatis.
