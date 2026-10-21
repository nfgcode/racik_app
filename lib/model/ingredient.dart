/// Tabel `ingredients` pada ERD — master data bahan.
class Ingredient {
  Ingredient({required this.name, this.unit});

  final String name; // varchar(80), unik
  final String? unit; // varchar(20), mis. 'gram', 'butir', 'sdm'

  factory Ingredient.fromJson(Map<String, dynamic> json) =>
      Ingredient(name: json['name'] as String, unit: json['unit'] as String?);
}
