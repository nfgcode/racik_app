// Tes asap (smoke test): membangun seluruh aplikasi sebagai Guest, Pengguna,
// dan Admin memakai service PALSU, jadi tidak butuh Supabase maupun internet.
// Tujuannya menangkap error yang hanya muncul saat widget benar-benar dibangun
// (layout overflow, assertion provider, null yang tak terduga).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:racik_app/app.dart';
import 'package:racik_app/models/app_user.dart';
import 'package:racik_app/models/food.dart';
import 'package:racik_app/models/ingredient.dart';
import 'package:racik_app/models/scan_history.dart';
import 'package:racik_app/providers/auth_provider.dart';
import 'package:racik_app/providers/recognizer_provider.dart';
import 'package:racik_app/screens/scan/scan_result_screen.dart';
import 'package:racik_app/services/auth_service.dart';
import 'package:racik_app/services/favorite_service.dart';
import 'package:racik_app/services/food_service.dart';
import 'package:racik_app/services/ingredient_service.dart';
import 'package:racik_app/services/scan_service.dart';
import 'package:racik_app/services/stats_service.dart';
import 'package:racik_app/services/storage_service.dart';
import 'package:racik_app/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------- data ---

final gadoGado = Food.fromMap({
  'id': 'f1',
  'name': 'Gado-Gado',
  'category': 'Sayuran',
  'serving_size': '1 piring (350 g)',
  'cook_time_minutes': 30,
  'difficulty': 'sedang',
  'is_verified': true,
  'scan_count': 3,
  'nutritions': {
    'calories': 380, 'protein_g': 16, 'fat_g': 20, 'carbs_g': 34,
    'sugar_g': 9, 'sodium_mg': 600, 'fiber_g': 7,
  },
  'steps': [
    {'step_order': 1, 'instruction': 'Rebus sayuran.', 'duration_minutes': 15},
    {'step_order': 2, 'instruction': 'Siram dengan saus kacang.'},
  ],
  'food_ingredients': [
    {
      'ingredient_id': 'i1',
      'quantity': 60,
      'note': 'goreng dulu',
      'ingredients': {'id': 'i1', 'name': 'Kacang tanah', 'unit': 'gram'},
    },
  ],
});

AppUser user(String role) => AppUser(
      id: 'u1',
      username: 'nurfauzan',
      fullName: 'Nurfauzan Gymnastiar',
      role: role,
      isActive: true,
    );

// ------------------------------------------------------ service palsu ---
// `implements` + noSuchMethod: cukup tulis method yang dipakai layar.

class FakeAuthService implements AuthService {
  FakeAuthService(this.profile);

  final AppUser? profile;

  @override
  Stream<AuthState> get authChanges => Stream.value(AuthState(
        AuthChangeEvent.initialSession,
        profile == null
            ? null
            : Session(
                accessToken: 'token',
                tokenType: 'bearer',
                user: User(
                  id: profile!.id,
                  appMetadata: const {},
                  userMetadata: const {},
                  aud: 'authenticated',
                  createdAt: '2026-09-11T00:00:00Z',
                ),
              ),
      ));

  @override
  String? get currentEmail => profile == null ? null : 'nurfauzan@example.com';

  @override
  Future<AppUser?> fetchProfile(String userId) async => profile;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFoodService implements FoodService {
  @override
  Future<List<Food>> search({
    String query = '',
    String? category,
    bool includeUnverified = false,
  }) async => [gadoGado];

  @override
  Future<List<String>> categories() async => ['Sayuran'];

  @override
  Future<Food?> getDetail(String id) async => gadoGado;

  @override
  Future<Food?> findByName(String name) async => gadoGado;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScanService implements ScanService {
  @override
  Future<List<ScanHistory>> historyOf(String userId) async => [
        ScanHistory(
          id: 's1',
          userId: userId,
          foodId: 'f1',
          aiConfidence: 87.5,
          fuzzyScore: 58.05,
          fuzzyLabel: 'Cukup Sehat',
          scanStatus: ScanHistory.statusBerhasil,
          createdAt: DateTime.utc(2026, 9, 11, 6),
          foodName: 'Gado-Gado',
        ),
      ];

  @override
  Future<ScanHistory> save(ScanHistory scan) async => scan;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStorageService implements StorageService {
  @override
  Future<String> uploadJpeg({
    required String bucket,
    required String folder,
    required Uint8List bytes,
  }) async => 'https://example.com/$folder/foto.jpg';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFavoriteService implements FavoriteService {
  @override
  Future<bool> isFavorite({required String userId, required String foodId}) async =>
      false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeIngredientService implements IngredientService {
  @override
  Future<List<Ingredient>> list({String query = ''}) async =>
      [const Ingredient(id: 'i1', name: 'Kacang tanah', unit: 'gram')];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserService implements UserService {
  @override
  Future<List<AppUser>> list({String query = ''}) async =>
      [user(AppUser.roleAdmin), user(AppUser.rolePengguna).copyWith()];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStatsService implements StatsService {
  @override
  Future<ScanStats> load() async {
    final today = DateTime(2026, 9, 11);
    return ScanStats(
      totalScans: 12,
      totalUsers: 5,
      last7Days: [
        for (var i = 6; i >= 0; i--)
          DailyCount(today.subtract(Duration(days: i)), i),
      ],
      byStatus: {ScanHistory.statusBerhasil: 9, ScanHistory.statusTidakYakin: 3},
      byLabel: {'Cukup Sehat': 6, 'Sehat': 3},
      averageConfidence: 81.2,
      topFoods: [gadoGado],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ------------------------------------------------------------- helper ---

Widget racikWith(AppUser? profile, {Widget? home}) {
  return MultiProvider(
    providers: [
      Provider<FoodService>.value(value: FakeFoodService()),
      Provider<IngredientService>.value(value: FakeIngredientService()),
      Provider<ScanService>.value(value: FakeScanService()),
      Provider<StorageService>.value(value: FakeStorageService()),
      Provider<FavoriteService>.value(value: FakeFavoriteService()),
      Provider<UserService>.value(value: FakeUserService()),
      Provider<StatsService>.value(value: FakeStatsService()),
      ChangeNotifierProvider(
        create: (_) => AuthProvider(FakeAuthService(profile)),
      ),
      ChangeNotifierProvider(create: (_) => RecognizerProvider()),
    ],
    child: MaterialApp(home: home ?? const AuthGate()),
  );
}

void main() {
  setUp(() {
    // flutter_tts memanggil kode Android; di tes, jawab saja dengan 1.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('flutter_tts'),
      (call) async => 1,
    );
  });

  testWidgets('Guest: resep terlihat, fitur Pengguna meminta login',
      (tester) async {
    await tester.pumpWidget(racikWith(null));
    await tester.pumpAndSettle();

    expect(find.text('Gado-Gado'), findsOneWidget);

    await tester.tap(find.text('Pindai'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk memindai makanan'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk melihat riwayat pindai'), findsOneWidget);
  });

  testWidgets('Pengguna: pindai, riwayat, profil, dan detail resep',
      (tester) async {
    await tester.pumpWidget(racikWith(user(AppUser.rolePengguna)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pindai'));
    await tester.pumpAndSettle();
    expect(find.text('Buka kamera'), findsOneWidget);
    expect(find.textContaining('Mode demo'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Gado-Gado'), findsWidgets);

    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Nurfauzan Gymnastiar'), findsOneWidget);

    await tester.tap(find.text('Resep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gado-Gado').first);
    await tester.pumpAndSettle();
    expect(find.text('Bahan'), findsOneWidget);
    expect(find.text('Informasi nutrisi'), findsOneWidget);
  });

  testWidgets('Pengguna: layar hasil pindai menampilkan skor fuzzy',
      (tester) async {
    // Foto PNG 4×4 piksel. Mode demo menebak dari byte pertama file (0x89
    // untuk PNG) → keyakinan 82 %; FakeFoodService mencocokkannya ke Gado-Gado.
    final foto = img.encodePng(img.Image(width: 4, height: 4));
    await tester.pumpWidget(racikWith(
      user(AppUser.rolePengguna),
      // Sama seperti di aplikasi: layar hasil hanya terbuka setelah login.
      home: Builder(
        builder: (context) => context.watch<AuthProvider>().isLoggedIn
            ? ScanResultScreen(imageBytes: foto)
            : const SizedBox(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gado-Gado'), findsOneWidget);
    expect(find.text('Keyakinan AI 82%'), findsOneWidget);
    // ListView hanya membangun item di dekat layar, jadi gulir dulu.
    await tester.scrollUntilVisible(find.text('Skor kesehatan'), 200);
    await tester.scrollUntilVisible(find.text('Informasi nutrisi'), 200);
    await tester.scrollUntilVisible(
      find.text('Hasil ini tersimpan di Riwayat.'),
      200,
    );
  });

  testWidgets('Admin: keempat tab admin terbangun tanpa error',
      (tester) async {
    await tester.pumpWidget(racikWith(user(AppUser.roleAdmin)));
    await tester.pumpAndSettle();

    expect(find.text('Kelola resep'), findsOneWidget);
    for (final tab in ['Bahan', 'Statistik', 'Akun']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(find.text('Pindai per hari'), findsNothing); // tab Akun aktif
    await tester.tap(find.text('Statistik'));
    await tester.pumpAndSettle();
    expect(find.text('Pindai per hari'), findsOneWidget);

    // Formulir resep terisi dari data yang ada (4 tabel sekaligus).
    await tester.tap(find.text('Resep'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gado-Gado'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah resep'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rebus sayuran.'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  });
}
