import 'package:flutter/foundation.dart';

import '../ai/food_recognizer.dart';

/// Memuat mesin AI satu kali saja, lalu dipakai ulang oleh setiap pindai.
/// Mesin baru dibuat saat pertama dibutuhkan (lazy), bukan saat aplikasi
/// dibuka, supaya layar awal tetap cepat.
///
/// Cara membuat mesinnya diberikan dari luar: aplikasi memakai
/// `loadFoodRecognizer(client)` (Edge Function), tes memakai mode demo.
class RecognizerProvider extends ChangeNotifier {
  RecognizerProvider(this._create);

  final Future<FoodRecognizer> Function() _create;
  Future<FoodRecognizer>? _loading;
  FoodRecognizer? _recognizer;

  bool get isReady => _recognizer != null;
  bool get isDemo => _recognizer?.isDemo ?? false;

  Future<FoodRecognizer> obtain() => _loading ??= _load();

  Future<FoodRecognizer> _load() async {
    final recognizer = await _create();
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
