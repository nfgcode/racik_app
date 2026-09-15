/// Tabel `nutritions` pada ERD. Relasinya 1 : 1 dengan `foods`
/// (kolom `food_id` unik), jadi satu resep punya tepat satu data nutrisi.
///
/// Semua angka adalah nilai per satu porsi (`foods.serving_size`).
class Nutrition {
  const Nutrition({
    this.id,
    this.foodId,
    required this.calories,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.sugarG,
    this.sodiumMg,
    this.fiberG,
  });

  final String? id; // uuid, PK (null saat belum disimpan)
  final String? foodId; // uuid, FK → foods.id, unik
  final double calories; // numeric(7,2), NN — kkal
  final double? proteinG; // numeric(6,2)
  final double? fatG; // numeric(6,2)
  final double? carbsG; // numeric(6,2)
  final double? sugarG; // numeric(6,2)
  final double? sodiumMg; // numeric(7,2) — miligram, bukan gram
  final double? fiberG; // numeric(6,2)

  factory Nutrition.fromMap(Map<String, dynamic> map) {
    return Nutrition(
      id: map['id'] as String?,
      foodId: map['food_id'] as String?,
      calories: _toDouble(map['calories']) ?? 0,
      proteinG: _toDouble(map['protein_g']),
      fatG: _toDouble(map['fat_g']),
      carbsG: _toDouble(map['carbs_g']),
      sugarG: _toDouble(map['sugar_g']),
      sodiumMg: _toDouble(map['sodium_mg']),
      fiberG: _toDouble(map['fiber_g']),
    );
  }

  Map<String, dynamic> toMap() => {
        if (foodId != null) 'food_id': foodId,
        'calories': calories,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbs_g': carbsG,
        'sugar_g': sugarG,
        'sodium_mg': sodiumMg,
        'fiber_g': fiberG,
      };

  /// Postgres `numeric` bisa datang sebagai int, double, atau String
  /// tergantung nilainya. Fungsi ini menyeragamkannya menjadi double.
  static double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
