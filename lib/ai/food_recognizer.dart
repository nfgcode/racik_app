import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../models/nutrition.dart';
import 'demo_food_recognizer.dart';
import 'openrouter_food_recognizer.dart';
import 'tflite_food_recognizer.dart';

/// Satu tebakan model: label makanan + tingkat keyakinan 0..1 + estimasi gizi opsional.
class Prediction {
  const Prediction(
    this.label,
    this.confidence, {
    this.estimatedNutrition,
  });

  final String label;
  final double confidence;

  /// Estimasi nutrisi otomatis dari AI (jika makanan belum terdaftar di database).
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
/// UI dan ScanPipeline hanya mengenal kelas abstrak ini, sehingga model
/// bisa diganti (TFLite di perangkat, API cloud, atau mode demo) tanpa
/// mengubah layar mana pun.
abstract class FoodRecognizer {
  bool get isDemo;

  Future<RecognitionResult> recognize(Uint8List imageBytes);

  void dispose();
}

/// Coba muat model pengenal makanan dengan urutan prioritas:
/// 1. OpenRouter Vision API (bila OPENROUTER_API_KEY ada di env.json)
/// 2. Model TFLite lokal (assets/models/racik_food.tflite)
/// 3. DemoFoodRecognizer (fallback simulasi bila keduanya belum disiapkan)
Future<FoodRecognizer> loadFoodRecognizer() async {
  if (AppConfig.isOpenRouterConfigured) {
    debugPrint(
      'Memakai OpenRouter Food Recognizer (Model: ${AppConfig.openRouterModel})',
    );
    return OpenRouterFoodRecognizer(
      apiKey: AppConfig.openRouterApiKey,
      model: AppConfig.openRouterModel,
    );
  }

  try {
    return await TfliteFoodRecognizer.load();
  } catch (e) {
    debugPrint('Model TFLite tidak dimuat, memakai mode demo: $e');
    return DemoFoodRecognizer();
  }
}
