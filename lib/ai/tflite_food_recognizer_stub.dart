import 'food_recognizer.dart';

/// Pengganti [TfliteFoodRecognizer] saat aplikasi berjalan di web (Chrome).
///
/// Paket tflite_flutter memakai `dart:ffi`, dan library itu tidak ada di
/// browser. File ini dipilih lewat conditional import di
/// food_recognizer.dart, sehingga di web load() selalu gagal dan aplikasi
/// otomatis jatuh ke mode demo.
class TfliteFoodRecognizer {
  static Future<FoodRecognizer> load() =>
      Future.error(UnsupportedError('Model TFLite tidak tersedia di web.'));
}
