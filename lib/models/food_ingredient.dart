import 'ingredient.dart';

/// Tabel `food_ingredients` pada ERD — tabel penghubung many-to-many
/// antara `foods` dan `ingredients`, ditambah takaran per resep.
class FoodIngredient {
  const FoodIngredient({
    this.id,
    this.foodId,
    required this.ingredientId,
    this.quantity,
    this.note,
    this.ingredient,
  });

  final String? id; // uuid, PK
  final String? foodId; // uuid, FK → foods.id, NN
  final String ingredientId; // uuid, FK → ingredients.id, NN
  final double? quantity; // numeric(8,2)
  final String? note; // varchar(100), mis. 'iris tipis'

  /// Data bahan hasil join (`ingredients(*)`). Tidak disimpan ke tabel ini.
  final Ingredient? ingredient;

  /// Contoh: "2 butir" atau "150 gram".
  String get amountLabel {
    if (quantity == null) return '';
    final q = quantity! % 1 == 0
        ? quantity!.toStringAsFixed(0)
        : quantity!.toString();
    final unit = ingredient?.unit ?? '';
    return unit.isEmpty ? q : '$q $unit';
  }

  factory FoodIngredient.fromMap(Map<String, dynamic> map) {
    final joined = map['ingredients'];
    return FoodIngredient(
      id: map['id'] as String?,
      foodId: map['food_id'] as String?,
      ingredientId: map['ingredient_id'] as String,
      quantity: map['quantity'] == null
          ? null
          : double.tryParse(map['quantity'].toString()),
      note: map['note'] as String?,
      ingredient: joined is Map<String, dynamic>
          ? Ingredient.fromMap(joined)
          : null,
    );
  }

  Map<String, dynamic> toMap(String foodId) => {
        'food_id': foodId,
        'ingredient_id': ingredientId,
        'quantity': quantity,
        'note': note,
      };
}
