import 'ingredient.dart';

/// Tabel `food_ingredients` pada ERD — penghubung many-to-many antara
/// `foods` dan `ingredients`, ditambah takaran per resep.
class FoodIngredient {
  FoodIngredient({this.quantity, this.note, this.ingredient});

  final double? quantity; // numeric(8,2)
  final String? note; // varchar(100), mis. 'iris tipis'

  /// Data bahan hasil join `ingredients(*)`.
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

  factory FoodIngredient.fromJson(Map<String, dynamic> json) {
    final joined = json['ingredients'];
    return FoodIngredient(
      quantity: json['quantity'] == null
          ? null
          : double.tryParse(json['quantity'].toString()),
      note: json['note'] as String?,
      ingredient: joined is Map<String, dynamic>
          ? Ingredient.fromJson(joined)
          : null,
    );
  }
}
