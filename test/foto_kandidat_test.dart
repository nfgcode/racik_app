// Tes untuk foto kandidat dari hasil pindai:
//  - kapan pengguna ditawari izin "Jadikan foto resep" (ScanOutcome.canSharePhoto);
//  - ScanService memanggil RPC share_scan_photo dan mengambil kandidat;
//  - StorageService menyalin foto antarbucket dan menyetel cache panjang.
// Supabase diganti MockClient, jadi tidak butuh internet.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:racik_app/ai/food_recognizer.dart';
import 'package:racik_app/models/food.dart';
import 'package:racik_app/models/scan_history.dart';
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

void main() {
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
