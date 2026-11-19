import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../ai/food_recognizer.dart';
import '../ai/fuzzy_health_score.dart';
import '../core/config.dart';
import '../core/errors.dart';
import '../enum/load_state.dart';
import '../model/food.dart';
import '../model/scan_history.dart';
import '../service/food_service.dart';
import '../service/scan_service.dart';
import '../service/storage_service.dart';

/// Semua yang dibutuhkan halaman hasil pindai.
class ScanOutcome {
  ScanOutcome({
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
/// Memindai Makanan
///   └─ <<include>> Mengidentifikasi Citra Makanan        → langkah 1–2
///       └─ <<include>> Menampilkan Detail Skor
///                      Kesehatan dan Informasi Nutrisi   → langkah 3
/// lalu hasilnya disimpan ke scan_history                 → langkah 4
/// ```
class ScanController extends ChangeNotifier {
  final FoodService foodService;
  final ScanService scanService;
  final StorageService storageService;

  ScanController({
    required this.foodService,
    required this.scanService,
    required this.storageService,
    required this.recognizer,
  });

  final FoodRecognizer recognizer;
  LoadState _loadState = LoadState.initial;
  String _errorMessage = '';
  ScanOutcome? _outcome;

  bool get isDemo => recognizer.isDemo;
  LoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;
  ScanOutcome? get outcome => _outcome;

  Future<void> scan({
    required Uint8List imageBytes,
    required String userId,
  }) async {
    _loadState = LoadState.loading;
    _errorMessage = '';
    _outcome = null;
    notifyListeners();

    try {
      // 1. AI menebak makanan dari foto.
      final recognition = await recognizer.recognize(imageBytes);
      final top = recognition.top;
      final confident = top.confidence >= AppConfig.confidenceThreshold;

      // 2. Cocokkan ke tabel foods. Bila belum ada tetapi AI memberi
      //    perkiraan gizi, tampilkan sebagai makanan sementara (tidak disimpan
      //    ke foods; hanya admin yang boleh menambah resep).
      var food = await foodService.findByName(top.label);
      if (food == null && confident && top.estimatedNutrition != null) {
        food = Food(
          name: top.label,
          servingSize: '1 porsi (perkiraan AI)',
          nutrition: top.estimatedNutrition,
        );
      }

      // 3. Skor kesehatan dari data nutrisi dengan logika fuzzy.
      final nutrition = food?.nutrition;
      final health = nutrition == null
          ? null
          : FuzzyHealthScore.evaluate(nutrition);

      final String status;
      if (!confident) {
        status = ScanHistory.statusTidakYakin;
      } else if (food == null) {
        status = ScanHistory.statusTidakDitemukan;
      } else {
        status = ScanHistory.statusBerhasil;
      }

      // 4. Simpan riwayat. Kegagalan di sini (mis. internet putus) tidak
      //    membatalkan hasil; pengguna tetap melihat hasil pindainya.
      ScanHistory? saved;
      String? saveError;
      try {
        final imageUrl = await storageService.uploadJpeg(
          bucket: AppConfig.scanBucket,
          folder: userId,
          bytes: imageBytes,
        );
        saved = await scanService.save(
          ScanHistory(
            userId: userId,
            foodId: food?.id,
            imageUrl: imageUrl,
            aiConfidence: top.percent,
            fuzzyScore: health?.score,
            fuzzyLabel: health?.label,
            scanStatus: status,
          ),
        );
      } catch (e) {
        saveError = friendlyError(e);
      }

      _outcome = ScanOutcome(
        imageBytes: imageBytes,
        recognition: recognition,
        status: status,
        food: food,
        health: health,
        saved: saved,
        saveError: saveError,
      );
      _loadState = LoadState.loaded;
    } catch (e) {
      _errorMessage = friendlyError(e);
      _loadState = LoadState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    recognizer.dispose();
    super.dispose();
  }
}
