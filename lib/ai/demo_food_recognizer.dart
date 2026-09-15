import 'dart:typed_data';

import 'food_recognizer.dart';

/// Pengenal PURA-PURA untuk masa pengembangan, sebelum model TFLite siap.
///
/// Tebakannya diturunkan dari isi byte foto, jadi foto yang sama selalu
/// menghasilkan tebakan yang sama. Label di bawah sama dengan data contoh
/// di supabase/seed.sql sehingga seluruh alur pindai bisa dicoba.
///
/// Jangan dipakai untuk demo ke dosen sebagai "AI" — UI selalu menampilkan
/// pita "Mode demo" saat kelas ini aktif.
class DemoFoodRecognizer implements FoodRecognizer {
  static const labels = [
    'Nasi Goreng',
    'Gado-Gado',
    'Soto Ayam',
    'Rendang',
    'Pisang Goreng',
    'Sayur Bening Bayam',
  ];

  @override
  bool get isDemo => true;

  @override
  Future<RecognitionResult> recognize(Uint8List imageBytes) async {
    // Jeda singkat meniru waktu inferensi model sungguhan.
    await Future<void>.delayed(const Duration(milliseconds: 700));

    var seed = 0;
    for (var i = 0; i < imageBytes.length; i += 997) {
      seed = (seed * 31 + imageBytes[i]) & 0x7fffffff;
    }

    final first = seed % labels.length;
    // Keyakinan 0.45..0.94 supaya status "tidak yakin" juga ikut teruji.
    final topConfidence = 0.45 + (seed % 50) / 100;
    final rest = 1 - topConfidence;

    return RecognitionResult(
      isDemo: true,
      predictions: [
        Prediction(labels[first], topConfidence),
        Prediction(labels[(first + 1) % labels.length], rest * 0.7),
        Prediction(labels[(first + 2) % labels.length], rest * 0.3),
      ],
    );
  }

  @override
  void dispose() {}
}
