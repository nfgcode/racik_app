/// Tabel `favorites` pada ERD — resep yang disimpan seorang pengguna.
///
/// Catatan: tabel ini ada di ERD tetapi belum punya use case di diagram.
/// Di aplikasi, fitur ini muncul sebagai tombol hati di Detail Resep.
class Favorite {
  const Favorite({
    this.id,
    required this.userId,
    required this.foodId,
    this.createdAt,
  });

  final String? id; // uuid, PK
  final String userId; // uuid, FK → users.id, NN
  final String foodId; // uuid, FK → foods.id, NN
  final DateTime? createdAt; // timestamptz

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      foodId: map['food_id'] as String,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {'user_id': userId, 'food_id': foodId};
}
