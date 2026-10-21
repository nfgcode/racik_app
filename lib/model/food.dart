import 'food_ingredient.dart';
import 'nutrition.dart';
import 'recipe_step.dart';

/// Tabel `foods` pada ERD — satu baris = satu resep.
///
/// Relasi yang ikut dimuat oleh FoodService:
///   foods 1 ── 1 nutritions
///   foods 1 ── * steps
///   foods 1 ── * food_ingredients * ── 1 ingredients
class Food {
  Food({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.category,
    this.servingSize,
    this.cookTimeMinutes,
    this.difficulty,
    this.nutrition,
    this.steps = const [],
    this.ingredients = const [],
  });

  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? category;
  final String? servingSize; // mis. '1 piring (250 g)'
  final int? cookTimeMinutes;
  final String? difficulty; // 'mudah' | 'sedang' | 'sulit'

  final Nutrition? nutrition;
  final List<RecipeStep> steps;
  final List<FoodIngredient> ingredients;

  factory Food.fromJson(Map<String, dynamic> json) => Food(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    imageUrl: json['image_url'] as String?,
    category: json['category'] as String?,
    servingSize: json['serving_size'] as String?,
    cookTimeMinutes: json['cook_time_minutes'] as int?,
    difficulty: json['difficulty'] as String?,
    nutrition: _parseNutrition(json['nutritions']),
    steps:
        (json['steps'] as List<dynamic>? ?? [])
            .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder)),
    ingredients: (json['food_ingredients'] as List<dynamic>? ?? [])
        .map((e) => FoodIngredient.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Supabase mengembalikan relasi 1 : 1 sebagai objek, tetapi versi lama
  /// PostgREST mengembalikannya sebagai list berisi satu objek. Keduanya
  /// ditangani di sini.
  static Nutrition? _parseNutrition(Object? value) {
    if (value is Map<String, dynamic>) return Nutrition.fromJson(value);
    if (value is List && value.isNotEmpty) {
      return Nutrition.fromJson(value.first as Map<String, dynamic>);
    }
    return null;
  }
}
