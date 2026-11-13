import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../model/nutrition.dart';
import 'demo_food_recognizer.dart';
import 'openrouter_food_recognizer.dart';

/// Satu tebakan model: label makanan + tingkat keyakinan 0..1 + estimasi gizi opsional.
class Prediction {
  const Prediction(this.label, this.confidence, {this.estimatedNutrition});

  final String label;
  final double confidence;

  /// Estimasi nutrisi dari AI, dipakai bila makanan belum terdaftar di database.
  final Nutrition? estimatedNutrition;

  /// Untuk kolom `scan_history.ai_confidence` numeric(5,2) → 0..100.
  double get percent => double.parse((confidence * 100).toStringAsFixed(2));
}

/// Hasil use case "Mengidentifikasi Citra Makanan".
class RecognitionResult {
  const RecognitionResult({required this.predictions, required this.isDemo});

  /// Diurutkan dari keyakinan tertinggi. Tidak pernah kosong.
  final List<Prediction> predictions;
  final bool isDemo;

  Prediction get top => predictions.first;
  List<Prediction> get alternatives => predictions.skip(1).toList();
}

/// Kontrak untuk semua mesin pengenal makanan.
///
/// ScanController hanya mengenal kelas abstrak ini, sehingga mesinnya bisa
/// diganti (API cloud atau mode demo) tanpa mengubah halaman mana pun.
abstract class FoodRecognizer {
  bool get isDemo;

  Future<RecognitionResult> recognize(Uint8List imageBytes);

  void dispose();
}

/// OpenRouter Vision bila OPENROUTER_API_KEY ada di env.json; kalau tidak,
/// mode demo supaya alur pindai tetap bisa dicoba.
FoodRecognizer createFoodRecognizer() {
  if (AppConfig.isOpenRouterConfigured) {
    debugPrint(
      'Memakai OpenRouter Food Recognizer (${AppConfig.openRouterModel})',
    );
    return OpenRouterFoodRecognizer(
      apiKey: AppConfig.openRouterApiKey,
      model: AppConfig.openRouterModel,
    );
  }
  debugPrint('OPENROUTER_API_KEY kosong, memakai mode demo.');
  return DemoFoodRecognizer();
}
