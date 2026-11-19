// Tes untuk perbaikan bug lanjutan:
//  - profil gagal dimuat saat offline tidak boleh membuat pengguna jadi Guest;
//  - statistik tidak gagal bila ada riwayat tanpa scan_status;
//  - label/kata kunci dengan % atau _ tidak menjadi wildcard di pola ilike;
//  - pesan error password dari Supabase diterjemahkan dengan tepat.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:racik_app/app.dart';
import 'package:racik_app/core/errors.dart';
import 'package:racik_app/core/query_text.dart';
import 'package:racik_app/models/app_user.dart';
import 'package:racik_app/models/scan_history.dart';
import 'package:racik_app/providers/auth_provider.dart';
import 'package:racik_app/services/auth_service.dart';
import 'package:racik_app/services/food_service.dart';
import 'package:racik_app/services/stats_service.dart';
import 'package:racik_app/services/user_service.dart';
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

http.Response jsonResponse(http.Request request, Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        request: request, headers: {'content-type': 'application/json'});

/// Sesi tersimpan di HP, tetapi profil gagal dimuat [failures] kali pertama.
class OfflineAuthService implements AuthService {
  OfflineAuthService({this.failures = 1});

  int failures;

  @override
  Stream<AuthState> get authChanges => Stream.value(AuthState(
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
      ));

  @override
  Future<AppUser?> fetchProfile(String userId) async {
    if (failures > 0) {
      failures--;
      throw const SocketException('Network is unreachable');
    }
    return budi;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('Profil gagal dimuat saat offline', () {
    test('bukan Guest, dan bisa dicoba lagi', () async {
      final auth = AuthProvider(OfflineAuthService());
      await settle();

      expect(auth.actor, Actor.gagalMemuat);
      expect(auth.isLoggedIn, isFalse);
      expect(auth.profileError, contains('Tidak ada koneksi internet'));

      await auth.retryProfile();

      expect(auth.actor, Actor.pengguna);
      expect(auth.user!.username, 'budi');
      expect(auth.profileError, isNull);
    });

    testWidgets('AuthGate menampilkan layar coba lagi, bukan layar tamu', (tester) async {
      late AuthProvider auth;
      await tester.runAsync(() async {
        auth = AuthProvider(OfflineAuthService(failures: 99));
        await settle();
      });

      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(home: AuthGate()),
      ));

      expect(find.text('Profil belum bisa dimuat'), findsOneWidget);
      expect(find.textContaining('Tidak ada koneksi internet'), findsOneWidget);
      expect(find.text('Coba lagi'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
    });
  });

  test('statistik tetap jalan bila ada riwayat tanpa scan_status', () {
    final today = DateTime(2026, 11, 19, 10);
    final stats = StatsService.summarize(
      totalScans: 3,
      totalUsers: 2,
      today: today,
      topFoods: const [],
      recent: [
        {'created_at': today.toUtc().toIso8601String(), 'scan_status': 'berhasil',
         'fuzzy_label': 'Sehat', 'ai_confidence': '90.00'},
        {'created_at': today.toUtc().toIso8601String(), 'scan_status': null,
         'fuzzy_label': null, 'ai_confidence': null},
        {'created_at': null, 'scan_status': 'tidak_yakin', 'fuzzy_label': null, 'ai_confidence': 40},
      ],
    );

    expect(stats.byStatus, {
      ScanHistory.statusBerhasil: 1,
      'tidak_diketahui': 1,
      ScanHistory.statusTidakYakin: 1,
    });
    expect(stats.scansThisWeek, 2); // baris tanpa created_at tidak dihitung per hari
    expect(stats.averageConfidence, 65);
    expect(stats.byLabel, {'Sehat': 1});
  });

  group('Pola ilike', () {
    test('escapeLike menetralkan karakter wildcard', () {
      expect(escapeLike(r'100% Jus_Jeruk \ Segar'), r'100\% Jus\_Jeruk \\ Segar');
      expect(containsPattern(' soto '), '%soto%');
    });

    test('findByName tidak menjadikan % dan _ dari label AI sebagai wildcard', () async {
      final patterns = <String>[];
      final service = FoodService(clientWith((r) async {
        patterns.add(r.url.queryParameters['name']!);
        return jsonResponse(r, []);
      }));

      expect(await service.findByName('100% Jus_Jeruk Segar'), isNull);
      expect(patterns, [
        r'ilike.100\% Jus\_Jeruk Segar',
        r'ilike.%100\% Jus\_Jeruk Segar%',
        r'ilike.%100\% Jus\_Jeruk%',
      ]);
    });

    test('pencarian akun aman untuk koma dan wildcard', () async {
      final requests = <Map<String, String>>[];
      final service = UserService(clientWith((r) async {
        requests.add(r.url.queryParameters);
        final byUsername = r.url.queryParameters.containsKey('username');
        return jsonResponse(r, [
          if (byUsername)
            {'id': 'u2', 'username': 'a_b', 'role': 'pengguna', 'is_active': true,
             'created_at': '2026-11-02T00:00:00Z'},
          {'id': 'u1', 'username': 'budi', 'full_name': 'A_B, Budi', 'role': 'pengguna',
           'is_active': true, 'created_at': '2026-11-01T00:00:00Z'},
        ]);
      }));

      final users = await service.list(query: 'a_b,');

      expect(requests.map((q) => q['username'] ?? q['full_name']),
          [r'ilike.%a\_b,%', r'ilike.%a\_b,%']);
      expect(requests.every((q) => !q.containsKey('or')), isTrue);
      expect(users.map((u) => u.id), ['u2', 'u1']); // gabungan tanpa duplikat, terbaru dulu
    });
  });

  group('Pesan error password', () {
    test('password terlalu pendek', () {
      expect(
        friendlyError(const AuthException('Password should be at least 6 characters.',
            code: 'weak_password')),
        'Password minimal 6 karakter.',
      );
    });

    test('password lemah karena aturan lain tidak disebut "minimal 6"', () {
      final message = friendlyError(const AuthException(
          'Password should contain at least one character of each: 0123456789.',
          code: 'weak_password'));
      expect(message, isNot('Password minimal 6 karakter.'));
      expect(message, startsWith('Password terlalu lemah.'));
    });

    test('password baru sama dengan yang lama', () {
      expect(
        friendlyError(const AuthException(
            'New password should be different from the old password.',
            code: 'same_password')),
        'Password baru harus berbeda dari password lama.',
      );
    });

    test('pesan lain yang menyebut password tidak dipaksa jadi "minimal 6"', () {
      expect(friendlyError(const AuthException('Password is required for this action')),
          'Password is required for this action');
    });

    test('pesan lama tetap diterjemahkan', () {
      expect(friendlyError(const AuthException('Invalid login credentials',
          code: 'invalid_credentials')), 'Email atau password salah.');
      expect(friendlyError(const AuthException('Email not confirmed')),
          'Email belum dikonfirmasi. Buka tautan di email Anda dulu.');
      expect(friendlyError(const AuthException('User already registered')),
          'Email sudah terdaftar.');
    });
  });
}
