// Tes untuk persiapan rilis Play Store:
//  - pengenal makanan lewat Supabase Edge Function `recognize-food`
//    (kunci OpenRouter tersimpan di server, bukan di aplikasi);
//  - fitur Hapus akun (syarat Google Play).
// Supabase diganti MockClient / service palsu, jadi tidak butuh internet.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:racik_app/ai/edge_food_recognizer.dart';
import 'package:racik_app/ai/food_recognizer.dart';
import 'package:racik_app/core/errors.dart';
import 'package:racik_app/models/app_user.dart';
import 'package:racik_app/providers/auth_provider.dart';
import 'package:racik_app/screens/profile/profile_screen.dart';
import 'package:racik_app/services/auth_service.dart';
import 'package:racik_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const budi = AppUser(
  id: 'u1',
  username: 'budi',
  fullName: 'Budi Santoso',
  role: AppUser.rolePengguna,
  isActive: true,
);

SupabaseClient clientWith(MockClientHandler handler) =>
    SupabaseClient('https://contoh.supabase.co', 'sb_publishable_tes',
        httpClient: MockClient(handler));

/// Balasan JSON palsu. `request` wajib diisi karena klien Supabase membacanya.
http.Response jsonResponse(http.Request request, Object body, int status) =>
    http.Response(jsonEncode(body), status,
        request: request, headers: {'content-type': 'application/json'});

class FakeAuthService implements AuthService {
  final _changes = StreamController<AuthState>.broadcast();
  bool deleted = false;

  @override
  Stream<AuthState> get authChanges async* {
    yield AuthState(
      AuthChangeEvent.initialSession,
      Session(
        accessToken: 'token',
        tokenType: 'bearer',
        user: User(
          id: budi.id,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: '2026-11-19T00:00:00Z',
        ),
      ),
    );
    yield* _changes.stream;
  }

  @override
  String? get currentEmail => 'budi@example.com';

  @override
  Future<AppUser?> fetchProfile(String userId) async => budi;

  @override
  Future<void> deleteAccount() async {
    deleted = true;
    // Seperti Supabase: setelah signOut, sesi hilang → AuthProvider jadi Guest.
    _changes.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeStorageService implements StorageService {
  final removedFolders = <String>[];

  @override
  Future<void> removeFolder({required String bucket, required String folder}) async =>
      removedFolders.add('$bucket/$folder');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<AuthProvider> loggedInProvider(FakeAuthService service) async {
  final auth = AuthProvider(service);
  for (var i = 0; i < 5 && !auth.isLoggedIn; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(auth.isLoggedIn, isTrue);
  return auth;
}

void main() {
  group('EdgeFoodRecognizer', () {
    test('parseRecognition membaca jawaban Edge Function', () {
      final r = EdgeFoodRecognizer.parseRecognition({
        'label': 'Ayam Goreng',
        'confidence': 0.98,
        'calories': 450,
        'fat_g': '25',
        'alternatives': [
          {'label': 'Ayam Bakar', 'confidence': 0.6},
          {'label': 'ayam goreng', 'confidence': 0.5}, // duplikat diabaikan
        ],
        'model': 'qwen/qwen-2.5-vl-72b-instruct',
      });
      expect(r.isDemo, isFalse);
      expect(r.top.label, 'Ayam Goreng');
      expect(r.top.percent, 98);
      expect(r.top.estimatedNutrition!.fatG, 25);
      expect(r.alternatives.map((p) => p.label), ['Ayam Bakar']);
    });

    test('recognize mengirim foto ke fungsi recognize-food', () async {
      late http.Request request;
      final recognizer = EdgeFoodRecognizer(clientWith((r) async {
        request = r;
        return jsonResponse(r, {'label': 'Bakso', 'confidence': 0.9, 'calories': 300}, 200);
      }));
      final jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 8, height: 8)));

      final result = await recognizer.recognize(jpeg);

      expect(request.method, 'POST');
      expect(request.url.path, '/functions/v1/recognize-food');
      final image = (jsonDecode(request.body) as Map<String, dynamic>)['image'] as String;
      expect(base64Decode(image), isNotEmpty);
      expect(result.top.label, 'Bakso');
      expect(result.top.estimatedNutrition!.calories, 300);
    });

    test('tanpa AI_DEMO, aplikasi memakai Edge Function', () async {
      final recognizer = await loadFoodRecognizer(clientWith((r) async => jsonResponse(r, {}, 200)));
      expect(recognizer, isA<EdgeFoodRecognizer>());
    });

    test('friendlyError menerjemahkan error Edge Function', () {
      expect(friendlyError(const FunctionException(status: 404)),
          'Layanan AI belum siap (fungsi recognize-food belum di-deploy).');
      expect(friendlyError(const FunctionException(status: 401)),
          'Sesi berakhir. Silakan masuk lagi.');
      expect(
        friendlyError(const FunctionException(
            status: 502, details: {'error': 'AI belum bisa mengenali foto.'})),
        'AI belum bisa mengenali foto.',
      );
    });
  });

  group('Hapus akun', () {
    test('AuthProvider.deleteAccount menghapus foto dulu, lalu akun', () async {
      final service = FakeAuthService();
      final storage = FakeStorageService();
      final auth = await loggedInProvider(service);

      final error = await auth.deleteAccount(storage);

      expect(error, isNull);
      expect(storage.removedFolders, ['scan-images/u1', 'avatars/u1']);
      expect(service.deleted, isTrue);
    });

    testWidgets('Profil → Hapus akun → Hapus permanen', (tester) async {
      final service = FakeAuthService();
      final storage = FakeStorageService();
      late AuthProvider auth;
      await tester.runAsync(() async => auth = await loggedInProvider(service));

      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<StorageService>.value(value: storage),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ));

      await tester.tap(find.text('Hapus akun'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus akun?'), findsOneWidget);

      await tester.tap(find.text('Hapus permanen'));
      await tester.pumpAndSettle();

      expect(service.deleted, isTrue);
      expect(storage.removedFolders, ['scan-images/u1', 'avatars/u1']);
      expect(find.text('Akun Anda sudah dihapus.'), findsOneWidget);
    });
  });
}
