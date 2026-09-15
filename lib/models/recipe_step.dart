/// Tabel `steps` pada ERD — langkah memasak satu resep.
///
/// Nama kelasnya `RecipeStep`, bukan `Step`, karena Flutter sudah punya
/// widget bernama `Step` (dipakai oleh `Stepper`). Nama yang sama akan
/// bentrok saat kita meng-import material.dart.
class RecipeStep {
  const RecipeStep({
    this.id,
    this.foodId,
    required this.stepOrder,
    required this.instruction,
    this.durationMinutes,
  });

  final String? id; // uuid, PK
  final String? foodId; // uuid, FK → foods.id, NN
  final int stepOrder; // int, NN — urutan 1, 2, 3, ...
  final String instruction; // text, NN
  final int? durationMinutes; // int

  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      id: map['id'] as String?,
      foodId: map['food_id'] as String?,
      stepOrder: map['step_order'] as int,
      instruction: map['instruction'] as String,
      durationMinutes: map['duration_minutes'] as int?,
    );
  }

  Map<String, dynamic> toMap(String foodId) => {
        'food_id': foodId,
        'step_order': stepOrder,
        'instruction': instruction,
        'duration_minutes': durationMinutes,
      };
}
