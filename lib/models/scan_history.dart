/// Tabel `scan_history` pada ERD — satu baris = satu kali "Memindai
/// Makanan" oleh Pengguna.
///
/// `food_id` boleh kosong (tidak NN di ERD): terjadi saat AI mengenali
/// sebuah label tetapi resepnya belum ada di tabel `foods`.
class ScanHistory {
  const ScanHistory({
    this.id,
    required this.userId,
    this.foodId,
    this.imageUrl,
    this.aiConfidence,
    this.fuzzyScore,
    this.fuzzyLabel,
    required this.scanStatus,
    this.createdAt,
    this.foodName,
  });

  final String? id; // uuid, PK
  final String userId; // uuid, FK → users.id, NN
  final String? foodId; // uuid, FK → foods.id
  final String? imageUrl; // text — foto di Supabase Storage
  final double? aiConfidence; // numeric(5,2) — 0..100 (%)
  final double? fuzzyScore; // numeric(5,2) — 0..100
  final String? fuzzyLabel; // varchar(20) — 'Sehat' | 'Cukup Sehat' | 'Kurang Sehat'
  final String scanStatus; // varchar(20) — lihat konstanta di bawah
  final DateTime? createdAt; // timestamptz

  /// Nama makanan dari join `foods(name)`. Tidak disimpan ke tabel ini.
  final String? foodName;

  /// AI yakin dan resepnya ada di database.
  static const statusBerhasil = 'berhasil';

  /// AI mengenali sesuatu tetapi keyakinannya di bawah ambang batas.
  static const statusTidakYakin = 'tidak_yakin';

  /// AI yakin, tetapi resep dengan nama itu belum ada di `foods`.
  static const statusTidakDitemukan = 'tidak_ditemukan';

  factory ScanHistory.fromMap(Map<String, dynamic> map) {
    final food = map['foods'];
    return ScanHistory(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      foodId: map['food_id'] as String?,
      imageUrl: map['image_url'] as String?,
      aiConfidence: _toDouble(map['ai_confidence']),
      fuzzyScore: _toDouble(map['fuzzy_score']),
      fuzzyLabel: map['fuzzy_label'] as String?,
      // Kolom ini tidak NN di ERD, jadi siapkan nilai cadangan.
      scanStatus: map['scan_status'] as String? ?? 'tidak_diketahui',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
      foodName: food is Map<String, dynamic> ? food['name'] as String? : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'user_id': userId,
        'food_id': foodId,
        'image_url': imageUrl,
        'ai_confidence': aiConfidence,
        'fuzzy_score': fuzzyScore,
        'fuzzy_label': fuzzyLabel,
        'scan_status': scanStatus,
      };

  static double? _toDouble(Object? value) =>
      value == null ? null : double.tryParse(value.toString());
}
