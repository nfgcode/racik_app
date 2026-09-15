# Racik

Aplikasi mobile pemindai makanan berbasis kecerdasan buatan (Flutter + Supabase + TensorFlow Lite).

## Menjalankan

1. Buat project di [supabase.com](https://supabase.com), buka **SQL Editor**, jalankan
   `supabase/schema.sql` lalu `supabase/seed.sql`.
2. Untuk masa pengembangan, matikan **Authentication → Sign In / Providers → Email → Confirm email**.
3. Pastikan file `env.json` berisi `SUPABASE_URL`, `SUPABASE_KEY`, dan `OPENROUTER_API_KEY` (Vision AI):

   ```json
   {
     "SUPABASE_URL": "https://<ref>.supabase.co",
     "SUPABASE_KEY": "sb_publishable_...",
     "OPENROUTER_API_KEY": "sk-or-v1-...",
     "OPENROUTER_MODEL": "qwen/qwen-2.5-vl-72b-instruct"
   }
   ```

4. Jalankan:

   ```bash
   flutter pub get
   flutter run --dart-define-from-file=env.json
   ```

5. Daftar akun lewat aplikasi, lalu jadikan admin di SQL Editor:

   ```sql
   update public.users set role = 'admin' where username = 'username_anda';
   ```

Aplikasi menggunakan model Vision AI **Qwen 2.5 VL 72B** (atau TFLite/Demo lokal). AI otomatis mengenali makanan lokal Indonesia dan mengestimasi nilai gizinya ke database jika belum terdaftar, lalu mengevaluasi skor kesehatan menggunakan **Logika Fuzzy Sugeno**.

## Struktur

```
lib/
  main.dart, app.dart   titik masuk, Provider, AuthGate (layar per aktor)
  core/                 konfigurasi, tema, format, pesan error
  models/               satu kelas per tabel ERD
  services/             akses Supabase, satu file per kelompok use case
  ai/                   pengenal makanan (TFLite/demo) + skor fuzzy
  providers/            state login & model AI
  widgets/              komponen yang dipakai ulang
  screens/              layar, dikelompokkan per fitur
supabase/               schema.sql (tabel, trigger, RLS, storage) + seed.sql
test/                   tes logika fuzzy dan parsing model
```
