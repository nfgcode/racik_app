// Tes untuk foto kandidat dari hasil pindai:
//  - kapan pengguna ditawari izin "Jadikan foto resep" (ScanOutcome.canSharePhoto);
//  - ScanService memanggil RPC share_scan_photo dan mengambil kandidat;
//  - StorageService menyalin foto antarbucket dan menyetel cache panjang.
// Supabase diganti MockClient, jadi tidak butuh internet.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:racik_app/ai/food_recognizer.dart';
import 'package:racik_app/models/food.dart';
import 'package:provider/provider.dart';
import 'package:racik_app/models/scan_history.dart';
import 'package:racik_app/screens/history/scan_history_detail_screen.dart';
import 'package:racik_app/services/food_service.dart';
import 'package:racik_app/services/scan_pipeline.dart';
import 'package:racik_app/services/scan_service.dart';
import 'package:racik_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient clientWith(MockClientHandler handler) =>
    SupabaseClient('https://contoh.supabase.co', 'sb_publishable_tes',
        httpClient: MockClient(handler));

http.Response jsonResponse(http.Request request, Object body, int status) =>
    http.Response(jsonEncode(body), status,
        request: request, headers: {'content-type': 'application/json'});

const scanFoto =
    'https://contoh.supabase.co/storage/v1/object/public/scan-images/u1/1726040000000.jpg';

ScanOutcome outcome({Food? food, ScanHistory? saved}) => ScanOutcome(
      imageBytes: Uint8List(0),
      recognition: const RecognitionResult(
        isDemo: false,
        predictions: [Prediction('Bakso', 0.9)],
      ),
      status: ScanHistory.statusBerhasil,
      food: food,
      saved: saved,
    );

const tersimpan = ScanHistory(
  id: 's1',
  userId: 'u1',
  foodId: 'f1',
  imageUrl: scanFoto,
  scanStatus: ScanHistory.statusBerhasil,
);

class FakeFoodService implements FoodService {
  FakeFoodService(this.food);

  final Food? food;

  @override
  Future<Food?> getDetail(String id) async => food;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeScanService implements ScanService {
  final shareCalls = <bool>[];

  @override
  Future<bool> setSharePhoto(String scanId, {required bool share}) async {
    shareCalls.add(share);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Detail riwayat. Foto pindai dikosongkan ('') supaya tes tidak mengunduh
/// gambar; aturan izin hanya melihat apakah image_url terisi (bukan null).
Future<FakeScanService> openDetail(
  WidgetTester tester, {
  required bool sharePhoto,
  Food? food,
}) async {
  // Layar tinggi supaya seluruh isi ListView terbangun tanpa digulir.
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final scans = FakeScanService();
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<FoodService>.value(value: FakeFoodService(food)),
      Provider<ScanService>.value(value: scans),
    ],
    child: MaterialApp(
      home: ScanHistoryDetailScreen(
        scan: ScanHistory(
          id: 's1',
          userId: 'u1',
          foodId: 'f1',
          imageUrl: '',
          scanStatus: ScanHistory.statusBerhasil,
          sharePhoto: sharePhoto,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return scans;
}

/// Resep yang sudah punya foto (foto resep tidak ditampilkan di detail
/// riwayat, jadi URL ini tidak pernah diunduh).
const berfoto = Food(
  id: 'f1',
  name: 'Bakso',
  isVerified: true,
  imageUrl: 'https://contoh/foto-resep.jpg',
);

void main() {
  group('Detail riwayat: izin foto bisa ditarik', () {
    testWidgets('izin yang sudah diberikan bisa dimatikan', (tester) async {
      final scans = await openDetail(tester, sharePhoto: true, food: berfoto);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(scans.shareCalls, [false]);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      expect(find.textContaining('Izin ditarik'), findsOneWidget);
    });

    testWidgets('resep sudah berfoto dan belum ada izin: tidak ditanya', (tester) async {
      await openDetail(tester, sharePhoto: false, food: berfoto);
      expect(find.text('Jadikan foto resep'), findsNothing);
    });

    testWidgets('resep belum diverifikasi: pesan jelas + izin ditawarkan', (tester) async {
      await openDetail(tester, sharePhoto: false);
      expect(find.textContaining('masih menunggu verifikasi admin'), findsOneWidget);
      expect(find.text('Jadikan foto resep'), findsOneWidget);
    });
  });

  group('ScanOutcome.canSharePhoto', () {
    test('ditawarkan bila resep tersimpan dan belum punya foto', () {
      expect(
        outcome(food: const Food(id: 'f1', name: 'Bakso'), saved: tersimpan).canSharePhoto,
        isTrue,
      );
    });

    test('TIDAK ditawarkan bila resep sudah punya foto', () {
      const food = Food(id: 'f1', name: 'Bakso', imageUrl: 'https://contoh/foto.jpg');
      expect(outcome(food: food, saved: tersimpan).canSharePhoto, isFalse);
    });

    test('TIDAK ditawarkan bila riwayat/resep tidak tersimpan', () {
      expect(outcome(food: const Food(id: 'f1', name: 'Bakso')).canSharePhoto, isFalse);
      expect(outcome(food: const Food(name: 'Bakso'), saved: tersimpan).canSharePhoto, isFalse);
      expect(outcome(saved: tersimpan).canSharePhoto, isFalse);
    });
  });

  group('ScanService', () {
    test('setSharePhoto memanggil RPC share_scan_photo', () async {
      late http.Request request;
      final service = ScanService(clientWith((r) async {
        request = r;
        return jsonResponse(r, false, 200); // resep sudah punya foto
      }));

      final ok = await service.setSharePhoto('s1', share: true);

      expect(request.url.path, '/rest/v1/rpc/share_scan_photo');
      expect(jsonDecode(request.body), {'p_scan_id': 's1', 'p_share': true});
      expect(ok, isFalse);
    });

    test('photoCandidates hanya mengambil foto yang diizinkan, terbaru di atas', () async {
      late http.Request request;
      final service = ScanService(clientWith((r) async {
        request = r;
        return jsonResponse(r, [
          {
            'id': 's1', 'user_id': 'u1', 'food_id': 'f1', 'image_url': scanFoto,
            'scan_status': 'berhasil', 'share_photo': true,
            'created_at': '2026-11-19T10:00:00Z',
          },
        ], 200);
      }));

      final items = await service.photoCandidates('f1');

      final q = request.url.queryParameters;
      expect(request.url.path, '/rest/v1/scan_history');
      expect(q['food_id'], 'eq.f1');
      expect(q['share_photo'], 'eq.true');
      expect(q['image_url'], 'not.is.null');
      expect(q['order'], 'created_at.desc.nullslast');
      expect(items.single.imageUrl, scanFoto);
      expect(items.single.sharePhoto, isTrue);
    });
  });

  group('StorageService', () {
    test('pathFromPublicUrl', () {
      expect(StorageService.pathFromPublicUrl(scanFoto, 'scan-images'),
          'u1/1726040000000.jpg');
      expect(StorageService.pathFromPublicUrl(scanFoto, 'food-images'), isNull);
      expect(StorageService.pathFromPublicUrl('https://contoh/foto.jpg', 'scan-images'),
          isNull);
    });

    test('copyFromPublicUrl menyalin di server ke food-images/foods/', () async {
      late http.Request request;
      final service = StorageService(clientWith((r) async {
        request = r;
        return jsonResponse(r, {'Key': 'food-images/foods/1.jpg'}, 200);
      }));

      final url = await service.copyFromPublicUrl(
        publicUrl: scanFoto,
        fromBucket: 'scan-images',
        toBucket: 'food-images',
        folder: 'foods',
      );

      expect(request.url.path, '/storage/v1/object/copy');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['bucketId'], 'scan-images');
      expect(body['sourceKey'], 'u1/1726040000000.jpg');
      expect(body['destinationBucket'], 'food-images');
      expect(body['destinationKey'], startsWith('foods/'));
      expect(url, startsWith(
          'https://contoh.supabase.co/storage/v1/object/public/food-images/foods/'));
    });

    test('uploadJpeg menyetel cache panjang (nama file selalu baru)', () async {
      late http.Request request;
      final service = StorageService(clientWith((r) async {
        request = r;
        return jsonResponse(r, {'Key': 'scan-images/u1/1.jpg'}, 200);
      }));

      await service.uploadJpeg(bucket: 'scan-images', folder: 'u1', bytes: Uint8List(4));

      // Supabase menerima cacheControl sebagai field di form multipart.
      final body = latin1.decode(request.bodyBytes);
      expect(body, matches(RegExp(r'name="cacheControl"\r\n\r\n31536000\r\n')));
    });
  });
}
