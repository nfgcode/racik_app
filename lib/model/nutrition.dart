/// Tabel `nutritions` pada ERD. Relasinya 1 : 1 dengan `foods`, dan semua
/// angka adalah nilai per satu porsi (`foods.serving_size`).
class Nutrition {
  Nutrition({
    required this.calories,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.sugarG,
    this.sodiumMg,
    this.fiberG,
  });

  final double calories; // kkal
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? sugarG;
  final double? sodiumMg; // miligram, bukan gram
  final double? fiberG;

  factory Nutrition.fromJson(Map<String, dynamic> json) => Nutrition(
    calories: _toDouble(json['calories']) ?? 0,
    proteinG: _toDouble(json['protein_g']),
    fatG: _toDouble(json['fat_g']),
    carbsG: _toDouble(json['carbs_g']),
    sugarG: _toDouble(json['sugar_g']),
    sodiumMg: _toDouble(json['sodium_mg']),
    fiberG: _toDouble(json['fiber_g']),
  );

  /// Postgres `numeric` bisa datang sebagai int, double, atau String
  /// tergantung nilainya. Fungsi ini menyeragamkannya menjadi double.
  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
