import 'dart:typed_data';

import '../ai/food_recognizer.dart';
import '../ai/fuzzy_health_score.dart';
import '../core/config.dart';
import '../core/errors.dart';
import '../models/food.dart';
import '../models/scan_history.dart';
import 'food_service.dart';
import 'scan_service.dart';
import 'storage_service.dart';

/// Semua yang dibutuhkan layar hasil pindai.
class ScanOutcome {
  const ScanOutcome({
    required this.imageBytes,
    required this.recognition,
    required this.status,
    this.food,
    this.health,
    this.saved,
    this.saveError,
  });

  final Uint8List imageBytes;
  final RecognitionResult recognition;
  final String status; // salah satu ScanHistory.status*
  final Food? food;
  final HealthScoreResult? health;
  final ScanHistory? saved;
  final String? saveError;
}

/// Alur use case "Memindai Makanan" persis seperti diagram:
///
/// ```text
///   Memindai Makanan
///     └─<<include>> Mengidentifikasi Citra Makanan      → langkah 1–2
///         └─<<include>> Menampilkan Detail Skor
///                       Kesehatan & Informasi Nutrisi   → langkah 3
///   (lalu hasilnya disimpan ke scan_history)            → langkah 4
/// ```
class ScanPipeline {
  ScanPipeline({
    required this.recognizer,
    required this.foods,
    required this.scans,
    required this.storage,
  });

  final FoodRecognizer recognizer;
  final FoodService foods;
  final ScanService scans;
  final StorageService storage;

  Future<ScanOutcome> run({
    required Uint8List imageBytes,
    required String userId,
  }) async {
    // 1. AI menebak label makanan dari foto.
    final recognition = await recognizer.recognize(imageBytes);
    final top = recognition.top;

    // 2. Cocokkan label ke tabel foods.
    var food = await foods.findByName(top.label);

    // Bila belum terdaftar di database dan AI punya estimasi gizi:
    if (food == null &&
        top.estimatedNutrition != null &&
        top.confidence >= AppConfig.confidenceThreshold) {
      food = await foods.createFromAi(
        name: top.label,
        nutrition: top.estimatedNutrition!,
        userId: userId,
      );
    }

    // 3. Hitung skor kesehatan dari data nutrisi dengan logika fuzzy.
    final health = food?.nutrition == null
        ? null
        : FuzzyHealthScore.evaluate(food!.nutrition!);

    final String status;
    if (top.confidence < AppConfig.confidenceThreshold) {
      status = ScanHistory.statusTidakYakin;
    } else if (food == null) {
      status = ScanHistory.statusTidakDitemukan;
    } else {
      status = ScanHistory.statusBerhasil;
    }

    // 4. Simpan riwayat. Kegagalan di sini (mis. internet putus) tidak
    //    membatalkan hasil — pengguna tetap melihat hasil pindainya.
    ScanHistory? saved;
    String? saveError;
    try {
      final imageUrl = await storage.uploadJpeg(
        bucket: AppConfig.scanBucket,
        folder: userId,
        bytes: imageBytes,
      );
      saved = await scans.save(ScanHistory(
        userId: userId,
        foodId: food?.id,
        imageUrl: imageUrl,
        aiConfidence: top.percent,
        fuzzyScore: health?.score,
        fuzzyLabel: health?.label,
        scanStatus: status,
      ));
    } catch (e) {
      saveError = friendlyError(e);
    }

    return ScanOutcome(
      imageBytes: imageBytes,
      recognition: recognition,
      status: status,
      food: food,
      health: health,
      saved: saved,
      saveError: saveError,
    );
  }
}
