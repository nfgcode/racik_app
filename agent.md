# AGENTS.md — Racik

Panduan kerja untuk siapa pun (manusia atau AI agent) yang mengubah kode ini.

## 1. Tentang proyek

**Racik** adalah aplikasi mobile pemindai makanan berbasis kecerdasan buatan (tugas PAPB).

Branch:
- `main` — versi **progress**: tampilan + login/daftar Supabase + daftar & detail resep.
  Struktur mengikuti template praktikum (https://github.com/yuisa-scarlet/praktikum_papb).
- `uas` — versi **lengkap** untuk UAS: pindai AI (OpenRouter/TFLite), skor fuzzy, riwayat,
  ubah profil, favorit, dan halaman admin. Fitur dari sini dipindah ke `main` bertahap.

## 2. Stack

| | |
|---|---|
| Flutter / Dart | 3.44.1 / 3.12.1 (`sdk: ^3.12.1`) |
| Platform | Android + Web (Chrome) |
| Backend | Supabase (Postgres + Auth) |
| State | `ChangeNotifier` + `ListenableBuilder`, controller dioper lewat konstruktor (tanpa paket `provider`) |

Paket: `supabase_flutter`, `http` (hanya untuk mengenali `ClientException`). Dev: `flutter_lints`.

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
  controller/      AuthController, FoodController (ChangeNotifier)
  enum/            LoadState (initial, loading, loaded, error), AuthStatus
  model/           AppUser, Food, Nutrition, Ingredient, FoodIngredient, RecipeStep (fromJson)
  service/         AuthService, FoodService — hanya bicara ke Supabase, tanpa widget
  pages/           main, food_list, food_detail, login, register, scan, history, profile, setup
  widget/          food_card, food_image, nutrition_card, recipe_sections, state_views
  core/            config, errors (friendlyError), formatters, theme
supabase/          schema.sql, seed.sql (skema lengkap, dipakai juga oleh branch uas)
test/              models_test, widget_test (service palsu, tanpa internet)
```

## 5. Use case → kode (progress)

| Aktor | Use case | Halaman | Logika |
|---|---|---|---|
| Guest | Mendaftar Akun | `RegisterPage` | `AuthController.register` → RPC `username_available`, `auth.signUp` |
| Guest, Pengguna | Melakukan Login | `LoginPage` | `AuthController.login` |
| Guest | Mencari Resep | `FoodListPage` | `FoodController.loadFoods`, `search` (debounce 400 ms), `selectCategory` |
| Guest | Melihat Detail Resep (+ bahan, langkah, nutrisi) | `FoodDetailPage` | data sudah lengkap dari `FoodService.getFoods` |
| Pengguna | Memindai Makanan | `ScanPage` | tampilan saja — fitur di branch `uas` |
| Pengguna | Melihat Hasil Pemindaian | `HistoryPage` | tampilan saja — fitur di branch `uas` |
| Pengguna | Mengubah Profil Akun | `ProfilePage` | baru tampil profil + Keluar — ubah profil di branch `uas` |

## 6. Konvensi kode

- Komentar dan teks UI berbahasa Indonesia; identifier berbahasa Inggris.
- Ikuti pola template: controller punya `LoadState` + `errorMessage`, halaman memakai
  `ListenableBuilder` dan `switch (controller.loadState)`.
- Setiap `Row` dan `Column` dibungkus `Container` (konvensi praktikum). Karena itu lint
  `avoid_unnecessary_containers` dimatikan di `analysis_options.yaml`.
- Error ditampilkan lewat `friendlyError(e)` di `core/errors.dart`.
- Navigator/ScaffoldMessenger disimpan ke variabel sebelum `await`; setelah `await`, cek `mounted`.
- `TextEditingController` dan `Timer` selalu di-dispose.
- Aksesibilitas: setiap `IconButton` punya tooltip, baris label–nilai dibungkus `MergeSemantics`.
- API terbaru: `Supabase.initialize(publishableKey: ...)` (bukan `anonKey`).

## 7. Larangan

- Jangan memasukkan secret/service_role key ke kode, env, atau repo.
- Jangan membuat query Supabase langsung dari widget. Selalu lewat service.
- Jangan mengganti nama tabel/kolom tanpa memperbarui model, service, dan `supabase/schema.sql`.
