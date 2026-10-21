/// Tabel `steps` pada ERD — langkah memasak satu resep.
///
/// Nama kelasnya `RecipeStep`, bukan `Step`, karena Flutter sudah punya
/// widget bernama `Step` (dipakai oleh `Stepper`).
class RecipeStep {
  RecipeStep({
    required this.stepOrder,
    required this.instruction,
    this.durationMinutes,
  });

  final int stepOrder; // urutan 1, 2, 3, ...
  final String instruction;
  final int? durationMinutes;

  factory RecipeStep.fromJson(Map<String, dynamic> json) => RecipeStep(
    stepOrder: json['step_order'] as int,
    instruction: json['instruction'] as String,
    durationMinutes: json['duration_minutes'] as int?,
  );
}
