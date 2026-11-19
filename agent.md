# AGENTS.md — Racik

Panduan kerja untuk siapa pun (manusia atau AI agent) yang mengubah kode ini.

## 1. Tentang proyek

**Racik** adalah aplikasi mobile pemindai makanan berbasis kecerdasan buatan (tugas PAPB).

Branch:
- `uts` — versi aktif. Struktur mengikuti template praktikum
  (https://github.com/yuisa-scarlet/praktikum_papb) dan berisi ketujuh use case: daftar, login,
  cari resep, detail resep, pindai makanan (AI + fuzzy), riwayat pindai, dan ubah profil.
- `uas` / `main` — versi lama berstruktur `screens/` + `provider` (termasuk admin, favorit, TFLite).
  Dipakai sebagai rujukan saja.

## 2. Stack

| | |
|---|---|
| Flutter / Dart | 3.44.1 / 3.12.1 (`sdk: ^3.12.1`) |
| Platform | Android + Web (Chrome) |
| Backend | Supabase (Postgres + Auth + Storage) |
| AI | OpenRouter Vision lewat Supabase Edge Function `recognize-food` (kunci di server) + logika fuzzy Sugeno (Dart). `--dart-define=AI_DEMO=true` untuk mode demo |
| State | `ChangeNotifier` + `ListenableBuilder`, controller dioper lewat konstruktor (tanpa paket `provider`) |

Paket: `supabase_flutter`, `http`, `camera`, `image_picker`, `image` (kompres foto), `flutter_tts`.
Dev: `flutter_lints`. Versi dikunci sama dengan branch `uas` (sudah terbukti build di AGP 9).

## 3. Perintah

```bash
flutter pub get
flutter analyze                                          # harus bersih sebelum commit
flutter test
flutter run --dart-define-from-file=env.json             # HP/emulator Android
flutter run -d chrome --dart-define-from-file=env.json   # Chrome
```

Di VS Code pakai konfigurasi **Racik** / **Racik (Chrome)** di `.vscode/launch.json`.
`env.json` di-gitignore; contohnya `env.example.json`. Isi `SUPABASE_KEY` hanya dengan
**publishable key**. Tanpa `env.json`, aplikasi menampilkan `SetupPage`.

## 4. Struktur folder (mengikuti template)

```
lib/
  main.dart        init Supabase → buat service & controller → runApp(RacikApp)
  controller/      AuthController, FoodController, ScanController, HistoryController
  enum/            LoadState (initial, loading, loaded, error), AuthStatus
  model/           AppUser, Food, Nutrition, Ingredient, FoodIngredient, RecipeStep, ScanHistory
  service/         AuthService, FoodService, ScanService, StorageService — hanya bicara ke Supabase
  ai/              FoodRecognizer (EdgeFoodRecognizer / demo), FuzzyHealthScore (Sugeno, Dart murni)
  pages/           splash, main, food_list, food_detail, login, register, scan, camera,
                   scan_result, history, history_detail, profile, edit_profile, setup
  widget/          food_card, food_image, nutrition_card, recipe_sections, health_score_card,
                   scan_widgets, state_views
  core/            config, errors (friendlyError), formatters, spacing, theme
assets/images/     logo_racik.png (dipakai SplashPage)
supabase/          schema.sql, seed.sql, hapus_akun.sql, functions/recognize-food (Edge Function AI)
store/             aset & teks listing Google Play + PANDUAN-PUBLIKASI.md
test/              models_test, fuzzy_health_score_test, widget_test (service palsu, tanpa internet)
tool/              test_supabase_api.ps1, buat_upload_key.ps1, buat_aset_playstore.py
```

## 5. Splash screen

Tiga lapis, semuanya memakai logo yang sama (`LOGO_PAPB.png` di root repo):
- **Android bawaan**: `res/drawable*/launch_background.xml` (Android < 12) dan
  `res/values*-v31/styles.xml` (Android 12+, ikon `splash_icon` diberi ruang agar muat di lingkaran).
  Warna latar `@color/splash_background` = `colorScheme.surface` Flutter.
- **Web**: `#splash` di `web/index.html`, dihapus saat event `flutter-first-frame`.
- **Flutter**: `SplashPage` (animasi fade + scale), pindah ke `MainPage` setelah minimal
  1,8 detik dan sesi login selesai dibaca.

Bila logo diganti, buat ulang `assets/images/logo_racik.png`, `drawable-xxhdpi/splash_logo.png`
(432 px), `drawable-xxhdpi/splash_icon.png` (864 px, logo ±390 px di tengah), dan
`web/icons/splash_logo.png`.

## 6. Use case → kode

| Aktor | Use case | Halaman | Logika |
|---|---|---|---|
| Guest | Mendaftar Akun | `RegisterPage` | `AuthController.register` → RPC `username_available`, `auth.signUp` |
| Guest, Pengguna | Melakukan Login | `LoginPage` | `AuthController.login` |
| Guest | Mencari Resep | `FoodListPage` | `FoodController.loadFoods`, `search` (debounce 400 ms), `selectCategory` |
| Guest | Melihat Detail Resep (+ bahan, langkah, nutrisi) | `FoodDetailPage` | data sudah lengkap dari `FoodService.getFoods` |
| Pengguna | Memindai Makanan | `ScanPage` → `CameraPage` / galeri → `ScanResultPage` | `ScanController.scan` |
| ↳ include | Mengidentifikasi Citra Makanan | | `FoodRecognizer.recognize` → Edge Function `recognize-food` |
| ↳ include | Detail Skor Kesehatan & Informasi Nutrisi | `HealthScoreCard`, `NutritionCard` | `FuzzyHealthScore.evaluate` |
| Pengguna | Melihat Hasil Pemindaian | `HistoryPage`, `HistoryDetailPage` | `HistoryController.loadHistory`, `delete` |
| Pengguna | Mengubah Profil Akun | `ProfilePage` → `EditProfilePage` | `AuthController.updateProfile`, `uploadAvatar` (bucket `avatars`) |

### Alur pindai (`ScanController.scan`)
1. `FoodRecognizer.recognize` menebak makanan (label + keyakinan + perkiraan gizi bila OpenRouter).
2. `FoodService.findByName` mencari resep terverifikasi. Bila tidak ada tetapi AI yakin dan memberi
   perkiraan gizi, dibuat `Food` sementara tanpa `id` (tidak disimpan ke `foods`; hanya admin yang
   boleh menambah resep).
3. `FuzzyHealthScore.evaluate` menghitung skor dari nutrisi.
4. Status: keyakinan < 0,60 → `tidak_yakin`; tidak ada data → `tidak_ditemukan`; selain itu `berhasil`.
5. Foto diunggah ke `scan-images/<userId>/…`, lalu baris `scan_history` di-insert. Bila gagal,
   hasil tetap tampil dan halaman menampilkan `InlineError`.

`HistoryController` mengikuti akun yang login lewat listener di `main.dart`
(`authController.addListener(() => historyController.setUser(...))`).

## 7. Rilis Google Play

- Package name `com.nfgcode.racik` (permanen), target API 36, versi di `pubspec.yaml` (`x.y.z+versionCode`).
- Rilis ditandatangani upload key dari `android/key.properties` (tidak masuk git); tanpa file itu
  rilis memakai kunci debug dan DITOLAK Play Store.
- Kunci OpenRouter TIDAK boleh ada di aplikasi; hanya sebagai secret Edge Function.
- Hapus akun wajib ada: Profil → Hapus akun (`delete_my_account`) + `docs/hapus-akun.html`.
- Langkah lengkap: `store/PANDUAN-PUBLIKASI.md`.

## 8. Konvensi kode

- Komentar dan teks UI berbahasa Indonesia; identifier berbahasa Inggris.
- Ikuti pola template: controller punya `LoadState` + `errorMessage`, halaman memakai
  `ListenableBuilder` dan `switch (controller.loadState)`.
- Setiap `Row` dan `Column` dibungkus `Container` (konvensi praktikum). Karena itu lint
  `avoid_unnecessary_containers` dimatikan di `analysis_options.yaml`.
- Error ditampilkan lewat `friendlyError(e)` di `core/errors.dart`. Error aksi di form memakai
  `InlineError`; halaman yang gagal memuat data memakai `ErrorState` (keduanya di `widget/state_views.dart`).
- Semua jarak memakai `AppSpacing` (`core/spacing.dart`); tepi halaman `AppSpacing.page` (16).
- Navigator/ScaffoldMessenger disimpan ke variabel sebelum `await`; setelah `await`, cek `mounted`.
- `TextEditingController` dan `Timer` selalu di-dispose.
- Aksesibilitas: setiap `IconButton` punya tooltip, baris label–nilai dibungkus `MergeSemantics`.
- API terbaru: `Supabase.initialize(publishableKey: ...)` (bukan `anonKey`).

## 9. Larangan

- Jangan memasukkan secret/service_role key ke kode, env, atau repo.
- Jangan membuat query Supabase langsung dari widget. Selalu lewat service.
- Jangan mengganti nama tabel/kolom tanpa memperbarui model, service, dan `supabase/schema.sql`.
