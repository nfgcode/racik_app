# AGENTS.md — Racik

Panduan kerja untuk siapa pun (manusia atau AI agent) yang mengubah kode ini.
Baca bagian **Status** dan **Larangan** sebelum mulai.

## 1. Tentang proyek

**Racik** adalah aplikasi mobile pemindai makanan berbasis kecerdasan buatan (tugas PAPB).
- Pengguna memotret makanan, lalu model AI mengenali jenisnya.
- Aplikasi kemudian menampilkan skor kesehatan (dihitung dengan logika fuzzy) dan informasi nutrisinya.
- Tamu bisa mencari dan membaca resep.
- Admin mengelola resep, bahan, dan akun, serta melihat statistik pemindaian.

Rujukan desain utama adalah `PAPB-Asik.Project-Racik.pdf`: halaman 1 berisi use case, halaman 2 berisi ERD, dan halaman 3 adalah duplikat halaman 2.

## 2. Stack

| | |
|---|---|
| Flutter / Dart | 3.44.1 / 3.12.1 (`sdk: ^3.12.1`) |
| Platform | **Android saja** (tidak ada `ios/`) — AGP 9.0.1, Kotlin 2.3.20, Gradle 9.1.0, Java 17 |
| Backend | Supabase (Postgres + Auth + Storage) |
| State | `provider` (ChangeNotifier) |
| AI | Multimodal Vision (OpenRouter Qwen 2.5 VL 72B / TFLite) + Logika Fuzzy Sugeno (Dart) |

Paket: `supabase_flutter ^2.17.2`, `provider ^6.1.5+1`, `camera ^0.12.1`,
`image_picker ^1.2.3`, `tflite_flutter ^0.12.1`, `image ^4.9.2`, `flutter_tts ^4.2.5`.
Dev: `flutter_lints ^6.0.0`.

## 3. Perintah

```bash
flutter pub get
flutter analyze                               # harus bersih sebelum commit
flutter test
flutter run --dart-define-from-file=env.json  # HP/emulator Android
flutter build apk --debug
```

`env.json` sudah di-gitignore. Contohnya ada di `env.example.json`:

```json
{ "SUPABASE_URL": "https://<ref>.supabase.co", "SUPABASE_KEY": "sb_publishable_..." }
```

Isi `SUPABASE_KEY` hanya dengan **publishable key**. Tanpa `env.json`, aplikasi menampilkan layar
"Racik belum terhubung ke Supabase".

## 4. Arsitektur

```
screens/, widgets/    UI — ambil dependensi via context.read / watch / select
      │
providers/            AuthProvider (siapa yang login), RecognizerProvider (model AI, lazy)
      │
services/             akses data, satu service per kelompok use case
      │               hanya bicara ke Supabase, tanpa import widget; kembalikan model
      ▼
Supabase              ai/  → FoodRecognizer (TFLite/demo), FuzzyHealthScore (Dart murni)
models/               satu kelas per tabel ERD (fromMap / toMap)
core/                 config, errors (friendlyError), formatters, theme
```

Semua service dan provider didaftarkan satu kali di `lib/app.dart` (`MultiProvider`).

## 5. Struktur folder

```
lib/
  main.dart            init Supabase → runApp
  app.dart             RacikApp, MultiProvider, AuthGate, layar setup
  core/                config · errors · formatters · theme
  models/              app_user · food · nutrition · ingredient · food_ingredient
                       recipe_step · scan_history · favorite
  ai/                  food_recognizer · tflite_food_recognizer
                       demo_food_recognizer · fuzzy_health_score
  services/            auth · food · ingredient · scan · scan_pipeline
                       storage · favorite · user · stats
  providers/           auth_provider · recognizer_provider
  widgets/             food_card · food_image · nutrition_card · health_score_card
                       recipe_sections · scan_widgets · state_views
  screens/
    auth/              login_screen · register_screen
    home/              main_shell
    recipe/            recipe_search_screen · recipe_detail_screen
    scan/              scan_home_screen · camera_capture_screen · scan_result_screen
    history/           scan_history_screen · scan_history_detail_screen
    profile/           profile_screen · edit_profile_screen · favorites_screen
    admin/             admin_shell · admin_foods_screen · food_form_screen
                       admin_ingredients_screen · admin_stats_screen · admin_users_screen
assets/models/         racik_food.tflite + labels.txt (belum ada → mode demo)
supabase/              schema.sql, seed.sql — BELUM DIBUAT (lihat §12)
test/                  BELUM DIBUAT
```

## 6. Aktor dan navigasi

`AuthProvider.actor` bertipe `enum Actor { memuat, guest, pengguna, admin }`. `AuthGate` di `app.dart`
memilih kerangka layar berdasarkan nilai itu:

| Actor | Layar |
|---|---|
| memuat | spinner (sesi belum terbaca) |
| guest / pengguna | `MainShell`: Resep · Pindai · Riwayat · Profil. Guest melihat `LoginRequired` di tiga tab terakhir |
| admin | `AdminShell`: Resep · Bahan · Statistik · Akun |

Peran diambil dari `users.role`. Ada dua kondisi yang membuat pengguna langsung di-logout dengan pesan:
- `is_active = false`;
- akun tidak punya baris di tabel `users`.

## 7. Use case → kode

| Aktor | Use case | Layar | Logika |
|---|---|---|---|
| Guest | Mendaftar Akun | `RegisterScreen` | `AuthProvider.register` → RPC `username_available`, `auth.signUp` (metadata `username`, `full_name`) |
| Guest | Melakukan Login | `LoginScreen` | `AuthService.login` |
| Guest | Mencari Resep | `RecipeSearchScreen` | `FoodService.search`, `categories` (debounce 400 ms) |
| Guest | Melihat Detail Resep | `RecipeDetailScreen` | `FoodService.getDetail` |
| ↳ include | Menampilkan Bahan & Langkah Memasak | `IngredientList`, `StepList` | |
| ↳ include | Menampilkan Informasi Nutrisi | `NutritionCard` | |
| Pengguna | Memindai Makanan | `ScanHomeScreen` → `CameraCaptureScreen` / galeri → `ScanResultScreen` | `ScanPipeline.run` |
| ↳ include | Mengidentifikasi Citra Makanan | | `FoodRecognizer.recognize` |
| ↳ include | Detail Skor Kesehatan & Informasi Nutrisi | `HealthScoreCard`, `NutritionCard` | `FuzzyHealthScore.evaluate` |
| Pengguna | Melihat Hasil Pemindaian | `ScanHistoryScreen`, `ScanHistoryDetailScreen` | `ScanService.historyOf`, `delete` |
| Pengguna | Mengubah Profil Akun | `EditProfileScreen` | `AuthProvider.updateProfile`, `StorageService` (bucket `avatars`) |
| Admin | Mengelola Data Resep | `AdminFoodsScreen`, `FoodFormScreen` | `FoodService.saveFood`, `setVerified`, `deleteFood` |
| Admin | Mengelola Data Bahan | `AdminIngredientsScreen` | `IngredientService` |
| Admin | Melihat Statistik Pemindaian | `AdminStatsScreen` | `StatsService.load` |
| Admin | Mengelola Akun Pengguna | `AdminUsersScreen` | `UserService.updateAccess` (role, is_active) |
| — | Favorit (tabel ada, use case belum) | tombol hati di detail resep, `FavoritesScreen` | `FavoriteService` |
| semua | Logout | `ProfileScreen`, app bar `AdminFoodsScreen` | `AuthProvider.logout` |

Setiap kali layar diubah atau ditambah, perbarui dua hal:
- tabel ini;
- komentar `/// Use case: ...` di atas kelas layarnya.

## 8. ERD → model

| Tabel | Kelas | Catatan |
|---|---|---|
| users | `AppUser` | Tidak ada email/password; keduanya disimpan Supabase Auth. `users.id` = `auth.users.id` |
| foods | `Food` | Dua FK ke users (`created_by`, `verified_by`) |
| nutritions | `Nutrition` | 1:1 dengan foods (`food_id` unik) |
| ingredients | `Ingredient` | nama unik |
| food_ingredients | `FoodIngredient` | penghubung foods ↔ ingredients + takaran |
| steps | `RecipeStep` | bukan `Step`, supaya tidak bentrok dengan widget Flutter |
| scan_history | `ScanHistory` | `food_id` boleh null |
| favorites | `Favorite` | |

Konvensi model:
- Kolom `snake_case` dipetakan ke field `camelCase`.
- Kolom tanpa NN menjadi field nullable.
- Kolom `numeric` diparse lewat helper, karena bisa datang sebagai int, double, atau String.
- Field hasil join tidak ikut `toMap()`. Contohnya `Food.nutrition/steps/ingredients`, `ScanHistory.foodName`, dan `FoodIngredient.ingredient`.

Nilai domain (tulis persis):

| Kolom | Nilai |
|---|---|
| `users.role` | `pengguna`, `admin` |
| `foods.source` | `admin`, `ai` |
| `foods.difficulty` | `mudah`, `sedang`, `sulit` |
| `scan_history.scan_status` | `berhasil`, `tidak_yakin`, `tidak_ditemukan` |
| `scan_history.fuzzy_label` | `Sehat`, `Cukup Sehat`, `Kurang Sehat` |
| `scan_history.ai_confidence` | persen 0–100 (Dart: `Prediction.confidence` 0–1, `.percent` 0–100) |
| `scan_history.fuzzy_score` | 0–100, dua desimal |

## 9. Alur pindai (`services/scan_pipeline.dart`)

1. `FoodRecognizer.recognize(bytes)` menghasilkan tiga prediksi teratas.
2. `FoodService.findByName(top.label)` mencari resep dengan `ilike` tanpa wildcard. Hanya resep `is_verified` yang dicari.
3. Jika resep punya data nutrisi, `FuzzyHealthScore.evaluate` menghitung skornya.
4. Status ditentukan begini:
   - keyakinan di bawah `AppConfig.confidenceThreshold` (0.60) → `tidak_yakin`;
   - resep tidak ditemukan → `tidak_ditemukan`;
   - selain itu → `berhasil`.
5. Foto diunggah ke `scan-images/<userId>/<millis>.jpg`, lalu baris baru di-insert ke `scan_history`.
   - Jika penyimpanan gagal, hasil pindai tetap ditampilkan.
   - Pesan gagalnya muncul lewat `saveError`.

Aksesibilitas di layar hasil:
- `SemanticsService.sendAnnouncement` membacakan hasil untuk pengguna TalkBack.
- Tombol "Bacakan hasil" memakai `flutter_tts` (bahasa `id-ID`, kecepatan 0.5).

## 10. AI

### Model

- **File:** `assets/models/racik_food.tflite` dan `labels.txt`.
- **Format label:** format Teachable Machine (`0 Nasi Goreng`); angka di depan dibuang.
- **Aturan label:** setiap label harus sama dengan `foods.name`.
- **Input:** `[1, N, N, 3]`.
  - Model float32 memakai piksel `/127.5 − 1`.
  - Model uint8 memakai piksel mentah.
  - Output uint8 dibagi 255.
- **Pra-proses:** `copyResizeCropSquare` (potong tengah jadi persegi, lalu resize), dijalankan di `Isolate.run`.
- **Mode demo:** jika model gagal dimuat, aplikasi memakai `DemoFoodRecognizer`.
  - Tebakannya deterministik dari byte foto.
  - Labelnya Nasi Goreng, Gado-Gado, Soto Ayam, Rendang, dan Pisang Goreng.
  - UI selalu menampilkan pita "Mode demo".
- **Mengganti mesin AI** (misalnya API cloud lewat Edge Function): cukup buat implementasi baru `FoodRecognizer`. Tidak ada layar yang perlu diubah.

### Fuzzy (`ai/fuzzy_health_score.dart`)

Metodenya Sugeno orde-nol. Semua nilai dihitung per porsi.

| Input | rendah | sedang | tinggi |
|---|---|---|---|
| Gula (g) | turun 5→12 | segitiga 5–12–25 | naik 12→25 |
| Lemak (g) | turun 5→12 | segitiga 5–12–21 | naik 12→21 |
| Natrium (mg) | turun 300→600 | segitiga 300–600–1000 | naik 600→1000 |
| Serat (g) | turun 2→5 | — | naik 2→5 |

Cara menghitung skor:
- Ada 54 aturan, yaitu semua kombinasi himpunan di atas.
- α setiap aturan = nilai minimum derajat keanggotaannya.
- Keluaran z per aturan:
  - mulai dari 90;
  - dikurangi penalti tiap zat: rendah 0, sedang 10, tinggi 30;
  - ditambah 10 jika serat tinggi;
  - dibatasi ke rentang 0–100.
- Skor akhir = Σαz / Σα.

Label akhir:
- ≥ 75 → Sehat;
- ≥ 50 → Cukup Sehat;
- sisanya → Kurang Sehat.

Nilai nutrisi yang kosong dianggap 0 dan ditandai `hasMissingData`.

**Semua batas di atas masih contoh.** Validasi dulu dengan rancangan fuzzy tim dan sumber gizi (TKPI/Kemenkes) sebelum masuk laporan.

## 11. Konvensi kode

Umum:
- Komentar dan teks UI berbahasa Indonesia; identifier berbahasa Inggris.
- Service tidak memakai Flutter dan selalu mengembalikan model.
- Error ditampilkan lewat `friendlyError(e)` di `core/errors.dart`. Pemetaan pesan baru ditambahkan di sana, bukan di layar.

Async dan lifecycle:
- Semua `context.read` diambil sebelum `await` pertama.
- Setelah `await`, cek `mounted`.
- `ScaffoldMessenger` dan `Navigator` disimpan ke variabel sebelum `await`.
- Future disimpan di State (`initState`), tidak pernah dibuat di `build()`.
- `TextEditingController`, `CameraController`, dan `Timer` selalu di-dispose.
- Pakai `context.select` bila hanya butuh satu nilai dari provider.

Widget yang dipakai ulang:
- `NutritionCard`
- `HealthScoreCard` / `HealthScoreBadge`
- `ScanHeader`, `ScanStatusBanner`
- `FoodCard`, `FoodImage`
- `EmptyState` / `ErrorState` / `LoginRequired`

Aksesibilitas (wajib):
- Setiap `IconButton` punya tooltip.
- Kontrol buatan sendiri dibungkus `Semantics`.
- Baris label–nilai dibungkus `MergeSemantics`.
- Target sentuh minimal 48 dp; tombol utama 52 dp.
- Warna tidak pernah dipakai sendirian, selalu disertai ikon dan teks (`HealthStyle`).
- Teks loading memakai `liveRegion`.
- HP bergetar singkat saat memotret.

Fitur Dart 3 yang dipakai: records, switch expression, pattern, `.indexed`, null-aware element
(`?trailing`), dan parameter wildcard `_`.

API di versi terpasang yang sudah berubah (jangan kembali ke cara lama):
- `Supabase.initialize(publishableKey: ...)`, karena `anonKey` sudah deprecated.
- `SemanticsService.sendAnnouncement(View.of(context), ...)`, karena `announce` sudah deprecated.
- `DropdownButtonFormField(initialValue: ...)`, karena `value` sudah deprecated.
- `from(t).count()` mengembalikan `int`. Untuk menunggu beberapa query yang tipenya berbeda, pakai `Future.wait<Object>`.
- Relasi 1:1 bisa datang sebagai objek atau list. Ini sudah ditangani `Food._parseNutrition`.
- Jangan embed `users` dari `foods` tanpa menyebut nama FK-nya, karena ada dua FK ke `users`.

## 12. Kontrak backend (untuk `supabase/schema.sql`)

File SQL **belum dibuat**. Kode aplikasi bergantung pada semua hal di bawah ini.

**Tabel dan trigger**
- Semua tabel sesuai ERD, di schema `public`. `users.id` adalah FK ke `auth.users(id)`.
- Trigger `handle_new_user` berjalan saat insert ke `auth.users`:
  - membuat baris `public.users` dari `raw_user_meta_data` (`username`, `full_name`);
  - mengisi `role = 'pengguna'` dan `is_active = true`.
- Fungsi `username_available(p_username text) returns boolean`: `security definer`, dan boleh dipanggil anon.
- Trigger yang menaikkan `foods.scan_count` setiap ada insert `scan_history` dengan `food_id`.

**Foreign key**
- Tabel nutritions, steps, food_ingredients, dan favorites memakai `on delete cascade` dari foods.
- `scan_history.food_id` memakai `on delete set null`.
- `food_ingredients.ingredient_id` memakai `restrict`, sehingga menghapus bahan yang masih terpakai menghasilkan error 23503.

**Unique**
- Wajib: `users.username`, `ingredients.name`, `nutritions.food_id`.
- Disarankan: `food_ingredients(food_id, ingredient_id)` dan `favorites(user_id, food_id)`.

**RLS** (memakai helper `is_admin()`)

| Tabel | Baca | Tulis |
|---|---|---|
| foods dan tabel anaknya | publik jika `is_verified`; admin melihat semua | hanya admin |
| scan_history | milik sendiri; admin membaca semua | milik sendiri |
| favorites | milik sendiri | milik sendiri |
| users | milik sendiri + admin | kolom profil milik sendiri; `role`/`is_active` hanya admin (dijaga trigger) |

**Storage**
- Bucket publik: `scan-images`, `food-images`, `avatars`.
- Pengguna hanya boleh mengunggah ke folder `<auth.uid()>/`. Admin juga boleh mengunggah ke `foods/`.

**Lain-lain**
- Admin pertama dibuat manual: `update public.users set role = 'admin' where username = '...';`
- Saat pengembangan, "Confirm email" boleh dimatikan. Kalau tetap aktif, dialog konfirmasi di aplikasi sudah menanganinya.
- `seed.sql` berisi resep contoh yang namanya sama dengan label `DemoFoodRecognizer`. Nilai gizinya ditandai sebagai perkiraan.

## 13. Status (11 Sep 2026)

Selesai:
- Seluruh `lib/`: model, service, provider, AI, fuzzy, dan layar untuk ketiga aktor.
- Dependensi di `pubspec.yaml` dan aset `assets/models/`.
- Izin Android: INTERNET, CAMERA, dan query TTS.
- Label aplikasi "Racik".
- `env.example.json`, dan `env.json` sudah masuk `.gitignore`.

Belum diverifikasi (kerjakan dulu):
- [ ] `flutter analyze`. Sempat terhenti, jadi kode belum pernah dikompilasi.
- [ ] `flutter build apk --debug`, untuk memastikan camera dan tflite_flutter cocok dengan AGP 9.
- [ ] Uji di HP nyata: izin kamera, siklus hidup kamera, dan TTS bahasa Indonesia.

Belum dibuat:
- [ ] `supabase/schema.sql` dan `supabase/seed.sql` (lihat §12).
- [ ] `test/fuzzy_health_score_test.dart`:
  - jumlah derajat keanggotaan selalu 1;
  - skor tidak naik ketika gula naik;
  - contoh label untuk beberapa kasus.
- [ ] `test/models_test.dart`, untuk parsing hasil join.
- [ ] `README.md` proyek dan dokumen belajar Flutter.
- [ ] Model `racik_food.tflite`. Sampai model ini ada, aplikasi berjalan dalam mode demo.
- [ ] `applicationId` masih `com.example.racik_app`.
- [ ] Warna `HealthStyle` belum disesuaikan untuk tema gelap.
- [ ] Proyek belum memakai git. Jalankan `git init` sebelum perubahan berikutnya.

## 14. Celah di diagram (bawa ke tim)

1. Admin tidak terhubung ke "Melakukan Login", padahal admin juga harus login.
2. Pengguna tidak terhubung ke Mencari Resep dan Melihat Detail Resep. Tambahkan generalisasi Pengguna → Guest.
3. Tabel `favorites` belum punya use case. Usulan: "Menyimpan Resep Favorit".
4. `scan_history` tidak menyimpan label tebakan saat `food_id` kosong. Akibatnya admin tidak tahu makanan apa yang belum terdata. Usulan: tambah kolom `predicted_label varchar(120)`.
5. "Mengelola Akun Pengguna" diimplementasikan sebagai ubah peran dan nonaktifkan akun. Menghapus akun Auth butuh secret key, jadi tidak dilakukan dari aplikasi.
6. `foods.scan_count` adalah data turunan yang dijaga trigger. Jangan diubah manual.
7. Halaman 3 PDF duplikat halaman 2.

## 15. Larangan

- Jangan memasukkan secret/service_role key ke kode, env, atau repo.
- Jangan mengganti nama tabel atau kolom tanpa memperbarui model, service, SQL, dan dokumen ini sekaligus.
- Jangan membuat query Supabase langsung dari widget. Selalu lewat service.
- Jangan menampilkan hasil `DemoFoodRecognizer` tanpa pita "Mode demo".
- Jangan menyampaikan skor kesehatan hanya dengan warna. Selalu sertakan ikon dan teks.