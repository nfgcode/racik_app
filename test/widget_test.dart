// Tes widget memakai service PALSU, jadi tidak butuh Supabase maupun internet.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racik_app/controller/auth_controller.dart';
import 'package:racik_app/controller/food_controller.dart';
import 'package:racik_app/enum/load_state.dart';
import 'package:racik_app/main.dart';
import 'package:racik_app/model/app_user.dart';
import 'package:racik_app/model/food.dart';
import 'package:racik_app/pages/login_page.dart';
import 'package:racik_app/pages/splash_page.dart';
import 'package:racik_app/service/auth_service.dart';
import 'package:racik_app/service/food_service.dart';
import 'package:racik_app/widget/state_views.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sotoAyam = Food.fromJson({
  'id': 'f1',
  'name': 'Soto Ayam',
  'category': 'Berkuah',
  'serving_size': '1 mangkuk (400 g)',
  'cook_time_minutes': 60,
  'difficulty': 'sedang',
  'nutritions': {'calories': 310, 'protein_g': 22},
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

void main() {
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

  testWidgets('Tamu melihat daftar resep, detail, dan ajakan masuk', (
    tester,
  ) async {
    final authService = FakeAuthService();
    final auth = AuthController(authService: authService);
    final food = FoodController(foodService: FakeFoodService())
      ..loadFoods()
      ..loadCategories();

    await tester.pumpWidget(
      RacikApp(authController: auth, foodController: food),
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

    // Daftar resep + filter kategori
    expect(find.text('Soto Ayam'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Berkuah'), findsOneWidget);

    // Detail resep: bahan, langkah, nutrisi
    await tester.tap(find.text('Soto Ayam'));
    await tester.pumpAndSettle();
    expect(find.text('Daging ayam'), findsOneWidget);
    expect(find.text('Rebus ayam sampai empuk.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Informasi nutrisi'), 200);
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
    final auth = AuthController(authService: FakeAuthService());
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
}
