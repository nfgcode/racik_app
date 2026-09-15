import 'food_ingredient.dart';
import 'nutrition.dart';
import 'recipe_step.dart';

/// Tabel `foods` pada ERD — satu baris = satu makanan/resep.
///
/// Relasi yang ikut dimuat (bila di-select):
///   foods 1 ── 1 nutritions
///   foods 1 ── * steps
///   foods 1 ── * food_ingredients * ── 1 ingredients
class Food {
  const Food({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.category,
    this.servingSize,
    this.cookTimeMinutes,
    this.difficulty,
    this.source = sourceAdmin,
    this.scanCount = 0,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedAt,
    this.createdBy,
    this.createdAt,
    this.nutrition,
    this.steps = const [],
    this.ingredients = const [],
  });

  final String? id; // uuid, PK
  final String name; // varchar(120), NN
  final String? description; // text
  final String? imageUrl; // text
  final String? category; // varchar(50)
  final String? servingSize; // varchar(30), mis. '1 piring (250 g)'
  final int? cookTimeMinutes; // int
  final String? difficulty; // varchar(20) → 'mudah' | 'sedang' | 'sulit'
  final String source; // varchar(20) → 'admin' | 'ai'
  final int scanCount; // int — dinaikkan trigger saat ada scan_history baru
  final bool isVerified; // boolean
  final String? verifiedBy; // uuid, FK → users.id (admin yang memverifikasi)
  final DateTime? verifiedAt; // timestamptz
  final String? createdBy; // uuid, FK → users.id
  final DateTime? createdAt; // timestamptz

  final Nutrition? nutrition;
  final List<RecipeStep> steps;
  final List<FoodIngredient> ingredients;

  static const sourceAdmin = 'admin';
  static const sourceAi = 'ai';
  static const difficulties = ['mudah', 'sedang', 'sulit'];

  factory Food.fromMap(Map<String, dynamic> map) {
    final steps = (map['steps'] as List<dynamic>? ?? [])
        .map((e) => RecipeStep.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return Food(
      id: map['id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      category: map['category'] as String?,
      servingSize: map['serving_size'] as String?,
      cookTimeMinutes: map['cook_time_minutes'] as int?,
      difficulty: map['difficulty'] as String?,
      source: map['source'] as String? ?? sourceAdmin,
      scanCount: map['scan_count'] as int? ?? 0,
      isVerified: map['is_verified'] as bool? ?? false,
      verifiedBy: map['verified_by'] as String?,
      verifiedAt: _parseDate(map['verified_at']),
      createdBy: map['created_by'] as String?,
      createdAt: _parseDate(map['created_at']),
      nutrition: _parseNutrition(map['nutritions']),
      steps: steps,
      ingredients: (map['food_ingredients'] as List<dynamic>? ?? [])
          .map((e) => FoodIngredient.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Kolom milik tabel `foods` saja. Nutrisi, langkah, dan bahan disimpan
  /// ke tabelnya masing-masing oleh FoodService.
  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'category': category,
        'serving_size': servingSize,
        'cook_time_minutes': cookTimeMinutes,
        'difficulty': difficulty,
        'source': source,
      };

  static DateTime? _parseDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  /// Supabase mengembalikan relasi 1 : 1 sebagai objek, tetapi versi lama
  /// PostgREST mengembalikannya sebagai list berisi satu objek. Keduanya
  /// ditangani di sini.
  static Nutrition? _parseNutrition(Object? value) {
    if (value is Map<String, dynamic>) return Nutrition.fromMap(value);
    if (value is List && value.isNotEmpty) {
      return Nutrition.fromMap(value.first as Map<String, dynamic>);
    }
    return null;
  }
}
