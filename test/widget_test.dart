// Tes memakai service PALSU, jadi tidak butuh Supabase maupun internet.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racik_app/ai/food_recognizer.dart';
import 'package:racik_app/controller/auth_controller.dart';
import 'package:racik_app/controller/food_controller.dart';
import 'package:racik_app/controller/history_controller.dart';
import 'package:racik_app/controller/scan_controller.dart';
import 'package:racik_app/enum/load_state.dart';
import 'package:racik_app/main.dart';
import 'package:racik_app/model/app_user.dart';
import 'package:racik_app/model/food.dart';
import 'package:racik_app/model/nutrition.dart';
import 'package:racik_app/model/scan_history.dart';
import 'package:racik_app/pages/login_page.dart';
import 'package:racik_app/pages/scan_result_page.dart';
import 'package:racik_app/pages/splash_page.dart';
import 'package:racik_app/service/auth_service.dart';
import 'package:racik_app/service/food_service.dart';
import 'package:racik_app/service/scan_service.dart';
import 'package:racik_app/service/storage_service.dart';
import 'package:racik_app/widget/state_views.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------- data ---

final sotoAyam = Food.fromJson({
  'id': 'f1',
  'name': 'Soto Ayam',
  'category': 'Berkuah',
  'serving_size': '1 mangkuk (400 g)',
  'cook_time_minutes': 60,
  'difficulty': 'sedang',
  'nutritions': {
    'calories': 310,
    'protein_g': 22,
    'fat_g': 12,
    'sugar_g': 3,
    'sodium_mg': 1100,
    'fiber_g': 2,
  },
  'steps': [
    {'step_order': 1, 'instruction': 'Rebus ayam sampai empuk.'},
  ],
  'food_ingredients': [
    {
      'quantity': 150,
      'ingredients': {'name': 'Daging ayam', 'unit': 'gram'},
    },
  ],
});

/// PNG 1×1 piksel, supaya Image.memory bisa menggambar di tes.
final tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

// ---------------------------------------------------------- service palsu ---

class FakeFoodService implements FoodService {
  bool fail = false;

  @override
  Future<List<Food>> getFoods({String query = '', String? category}) async {
    if (fail) throw const FormatException('Server sedang gangguan.');
    return [sotoAyam];
  }

  @override
  Future<List<String>> getCategories() async => ['Berkuah'];

  @override
  Future<Food?> findByName(String name) async =>
      name.toLowerCase() == 'soto ayam' ? sotoAyam : null;

  @override
  Future<Food?> getById(String id) async => id == 'f1' ? sotoAyam : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  final _changes = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authChanges => _changes.stream;

  @override
  String? get currentEmail => null;

  /// Tamu: sesi kosong.
  void emitGuest() =>
      _changes.add(const AuthState(AuthChangeEvent.initialSession, null));

  @override
  Future<AppUser?> fetchProfile(String userId) async => null;

  @override
  Future<void> logout() async {}

  /// Selalu gagal, seperti Supabase saat password salah.
  @override
  Future<void> login({required String email, required String password}) =>
      Future.error(const AuthException('Invalid login credentials'));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScanService implements ScanService {
  final saved = <ScanHistory>[];
  bool failSave = false;

  @override
  Future<ScanHistory> save(ScanHistory scan) async {
    if (failSave) throw const FormatException('Gagal menyimpan riwayat.');
    final row = ScanHistory(
      id: 's${saved.length + 1}',
      userId: scan.userId,
      foodId: scan.foodId,
      imageUrl: scan.imageUrl,
      aiConfidence: scan.aiConfidence,
      fuzzyScore: scan.fuzzyScore,
      fuzzyLabel: scan.fuzzyLabel,
      scanStatus: scan.scanStatus,
      createdAt: DateTime(2026, 11, 13, 10, 5),
      foodName: scan.foodId == null ? null : 'Soto Ayam',
    );
    saved.insert(0, row);
    return row;
  }

  @override
  Future<List<ScanHistory>> getHistory(String userId) async =>
      saved.where((s) => s.userId == userId).toList();

  @override
  Future<void> delete(String id) async => saved.removeWhere((s) => s.id == id);
}

class FakeStorageService implements StorageService {
  @override
  Future<String> uploadJpeg({
    required String bucket,
    required String folder,
    required Uint8List bytes,
  }) async => 'https://contoh.test/$bucket/$folder/foto.jpg';
}

/// Pengenal palsu dengan hasil yang bisa diatur dari tes.
class FakeRecognizer implements FoodRecognizer {
  FakeRecognizer(this.label, this.confidence, {this.estimated});

  final String label;
  final double confidence;
  final Nutrition? estimated;

  @override
  bool get isDemo => false;

  @override
  Future<RecognitionResult> recognize(Uint8List imageBytes) async =>
      RecognitionResult(
        isDemo: false,
        predictions: [
          Prediction(label, confidence, estimatedNutrition: estimated),
          const Prediction('Rendang', 0.05),
        ],
      );

  @override
  void dispose() {}
}

ScanController scanControllerWith(
  FakeRecognizer recognizer, {
  FakeScanService? scans,
}) => ScanController(
  foodService: FakeFoodService(),
  scanService: scans ?? FakeScanService(),
  storageService: FakeStorageService(),
  testRecognizer: recognizer,
);

void main() {
  // flutter_tts memanggil plugin native; di tes cukup dijawab "berhasil".
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('flutter_tts'),
          (_) async => 1,
        );
  });

  test('FoodController: loading → loaded, dan error menyimpan pesan', () async {
    final service = FakeFoodService();
    final controller = FoodController(foodService: service);
    expect(controller.loadState, LoadState.initial);

    final future = controller.loadFoods();
    expect(controller.loadState, LoadState.loading);
    await future;
    expect(controller.loadState, LoadState.loaded);
    expect(controller.allFoods.single.name, 'Soto Ayam');

    service.fail = true;
    await controller.loadFoods();
    expect(controller.loadState, LoadState.error);
    expect(controller.errorMessage, 'Server sedang gangguan.');
  });

  group('ScanController', () {
    test(
      'makanan dikenali → skor fuzzy dihitung dan riwayat tersimpan',
      () async {
        final scans = FakeScanService();
        final c = scanControllerWith(
          FakeRecognizer('Soto Ayam', 0.92),
          scans: scans,
        );
        await c.scan(imageBytes: tinyPng, userId: 'u1');

        expect(c.loadState, LoadState.loaded);
        final o = c.outcome!;
        expect(o.status, ScanHistory.statusBerhasil);
        expect(o.food!.name, 'Soto Ayam');
        expect(o.health!.label, 'Cukup Sehat');
        expect(o.saved, isNotNull);
        expect(scans.saved.single.foodId, 'f1');
        expect(scans.saved.single.aiConfidence, 92);
      },
    );

    test('keyakinan rendah → status tidak_yakin', () async {
      final c = scanControllerWith(FakeRecognizer('Soto Ayam', 0.4));
      await c.scan(imageBytes: tinyPng, userId: 'u1');
      expect(c.outcome!.status, ScanHistory.statusTidakYakin);
    });

    test(
      'belum terdaftar tapi ada perkiraan gizi AI → makanan sementara',
      () async {
        final c = scanControllerWith(
          FakeRecognizer(
            'Ayam Goreng',
            0.95,
            estimated: const Nutrition(calories: 450, fatG: 25, sodiumMg: 600),
          ),
        );
        await c.scan(imageBytes: tinyPng, userId: 'u1');
        final o = c.outcome!;
        expect(o.status, ScanHistory.statusBerhasil);
        expect(o.food!.id, isNull); // tidak ada resep lengkap
        expect(o.health, isNotNull);
      },
    );

    test('gagal menyimpan riwayat → hasil tetap tampil + pesan', () async {
      final scans = FakeScanService()..failSave = true;
      final c = scanControllerWith(
        FakeRecognizer('Soto Ayam', 0.9),
        scans: scans,
      );
      await c.scan(imageBytes: tinyPng, userId: 'u1');
      expect(c.loadState, LoadState.loaded);
      expect(c.outcome!.saved, isNull);
      expect(c.outcome!.saveError, 'Gagal menyimpan riwayat.');
    });
  });

  test('HistoryController mengikuti pengguna dan bisa menghapus', () async {
    final scans = FakeScanService();
    await scans.save(ScanHistory(userId: 'u1', scanStatus: 'berhasil'));
    await scans.save(ScanHistory(userId: 'u2', scanStatus: 'berhasil'));
    final c = HistoryController(
      scanService: scans,
      foodService: FakeFoodService(),
    );

    c.setUser('u1');
    await Future<void>.delayed(Duration.zero);
    expect(c.loadState, LoadState.loaded);
    expect(c.items, hasLength(1));

    await c.delete(c.items.single);
    expect(c.items, isEmpty);

    c.setUser(null); // logout
    expect(c.items, isEmpty);
    expect(c.loadState, LoadState.initial);
  });

  testWidgets('Tamu melihat daftar resep, detail, dan ajakan masuk', (
    tester,
  ) async {
    final authService = FakeAuthService();
    final storage = FakeStorageService();
    final scans = FakeScanService();
    final auth = AuthController(
      authService: authService,
      storageService: storage,
    );
    final food = FoodController(foodService: FakeFoodService())
      ..loadFoods()
      ..loadCategories();

    await tester.pumpWidget(
      RacikApp(
        authController: auth,
        foodController: food,
        scanController: scanControllerWith(
          FakeRecognizer('Soto Ayam', 0.9),
          scans: scans,
        ),
        historyController: HistoryController(
          scanService: scans,
          foodService: FakeFoodService(),
        ),
      ),
    );

    // Splash: logo tampil, belum pindah meski sesi sudah terbaca
    final logo = find.image(const AssetImage('assets/images/logo_racik.png'));
    expect(logo, findsOneWidget);
    authService.emitGuest();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Pemindai makanan berbasis AI'), findsOneWidget);
    expect(find.text('Cari resep'), findsNothing);

    // Setelah durasi minimal splash → halaman utama
    await tester.pump(SplashPage.minDuration);
    await tester.pumpAndSettle();
    expect(logo, findsNothing);

    // Daftar resep + filter kategori + lencana skor kesehatan
    expect(find.text('Soto Ayam'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Berkuah'), findsOneWidget);
    expect(find.text('Cukup Sehat 50'), findsOneWidget);

    // Detail resep: bahan, langkah, nutrisi, skor
    await tester.tap(find.text('Soto Ayam'));
    await tester.pumpAndSettle();
    expect(find.text('Daging ayam'), findsOneWidget);
    expect(find.text('Rebus ayam sampai empuk.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Skor kesehatan'), 200);
    expect(find.text('Informasi nutrisi'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Tab Pindai → tamu diminta masuk → halaman Masuk
    await tester.tap(find.text('Pindai'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk untuk memindai makanan'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Dari Masuk ke Daftar akun
    await tester.tap(find.text('Belum punya akun? Daftar'));
    await tester.pumpAndSettle();
    expect(find.text('Daftar akun'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });

  testWidgets('Login gagal menampilkan InlineError dengan pesan ramah', (
    tester,
  ) async {
    final auth = AuthController(
      authService: FakeAuthService(),
      storageService: FakeStorageService(),
    );
    await tester.pumpWidget(MaterialApp(home: LoginPage(authController: auth)));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@b.c',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'salah123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.byType(InlineError), findsOneWidget);
    expect(find.text('Email atau password salah.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('Halaman hasil pindai menampilkan makanan, skor, dan nutrisi', (
    tester,
  ) async {
    final scans = FakeScanService();
    final history = HistoryController(
      scanService: scans,
      foodService: FakeFoodService(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScanResultPage(
          imageBytes: tinyPng,
          authController: AuthController(
            authService: FakeAuthService(),
            storageService: FakeStorageService(),
          ),
          scanController: scanControllerWith(
            FakeRecognizer('Soto Ayam', 0.92),
            scans: scans,
          ),
          historyController: history,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Soto Ayam'), findsOneWidget);
    expect(find.text('Keyakinan AI 92%'), findsOneWidget);
    expect(find.text('Bacakan hasil'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Hasil ini tersimpan di Riwayat.'),
      200,
    );
    expect(find.text('Skor kesehatan'), findsOneWidget);
    expect(find.text('Lihat resep lengkap'), findsOneWidget);
    expect(scans.saved, hasLength(1));
  });
}
