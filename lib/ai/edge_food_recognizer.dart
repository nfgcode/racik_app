import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/nutrition.dart';
import 'food_recognizer.dart';

/// Pengenal makanan lewat Supabase Edge Function `recognize-food`
/// (supabase/functions/recognize-food). Fungsi itu yang memanggil OpenRouter
/// Vision, jadi kunci API tersimpan di server dan tidak ikut ke APK.
class EdgeFoodRecognizer implements FoodRecognizer {
  EdgeFoodRecognizer(this._client);

  final SupabaseClient _client;

  static const functionName = 'recognize-food';

  @override
  bool get isDemo => false;

  @override
  Future<RecognitionResult> recognize(Uint8List imageBytes) async {
    // Kecilkan foto (maks 768 px) agar cepat diunggah dan hemat kuota AI.
    final compressed = await compute(compressForUpload, imageBytes);
    final response = await _client.functions.invoke(
      functionName,
      body: {'image': base64Encode(compressed)},
    );
    return parseRecognition(response.data as Map<String, dynamic>);
  }

  /// Jawaban JSON dari fungsi → RecognitionResult. Dipisah supaya bisa dites.
  static RecognitionResult parseRecognition(Map<String, dynamic> json) {
    final topLabel = (json['label'] as String?)?.trim() ?? 'Makanan';
    final topConfidence = (_toDouble(json['confidence']) ?? 0.85).clamp(
      0.0,
      1.0,
    );

    final calories = _toDouble(json['calories']);
    final estimated = (calories != null && calories > 0)
        ? Nutrition(
            calories: calories,
            proteinG: _toDouble(json['protein_g']) ?? 0,
            fatG: _toDouble(json['fat_g']) ?? 0,
            carbsG: _toDouble(json['carbs_g']) ?? 0,
            sugarG: _toDouble(json['sugar_g']) ?? 0,
            sodiumMg: _toDouble(json['sodium_mg']) ?? 0,
            fiberG: _toDouble(json['fiber_g']) ?? 0,
          )
        : null;

    final predictions = <Prediction>[
      Prediction(topLabel, topConfidence, estimatedNutrition: estimated),
    ];
    for (final alt in json['alternatives'] as List<dynamic>? ?? const []) {
      if (alt is! Map<String, dynamic>) continue;
      final label = (alt['label'] as String?)?.trim();
      if (label == null || label.isEmpty) continue;
      if (label.toLowerCase() == topLabel.toLowerCase()) continue;
      predictions.add(
        Prediction(
          label,
          (_toDouble(alt['confidence']) ?? 0.5).clamp(0.0, 1.0),
        ),
      );
    }
    return RecognitionResult(predictions: predictions, isDemo: false);
  }

  static Uint8List compressForUpload(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;
    const maxDimension = 768;
    final resized =
        (image.width <= maxDimension && image.height <= maxDimension)
        ? image
        : image.width >= image.height
        ? img.copyResize(image, width: maxDimension)
        : img.copyResize(image, height: maxDimension);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  @override
  void dispose() {}
}
