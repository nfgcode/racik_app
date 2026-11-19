import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../model/nutrition.dart';
import 'demo_food_recognizer.dart';
import 'edge_food_recognizer.dart';

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
/// diganti (Edge Function atau mode demo) tanpa mengubah halaman mana pun.
abstract class FoodRecognizer {
  bool get isDemo;

  Future<RecognitionResult> recognize(Uint8List imageBytes);

  void dispose();
}

/// Supabase Edge Function `recognize-food` (OpenRouter Vision di server).
/// Mode demo hanya dipakai bila dijalankan dengan `--dart-define=AI_DEMO=true`,
/// mis. saat fungsi belum di-deploy.
FoodRecognizer createFoodRecognizer(SupabaseClient client) {
  if (AppConfig.aiDemo) {
    debugPrint('AI_DEMO=true, memakai mode demo.');
    return DemoFoodRecognizer();
  }
  return EdgeFoodRecognizer(client);
}
