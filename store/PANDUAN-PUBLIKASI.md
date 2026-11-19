# Panduan publikasi Racik ke Google Play

Urutan langkah dari kode sampai aplikasi tayang. Centang satu per satu.

## A. Supabase (backend)

- [ ] **Restore proyek** di dashboard Supabase bila sedang di-pause. Proyek gratis otomatis di-pause
      bila lama tidak dipakai; untuk aplikasi publik pertimbangkan paket berbayar supaya tidak mati.
- [ ] **Jalankan `supabase/hapus_akun.sql`** di SQL Editor (fungsi `delete_my_account` + kebijakan
      Storage). Tanpa ini tombol "Hapus akun" gagal.
- [ ] **Auth → Sign In / Providers → Email**: nyalakan *Confirm email* untuk versi publik.
- [ ] **Deploy Edge Function** `recognize-food` (kunci AI aman di server):

```bash
npm install -g supabase
supabase login
supabase secrets set OPENROUTER_API_KEY=sk-or-KUNCI_BARU --project-ref anpdybkgszizugifqrbw
supabase functions deploy recognize-food --project-ref anpdybkgszizugifqrbw
```

- [ ] **Buat kunci OpenRouter baru** dan hapus yang lama di dashboard OpenRouter. Kunci lama pernah
      ikut ter-compile ke build sebelumnya, jadi anggap sudah bocor. Hapus juga baris
      `OPENROUTER_API_KEY` dari `env.json` (aplikasi tidak memakainya lagi).
- [ ] Pasang **batas kredit** di OpenRouter supaya tagihan tidak membengkak.
- [ ] Uji: `powershell -ExecutionPolicy Bypass -File tool\test_supabase_api.ps1 -Login`

## B. Halaman web wajib (GitHub Pages)

- [ ] Ganti `[EMAIL-KONTAK]` di `docs/kebijakan-privasi.html`, `docs/hapus-akun.html`, dan
      `store/listing.md` dengan email yang akan kamu pakai untuk urusan aplikasi.
- [ ] GitHub repo → **Settings → Pages** → *Deploy from a branch* → branch `main`, folder `/docs`.
- [ ] Pastikan dua URL ini bisa dibuka:
  - https://nfgcode.github.io/racik_app/kebijakan-privasi.html
  - https://nfgcode.github.io/racik_app/hapus-akun.html

## C. Build rilis (.aab)

- [ ] Buat upload key (sekali saja), lalu **cadangkan** `android/upload-keystore.jks` dan
      `android/key.properties` di tempat aman:

```bash
powershell -ExecutionPolicy Bypass -File tool\buat_upload_key.ps1
```

- [ ] Build App Bundle:

```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

      Hasil: `build/app/outputs/bundle/release/app-release.aab`.
- [ ] Setiap rilis berikutnya, naikkan angka di belakang `+` pada `version:` di `pubspec.yaml`
      (mis. `1.0.0+1` → `1.0.1+2`). Play menolak versionCode yang sama.

## D. Play Console

- [ ] Daftar akun developer di https://play.google.com/console (biaya sekali US$25, verifikasi identitas).
- [ ] **Create app**: nama "Racik - Pindai Makanan & Gizi", bahasa Indonesia, *App*, *Free*.
- [ ] **Store listing**: isi dari `store/listing.md` dan unggah grafis di folder `store/`.
- [ ] **App content** (Policy → App content):
  - Privacy policy: URL kebijakan privasi di atas.
  - App access: *All or some functionality is restricted* → isi **akun uji** (buat akun khusus di
    aplikasi, mis. reviewer@…, lalu tulis email + password-nya di sini) supaya reviewer bisa
    mencoba Pindai, Riwayat, dan Profil.
  - Ads: *No*.
  - Content rating: isi kuesioner (aplikasi utilitas/makanan, tanpa kekerasan, tanpa konten
    pengguna yang dibagikan ke orang lain). Hasilnya biasanya *Semua umur / 3+*.
  - Target audience: pilih **13 tahun ke atas** (jangan pilih di bawah 13 agar tidak masuk
    program Families).
  - Data safety: lihat tabel di bawah.
  - Account deletion: URL halaman hapus akun di atas.
  - Health apps declaration (bila diminta): aplikasi informasi gizi umum, bukan perangkat medis.
- [ ] **Testing → Closed testing**: unggah `.aab`, undang tester lewat email/Google Group.
      Akun developer pribadi baru wajib menjalankan **closed testing dengan minimal 12 tester
      selama 14 hari berturut-turut** sebelum boleh mengajukan rilis Production.
- [ ] **Production**: setelah syarat di atas terpenuhi, buat rilis dan kirim untuk review.

### Jawaban Data safety

| Pertanyaan | Jawaban |
|---|---|
| Mengumpulkan / membagikan data? | Mengumpulkan: Ya. Membagikan ke pihak ketiga: Tidak (Supabase & OpenRouter adalah *service provider*) |
| Dienkripsi saat dikirim? | Ya (HTTPS) |
| Pengguna bisa minta hapus data? | Ya (Profil → Hapus akun, dan halaman web) |
| Info pribadi | Nama, Alamat email, ID pengguna (username) — fungsi aplikasi & manajemen akun |
| Foto dan video | Foto — fungsi aplikasi (foto makanan dipindai, foto profil opsional) |
| Aktivitas aplikasi | Interaksi di aplikasi (riwayat pindai) — fungsi aplikasi |
| Lokasi, kontak, keuangan, kesehatan pribadi, pesan | Tidak dikumpulkan |
| Wajib atau opsional? | Email & username wajib untuk membuat akun; foto profil opsional; resep bisa dibuka tanpa akun |

## E. Yang sudah disiapkan di kode

| Syarat | Di mana |
|---|---|
| Package name unik `com.racik.app` | `android/app/build.gradle.kts` |
| Target API 36 (terbaru) | `flutter.targetSdkVersion` |
| Penandatanganan rilis dengan upload key | `android/app/build.gradle.kts` + `tool/buat_upload_key.ps1` |
| Versi 1.0.0 (versionCode 1) | `pubspec.yaml` |
| Ikon adaptif + ikon semua ukuran | `android/app/src/main/res/mipmap-*` |
| Kunci AI tidak ada di APK | `supabase/functions/recognize-food` |
| Hapus akun di aplikasi | Profil → Hapus akun (`AuthProvider.deleteAccount`) |
| Hapus akun lewat web | `docs/hapus-akun.html` |
| Kebijakan privasi | `docs/kebijakan-privasi.html` |
| Izin hanya yang dipakai (Internet, Kamera) | `AndroidManifest.xml` |
| Penanda "bukan saran medis" | Kartu skor kesehatan |
