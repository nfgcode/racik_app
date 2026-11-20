# Panduan publikasi Racik ke Google Play

Kerjakan **berurutan dari Tahap 0 sampai Tahap 9**. Setiap tahap butuh tahap
sebelumnya. Langkah bertanda `[x]` sudah selesai per 20 November 2026.

Perkiraan waktu: sekitar 3–4 minggu. Yang paling lama adalah closed testing
wajib selama 14 hari (Tahap 7), ditambah review Google beberapa hari.

| Tahap | Isi | Status |
|---|---|---|
| 0 | Gabungkan kode terbaru | ✅ |
| 1 | Supabase siap dipakai orang lain | sebagian (patch, foto, Edge Function ✅) |
| 2 | Halaman web wajib (kebijakan privasi, hapus akun) | email ✅, hosting ⬜ |
| 3 | Build AAB rilis | upload key ✅, AAB ⬜ |
| 4 | Akun Play Console | sebagian |
| 5 | Isi data aplikasi di Play Console | ⬜ |
| 6 | Internal testing (cek cepat) | ⬜ |
| 7 | Closed testing: 12 tester × 14 hari | ⬜ |
| 8 | Ajukan akses Production | ⬜ |
| 9 | Rilis Production | ⬜ |

---

## Tahap 0 — Gabungkan kode terbaru

- [x] Ambil bundle terakhir, push ke `main`, lalu merge di laptop (perintah ada di chat).
- [x] Pastikan `git log --oneline -1` menunjukkan commit terbaru dan `pubspec.yaml` berisi
      `version: 1.0.0+2`.
- [x] `flutter pub get`

## Tahap 1 — Supabase siap dipakai orang lain

- [ ] **Restore proyek** di dashboard Supabase bila sedang di-pause. Proyek gratis otomatis
      di-pause setelah sekitar seminggu tanpa aktivitas. Selama closed testing (14 hari) dan
      setelah rilis, pastikan proyek tetap aktif, atau pertimbangkan paket berbayar.
- [x] `hapus_akun.sql`, `patch-01-perbaikan-bug.sql`, dan `patch-02-perbaikan-bug.sql` sudah jalan.
- [x] `patch-03-foto-kandidat.sql` sudah jalan (ketiga kolom cek `true`).
- [x] **Foto resep contoh** sudah terpasang: keenam foto ada di `food-images/resep/` dan keenam
      resep contoh sudah punya `image_url` (`foto-resep-contoh.sql`).
- [x] **Edge Function** `recognize-food` sudah ter-deploy (dicek 20 Nov 2026: tanpa login
      membalas 401, bukan 404).
- [ ] **Ganti kunci OpenRouter.** Kunci lama pernah ikut ter-compile ke build lama, jadi anggap
      sudah bocor:
  1. Di dashboard OpenRouter, buat kunci baru dan pasang **batas kredit** supaya tagihan
     tidak membengkak.
  2. Dashboard Supabase → **Edge Functions → Secrets** → ubah nilai `OPENROUTER_API_KEY`
     menjadi kunci baru, lalu simpan. Function tidak perlu di-deploy ulang.
  3. Coba pindai satu makanan dari aplikasi. Kalau berhasil, **hapus kunci lama** di OpenRouter.
- [ ] Bila kode Edge Function berubah dan perlu di-deploy ulang, pakai Supabase CLI lewat `npx`
      (butuh Node.js; jangan `npm install -g supabase`, karena cara itu tidak didukung):

```powershell
npx supabase@latest login
npx supabase@latest functions deploy recognize-food --project-ref anpdybkgszizugifqrbw
```

  Cara lain tanpa memasang apa pun: Dashboard → **Edge Functions** → `recognize-food` →
  editor kode, lalu tempel isi `supabase/functions/recognize-food/index.ts` dan deploy.
- [ ] Hapus baris `OPENROUTER_API_KEY` dari `env.json` bila masih ada. Aplikasi tidak memakainya lagi.
- [ ] **Email konfirmasi.** Email bawaan Supabase hanya untuk uji coba: jumlahnya dibatasi
      dan tidak bisa diandalkan untuk tester atau pengguna umum. Pilih salah satu:
  - pasang SMTP sendiri (misalnya Resend atau Brevo, keduanya punya paket gratis) di
    **Authentication → Emails → SMTP Settings**, lalu nyalakan **Confirm email**; atau
  - biarkan **Confirm email** mati selama closed testing.
- [ ] Pastikan ada akun **admin** untuk memverifikasi resep hasil AI:
      `update public.users set role = 'admin' where username = '...';`
- [ ] Uji API: `powershell -ExecutionPolicy Bypass -File tool\test_supabase_api.ps1 -Login`

## Tahap 2 — Halaman web wajib

Play Console meminta dua URL publik: kebijakan privasi dan cara menghapus akun.

- [x] **Ganti `[EMAIL-KONTAK]`** dengan email untuk urusan aplikasi. Email ini akan terlihat
      publik. Jalankan dari folder proyek (isi alamatmu di baris pertama):

```powershell
$email = 'ganti@contoh.com'
foreach ($f in 'docs\kebijakan-privasi.html', 'docs\hapus-akun.html', 'store\listing.md') {
  $p = (Resolve-Path $f).Path
  $isi = [IO.File]::ReadAllText($p).Replace('[EMAIL-KONTAK]', $email)
  [IO.File]::WriteAllText($p, $isi)   # tetap UTF-8 tanpa BOM
}
Select-String -Path docs\*.html, store\listing.md -Pattern 'EMAIL-KONTAK'   # harus kosong
```

  Commit dan push perubahan ini seperti biasa.
- [ ] **Pasang halamannya di internet.** Pilih salah satu:
  - **GitHub Pages**: repo → **Settings → Pages** → *Deploy from a branch* → `main`, folder
    `/docs`. Untuk akun gratis, GitHub Pages hanya tersedia bila **repo publik**. Sebelum
    menjadikannya publik, pastikan tidak ada rahasia di repo (`env.json`, keystore, dan
    `key.properties` sudah di-`.gitignore`).
  - **Netlify Drop** (repo tetap private): buka https://app.netlify.com/drop, lalu seret folder
    `docs`. Kamu mendapat alamat seperti `https://nama-acak.netlify.app`.
- [ ] Pastikan kedua halaman bisa dibuka dari HP tanpa login, misalnya:
  - `https://nfgcode.github.io/racik_app/kebijakan-privasi.html`
  - `https://nfgcode.github.io/racik_app/hapus-akun.html`

## Tahap 3 — Build AAB rilis

- [x] **Upload key sudah ada**: `android/upload-keystore.jks` + `android/key.properties`
      (alias `upload`, SHA1 `9B:83:B9:98:74:FE:71:E2:B4:F0:82:DC:AF:47:26:46:3D:E6:E0:A0`).
      **Jangan buat kunci baru.** Kunci inilah yang akan didaftarkan ke Play.
- [ ] Pastikan keystore dan password-nya sudah dicadangkan di tempat aman (bukan di repo).
- [ ] Build dan cek tanda tangannya:

```powershell
flutter build appbundle --release --dart-define-from-file=env.json
$kt = (Get-Command keytool -ErrorAction SilentlyContinue).Source; if (-not $kt) { $kt = "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe" }
& $kt -printcert -jarfile build\app\outputs\bundle\release\app-release.aab | Select-String 'Owner|SHA1'
```

  Hasilnya harus `Owner: CN=Nurfauzan Gymnastiar, ...` dan SHA1 di atas. Kalau muncul
  `CN=Android Debug`, `key.properties` tidak terbaca dan AAB itu akan ditolak.
- [ ] Coba APK rilisnya di HP sungguhan sebelum diunggah:
      `flutter run --release --dart-define-from-file=env.json`. Cek login, pindai, riwayat,
      "Jadikan foto resep", dan hapus akun.

File yang diunggah ke Play: `build\app\outputs\bundle\release\app-release.aab`.

## Tahap 4 — Akun Play Console

- [ ] Daftar akun developer di https://play.google.com/console (biaya sekali US$25), lalu
      selesaikan verifikasi identitas dan verifikasi HP Android yang diminta.
- [x] Package name `com.racik.app` sudah dicek dan tersedia. Bila Console meminta
      pendaftaran package name, daftarkan nama ini.

## Tahap 5 — Isi data aplikasi di Play Console

- [ ] **Create app**: nama `Racik - Pindai Makanan & Gizi`, bahasa default Indonesia, *App*,
      *Free*, lalu centang pernyataan kebijakan.
- [ ] **Main store listing**: salin teks dari `store/listing.md`. Unggah `store/icon-512.png`,
      `store/feature-graphic.png`, dan screenshot dari `store/screenshots/`.
  - Screenshot lama masih menampilkan resep tanpa foto. Setelah foto resep contoh terpasang
    (Tahap 1), sebaiknya ambil ulang minimal 2 screenshot dari HP.
- [ ] **App content** (menu *Policy → App content*):
  - **Privacy policy**: URL kebijakan privasi dari Tahap 2.
  - **App access**: *All or some functionality is restricted*. Buat **akun uji khusus reviewer**
    di aplikasi, lalu tulis email dan password-nya di sini, supaya reviewer bisa mencoba
    Pindai, Riwayat, dan Profil.
  - **Ads**: *No*.
  - **Advertising ID**: *No* (aplikasi tidak memakai ID iklan).
  - **Content rating**: isi kuesioner IARC dengan jujur. Racik adalah aplikasi utilitas
    makanan tanpa kekerasan. Satu hal yang perlu dicatat: **foto pindai pengguna bisa tampil
    untuk pengguna lain** sebagai foto resep, tetapi hanya bila pemiliknya menyalakan
    "Jadikan foto resep" **dan** admin memilihnya. Jadi bila ditanya apakah pengguna bisa
    berbagi gambar, jawab sesuai keadaan ini (dimoderasi admin, tanpa nama pemilik).
    Pengguna tidak bisa saling mengirim pesan.
  - **Target audience**: **13 tahun ke atas**. Jangan pilih usia di bawah 13 agar tidak masuk
    program Families.
  - **Data safety**: lihat tabel di bawah.
  - **Account deletion**: URL halaman hapus akun dari Tahap 2.
  - **Health apps** (bila diminta): aplikasi informasi gizi umum, bukan perangkat medis.
  - **Financial features**: aplikasi tidak punya fitur keuangan.
  - **Government apps** dan **News apps**: bukan.

### Jawaban Data safety

| Pertanyaan | Jawaban |
|---|---|
| Mengumpulkan / membagikan data? | Mengumpulkan: Ya. Membagikan ke pihak ketiga: Tidak (Supabase & OpenRouter adalah *service provider*) |
| Dienkripsi saat dikirim? | Ya (HTTPS) |
| Pengguna bisa minta hapus data? | Ya (Profil → Hapus akun, dan halaman web) |
| Info pribadi | Nama, Alamat email, ID pengguna (username) — fungsi aplikasi & manajemen akun |
| Foto dan video | Foto — fungsi aplikasi (foto makanan dipindai, foto profil opsional). Foto pindai hanya tampil untuk pengguna lain bila pemiliknya menyalakan “Jadikan foto resep” dan admin memilihnya; tanpa nama pemilik |
| Aktivitas aplikasi | Interaksi di aplikasi (riwayat pindai) — fungsi aplikasi |
| Lokasi, kontak, keuangan, kesehatan pribadi, pesan | Tidak dikumpulkan |
| Wajib atau opsional? | Email & username wajib untuk membuat akun; foto profil opsional; resep bisa dibuka tanpa akun |

## Tahap 6 — Internal testing (cek cepat)

Tidak wajib, tetapi berguna untuk memastikan AAB terpasang normal sebelum tester lain diundang.

- [ ] **Test and release → Testing → Internal testing → Create new release**.
- [ ] Saat diminta, setujui **Play App Signing** (Google yang menyimpan kunci tanda tangan
      aplikasi; kuncimu menjadi *upload key*).
- [ ] Unggah `app-release.aab`, tambahkan email-mu sebagai tester, lalu pasang lewat tautan
      undangan. Coba semua fitur sekali lagi.

## Tahap 7 — Closed testing: 12 tester × 14 hari

Akun developer pribadi yang baru **wajib** menjalankan closed testing dengan **minimal 12 tester
yang tetap ikut selama 14 hari berturut-turut** sebelum boleh mengajukan rilis Production.

- [ ] Kumpulkan minimal 12 orang yang punya akun Google dan HP Android (teman sekelas, keluarga).
      Sebaiknya ajak 15–20 orang sebagai cadangan.
- [ ] **Testing → Closed testing → Create track**, unggah AAB yang sama (atau promosikan rilis
      dari Internal testing).
- [ ] Tambahkan tester lewat daftar email atau Google Group, lalu bagikan **tautan opt-in**.
      Setiap tester harus membuka tautan itu, menekan *Become a tester*, lalu memasang aplikasi
      dari Play Store.
- [ ] Minta tester benar-benar memakai aplikasi selama 14 hari: memindai, membuka resep, dan
      memberi masukan. Jangan sampai ada yang keluar dari program sebelum 14 hari selesai.
- [ ] Bila ada perbaikan, naikkan versi (lihat bagian bawah), build, lalu unggah sebagai rilis
      baru di track yang sama. Hitungan 14 hari tidak diulang dari nol.

## Tahap 8 — Ajukan akses Production

- [ ] Setelah 14 hari terpenuhi, buka **Dashboard → Apply for production**.
- [ ] Isi pertanyaannya: cara merekrut tester, masukan yang didapat, perubahan yang dibuat,
      dan kesiapan aplikasi. Tulis apa adanya, misalnya “12 teman kuliah menguji fitur pindai
      dan resep; masukan soal X sudah diperbaiki di versi 1.0.0+3”.
- [ ] Tunggu persetujuan Google (biasanya beberapa hari).

## Tahap 9 — Rilis Production

- [ ] **Production → Create new release**, pilih AAB terakhir dari closed testing, lalu tulis
      catatan rilis.
- [ ] Pilih negara: Indonesia (bisa ditambah nanti).
- [ ] Kirim untuk review. Review aplikasi baru bisa memakan waktu beberapa hari sampai sekitar
      seminggu. Setelah disetujui, aplikasi tayang di Play Store.

---

## Setiap rilis berikutnya

1. Naikkan angka di belakang `+` pada `version:` di `pubspec.yaml`, misalnya `1.0.0+2` → `1.0.1+3`.
   Play menolak versionCode yang sudah pernah diunggah, termasuk dari track testing.
2. Build ulang dan cek tanda tangan (Tahap 3).
3. Unggah ke track yang sesuai, lalu kirim untuk review.
4. Bila skema database berubah, jalankan patch SQL-nya **sebelum** rilis baru menyebar.

## Yang sudah disiapkan di kode

| Syarat | Di mana |
|---|---|
| Package name unik `com.racik.app` | `android/app/build.gradle.kts` |
| Target API 36 (terbaru) | `flutter.targetSdkVersion` |
| Penandatanganan rilis dengan upload key | `android/app/build.gradle.kts` + `android/key.properties` (tidak di-commit) |
| Versi `1.0.0+2` (AAB pertama yang dibuat memakai versionCode 1) | `pubspec.yaml` |
| Ikon adaptif + ikon semua ukuran | `android/app/src/main/res/mipmap-*` |
| Kunci AI tidak ada di APK | `supabase/functions/recognize-food` |
| Hapus akun di aplikasi | Profil → Hapus akun (`AuthProvider.deleteAccount`) |
| Hapus akun lewat web | `docs/hapus-akun.html` |
| Kebijakan privasi | `docs/kebijakan-privasi.html` |
| Izin "Jadikan foto resep" bisa ditarik | Detail riwayat (`SharePhotoTile`) |
| Izin hanya yang dipakai (Internet, Kamera) | `AndroidManifest.xml` |
| Penanda "bukan saran medis" | Kartu skor kesehatan |
| Kredit foto berlisensi CC | `supabase/gambar-resep/KREDIT.md`, teks di bawah foto resep |
