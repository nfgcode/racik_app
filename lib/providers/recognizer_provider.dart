import 'package:flutter/foundation.dart';

import '../ai/food_recognizer.dart';

/// Memuat model AI satu kali saja, lalu dipakai ulang oleh setiap pindai.
/// Model baru dimuat saat pertama dibutuhkan (lazy), bukan saat aplikasi
/// dibuka, supaya layar awal tetap cepat.
class RecognizerProvider extends ChangeNotifier {
  Future<FoodRecognizer>? _loading;
  FoodRecognizer? _recognizer;

  bool get isReady => _recognizer != null;
  bool get isDemo => _recognizer?.isDemo ?? false;

  Future<FoodRecognizer> obtain() => _loading ??= _load();

  Future<FoodRecognizer> _load() async {
    final recognizer = await loadFoodRecognizer();
    _recognizer = recognizer;
    notifyListeners();
    return recognizer;
  }

  @override
  void dispose() {
    _recognizer?.dispose();
    super.dispose();
  }
}
