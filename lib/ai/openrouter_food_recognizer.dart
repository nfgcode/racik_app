import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../models/nutrition.dart';
import 'food_recognizer.dart';

/// Pengenal makanan berbasis cloud menggunakan OpenRouter Multimodal Vision API.
///
/// Menggunakan model:
/// - `qwen/qwen-2.5-vl-72b-instruct` (Sangat presisi untuk kuliner & hidangan Asia/Nusantara)
/// - `google/gemini-2.5-flash` (Pilihan alternatif cepat)
/// - `inclusionai/ling-3.0-flash-vl:free` (Fallback gratis)
class OpenRouterFoodRecognizer implements FoodRecognizer {
  OpenRouterFoodRecognizer({
    required this.apiKey,
    this.model = 'qwen/qwen-2.5-vl-72b-instruct',
  });

  final String apiKey;
  final String model;
  final HttpClient _client = HttpClient();

  static const String _freeFallbackModel = 'inclusionai/ling-3.0-flash-vl:free';

  @override
  bool get isDemo => false;

  @override
  Future<RecognitionResult> recognize(Uint8List imageBytes) async {
    // 1. Kompres dan resize foto (maks 768px) agar cepat diunggah.
    final compressedBytes = await compute(_compressImage, imageBytes);
    final base64Image = base64Encode(compressedBytes);

    try {
      return await _queryModel(model, base64Image);
    } catch (e) {
      // Jika model utama gagal (misal rate limit/gangguan provider),
      // otomatis coba dengan model vision cadangan.
      if (model != _freeFallbackModel) {
        debugPrint('Model $model gagal ($e), mencoba fallback ke $_freeFallbackModel...');
        try {
          return await _queryModel(_freeFallbackModel, base64Image);
        } catch (fallbackError) {
          debugPrint('Fallback $_freeFallbackModel juga gagal: $fallbackError');
        }
      }
      rethrow;
    }
  }

  Future<RecognitionResult> _queryModel(String activeModel, String base64Image) async {
    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final request = await _client.postUrl(uri);
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set('HTTP-Referer', 'https://racik.app');
    request.headers.set('X-Title', 'Racik Food Scanner');

    const systemPrompt = '''
Anda adalah pakar kuliner dan gizi terkemuka di Indonesia.
Tugas:
1. Identifikasi makanan atau minuman utama pada foto ini.
2. Estimasi kandungan nutrisi rata-rata per 1 porsi saji standar.

ATURAN WAJIB:
- Gunakan penamaan makanan/minuman khas Indonesia sehari-hari!
  Contoh: jika roti dipanggang/dibakar, sebut "Roti Bakar" (DILARANG menyebut "Panini" atau "Toast").
  Jika kopi susu dingin, sebut "Es Kopi" (DILARANG menyebut "Iced Coffee" atau "Latte").
  Gunakan istilah umum seperti: "Nasi Goreng", "Soto Ayam", "Rendang", "Gado-Gado", "Pisang Goreng", "Sayur Bening Bayam", "Bakso", "Ayam Goreng", dll.
- Balas HANYA dalam format JSON murni (tanpa tanda kutip ``` atau teks pengantar apapun):
{
  "label": "Nama Makanan",
  "confidence": 0.95,
  "calories": 280,
  "protein_g": 6.5,
  "fat_g": 9.0,
  "carbs_g": 42.0,
  "sugar_g": 12.0,
  "sodium_mg": 320,
  "fiber_g": 2.5,
  "alternatives": [
    {"label": "Kemungkinan Lain 1", "confidence": 0.70},
    {"label": "Kemungkinan Lain 2", "confidence": 0.50}
  ]
}
Catatan nilai gizi: calories (kkal), protein_g (gram), fat_g (gram), carbs_g (gram), sugar_g (gram), sodium_mg (miligram), fiber_g (gram).
''';

    final requestPayload = jsonEncode({
      'model': activeModel,
      'max_tokens': 350,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text': systemPrompt,
            },
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'temperature': 0.1,
    });

    request.write(requestPayload);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();

    if (response.statusCode != 200) {
      throw Exception(
        'OpenRouter HTTP ${response.statusCode}: $responseBody',
      );
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;
    final choices = json['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Tidak ada pilihan respon dari OpenRouter.');
    }

    final message = choices[0]['message'] as Map<String, dynamic>;
    final content = (message['content'] as String?)?.trim() ?? '';

    // Ambil bagian JSON di dalam string (antara kurung kurawal pertama dan terakhir)
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
    final jsonText = jsonMatch?.group(0) ?? content;

    final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
    final topLabel = (parsed['label'] as String?)?.trim() ?? 'Makanan';
    final topConfidence = _toDouble(parsed['confidence']) ?? 0.85;

    // Baca estimasi nutrisi dari AI
    final double? calories = _toDouble(parsed['calories']);
    Nutrition? estimatedNutrition;
    if (calories != null && calories > 0) {
      estimatedNutrition = Nutrition(
        calories: calories,
        proteinG: _toDouble(parsed['protein_g']) ?? 0.0,
        fatG: _toDouble(parsed['fat_g']) ?? 0.0,
        carbsG: _toDouble(parsed['carbs_g']) ?? 0.0,
        sugarG: _toDouble(parsed['sugar_g']) ?? 0.0,
        sodiumMg: _toDouble(parsed['sodium_mg']) ?? 0.0,
        fiberG: _toDouble(parsed['fiber_g']) ?? 0.0,
      );
    }

    final predictions = <Prediction>[
      Prediction(
        topLabel,
        topConfidence.clamp(0.0, 1.0),
        estimatedNutrition: estimatedNutrition,
      ),
    ];

    final alternatives = parsed['alternatives'] as List<dynamic>?;
    if (alternatives != null) {
      for (final alt in alternatives) {
        if (alt is Map<String, dynamic>) {
          final altLabel = (alt['label'] as String?)?.trim();
          final altConf = (alt['confidence'] as num?)?.toDouble() ?? 0.50;
          if (altLabel != null &&
              altLabel.isNotEmpty &&
              altLabel.toLowerCase() != topLabel.toLowerCase()) {
            predictions.add(Prediction(altLabel, altConf.clamp(0.0, 1.0)));
          }
        }
      }
    }

    return RecognitionResult(
      predictions: predictions,
      isDemo: false,
    );
  }

  static Uint8List _compressImage(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    const maxDimension = 768;
    if (image.width <= maxDimension && image.height <= maxDimension) {
      return Uint8List.fromList(img.encodeJpg(image, quality: 80));
    }

    final resized = image.width >= image.height
        ? img.copyResize(image, width: maxDimension)
        : img.copyResize(image, height: maxDimension);

    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _client.close(force: true);
  }
}
