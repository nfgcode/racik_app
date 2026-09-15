/// Tabel `ingredients` pada ERD — master data bahan (dikelola Admin lewat
/// use case "Mengelola Data Bahan").
class Ingredient {
  const Ingredient({this.id, required this.name, this.unit});

  final String? id; // uuid, PK
  final String name; // varchar(80), unik, NN
  final String? unit; // varchar(20), mis. 'gram', 'butir', 'sdm'

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'] as String?,
      name: map['name'] as String,
      unit: map['unit'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {'name': name, 'unit': unit};
}
