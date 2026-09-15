import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'food_recognizer.dart';

/// Pengenal makanan yang berjalan di HP (on-device) memakai TensorFlow Lite.
///
/// Cocok dengan model ekspor Teachable Machine (Image Project →
/// Export Model → TensorFlow Lite). Taruh dua file ini:
///   assets/models/racik_food.tflite
///   assets/models/labels.txt
///
/// Nama di labels.txt HARUS sama dengan `foods.name` di database,
/// karena hasil tebakan dicocokkan ke tabel `foods` lewat nama.
class TfliteFoodRecognizer implements FoodRecognizer {
  TfliteFoodRecognizer._(this._interpreter, this._labels);

  static const modelPath = 'assets/models/racik_food.tflite';
  static const labelsPath = 'assets/models/labels.txt';
  static const topK = 3;

  final Interpreter _interpreter;
  final List<String> _labels;

  static Future<TfliteFoodRecognizer> load() async {
    final interpreter = await Interpreter.fromAsset(modelPath);
    final labels = parseLabels(await rootBundle.loadString(labelsPath));
    return TfliteFoodRecognizer._(interpreter, labels);
  }

  /// Teachable Machine menulis label sebagai "0 Nasi Goreng". Angka di
  /// depan dibuang supaya yang tersisa hanya nama makanan.
  static List<String> parseLabels(String raw) => raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => line.replaceFirst(RegExp(r'^\d+\s+'), ''))
      .toList();

  @override
  bool get isDemo => false;

  @override
  Future<RecognitionResult> recognize(Uint8List imageBytes) async {
    final inputTensor = _interpreter.getInputTensor(0);
    final outputTensor = _interpreter.getOutputTensor(0);
    final size = inputTensor.shape[1]; // shape: [1, 224, 224, 3]
    final floatInput = inputTensor.type == TensorType.float32;

    // Decode + resize foto itu berat. Isolate.run menjalankannya di thread
    // lain supaya animasi loading di UI tidak patah-patah.
    final input = await Isolate.run(
      () => _preprocess(imageBytes, size, floatInput),
    );

    final classCount = outputTensor.shape.last; // shape: [1, jumlahLabel]
    final floatOutput = outputTensor.type == TensorType.float32;
    final output = [
      floatOutput
          ? List<double>.filled(classCount, 0)
          : List<int>.filled(classCount, 0),
    ];

    _interpreter.run(input, output);

    // Model kuantisasi (uint8) mengeluarkan 0..255, ubah ke 0..1.
    final scores = output.first
        .map((v) => floatOutput ? (v as double) : (v as int) / 255.0)
        .toList();

    final predictions = <Prediction>[
      for (var i = 0; i < scores.length && i < _labels.length; i++)
        Prediction(_labels[i], scores[i]),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return RecognitionResult(
      predictions: predictions.take(topK).toList(),
      isDemo: false,
    );
  }

  /// Foto → tensor [1][size][size][3].
  /// Model float Teachable Machine (MobileNet) mengharapkan piksel -1..1.
  /// Model kuantisasi mengharapkan piksel mentah 0..255.
  static List<List<List<List<num>>>> _preprocess(
    Uint8List bytes,
    int size,
    bool floatInput,
  ) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Foto tidak bisa dibaca.');
    }
    // Potong tengah menjadi persegi lalu kecilkan, sama seperti yang
    // dilakukan Teachable Machine saat pelatihan.
    final square = img.copyResizeCropSquare(decoded, size: size);

    num normalize(num channel) => floatInput ? channel / 127.5 - 1 : channel;

    return [
      List.generate(size, (y) {
        return List.generate(size, (x) {
          final pixel = square.getPixel(x, y);
          return [normalize(pixel.r), normalize(pixel.g), normalize(pixel.b)];
        });
      }),
    ];
  }

  @override
  void dispose() => _interpreter.close();
}
