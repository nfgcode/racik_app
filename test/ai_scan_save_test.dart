// Tes untuk penyimpanan hasil pindai AI:
//  - FoodService.createFromAi menyimpan lewat RPC `create_food_from_ai`
//    (bukan insert langsung ke tabel foods yang khusus admin);
//  - ScanPipeline menautkan riwayat pindai ke resep hasil AI.
// Supabase diganti MockClient, jadi tidak butuh internet.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:racik_app/ai/food_recognizer.dart';
import 'package:racik_app/models/food.dart';
import 'package:racik_app/models/nutrition.dart';
import 'package:racik_app/models/scan_history.dart';
import 'package:racik_app/services/food_service.dart';
import 'package:racik_app/services/scan_pipeline.dart';
import 'package:racik_app/services/scan_service.dart';
import 'package:racik_app/services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const baksoNutrition = Nutrition(
  calories: 300, proteinG: 15, fatG: 12, carbsG: 30,
  sugarG: 2, sodiumMg: 800, fiberG: 1,
);

SupabaseClient clientWith(MockClientHandler handler) =>
    SupabaseClient('https://contoh.supabase.co', 'sb_publishable_tes',
        httpClient: MockClient(handler));

/// Balasan JSON palsu. `request` wajib diisi karena postgrest membacanya
/// (pada HTTP sungguhan field ini selalu terisi).
http.Response jsonResponse(http.Request request, Object body, int status) =>
    http.Response(jsonEncode(body), status,
        request: request, headers: {'content-type': 'application/json'});

// ------------------------------------------------------------- fakes ---

class FakeRecognizer implements FoodRecognizer {
  @override
  bool get isDemo => false;

  @override
  Future<RecognitionResult> recognize(Uint8List imageBytes) async =>
      const RecognitionResult(isDemo: false, predictions: [
        Prediction('Bakso', 0.92, estimatedNutrition: baksoNutrition),
      ]);

  @override
  void dispose() {}
}

class FakeFoodService implements FoodService {
  String? savedName;

  @override
  Future<Food?> findByName(String name) async => null; // belum ada di database

  @override
  Future<Food> createFromAi({required String name, required Nutrition nutrition}) async {
    savedName = name;
    return Food(id: 'ai-1', name: name, source: Food.sourceAi, nutrition: nutrition);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeScanService implements ScanService {
  ScanHistory? saved;

  @override
  Future<ScanHistory> save(ScanHistory scan) async => saved = scan;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeStorageService implements StorageService {
  @override
  Future<String> uploadJpeg({
    required String bucket,
    required String folder,
    required Uint8List bytes,
  }) async => 'https://contoh/$folder/foto.jpg';

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  group('FoodService.createFromAi', () {
    test('menyimpan lewat RPC create_food_from_ai dan mengembalikan id-nya', () async {
      late http.Request request;
      final service = FoodService(clientWith((r) async {
        request = r;
        return jsonResponse(r, '9f0c2a1e-0000-4000-8000-000000000001', 200);
      }));

      final food = await service.createFromAi(name: 'Bakso', nutrition: baksoNutrition);

      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/create_food_from_ai');
      expect(jsonDecode(request.body), {
        'p_name': 'Bakso',
        'p_calories': 300.0,
        'p_protein_g': 15.0,
        'p_fat_g': 12.0,
        'p_carbs_g': 30.0,
        'p_sugar_g': 2.0,
        'p_sodium_mg': 800.0,
        'p_fiber_g': 1.0,
      });
      expect(food.id, '9f0c2a1e-0000-4000-8000-000000000001');
      expect(food.isVerified, isFalse); // menunggu ditinjau admin
      expect(food.source, Food.sourceAi);
      expect(food.nutrition!.sodiumMg, 800);
    });

    test('bila RPC gagal, tetap mengembalikan Food tanpa id beserta nutrisi AI', () async {
      final service = FoodService(clientWith((r) async => jsonResponse(
          r, {'code': '22003', 'message': 'numeric field overflow'}, 400)));

      final food = await service.createFromAi(name: 'Seblak', nutrition: baksoNutrition);

      expect(food.id, isNull);
      expect(food.isVerified, isFalse);
      expect(food.nutrition!.calories, 300);
    });
  });

  test('ScanPipeline menautkan riwayat pindai ke resep hasil AI', () async {
    final foods = FakeFoodService();
    final scans = FakeScanService();
    final outcome = await ScanPipeline(
      recognizer: FakeRecognizer(),
      foods: foods,
      scans: scans,
      storage: FakeStorageService(),
    ).run(imageBytes: Uint8List(8), userId: 'u1');

    expect(foods.savedName, 'Bakso');
    expect(outcome.status, ScanHistory.statusBerhasil);
    expect(outcome.health, isNotNull); // skor tetap dihitung dari gizi AI
    expect(scans.saved!.foodId, 'ai-1');
  });
}
