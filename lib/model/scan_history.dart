/// Tabel `scan_history` pada ERD — satu baris = satu kali "Memindai
/// Makanan" oleh Pengguna.
///
/// `food_id` boleh kosong: terjadi saat AI mengenali sebuah makanan tetapi
/// resepnya belum ada di tabel `foods`.
class ScanHistory {
  ScanHistory({
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

  final String? id;
  final String userId;
  final String? foodId;
  final String? imageUrl; // foto di Supabase Storage
  final double? aiConfidence; // 0..100 (%)
  final double? fuzzyScore; // 0..100
  final String? fuzzyLabel; // 'Sehat' | 'Cukup Sehat' | 'Kurang Sehat'
  final String scanStatus; // lihat konstanta di bawah
  final DateTime? createdAt;

  /// Nama makanan dari join `foods(name)`. Tidak disimpan ke tabel ini.
  final String? foodName;

  /// AI yakin dan resepnya ada di database.
  static const statusBerhasil = 'berhasil';

  /// AI mengenali sesuatu tetapi keyakinannya di bawah ambang batas.
  static const statusTidakYakin = 'tidak_yakin';

  /// AI yakin, tetapi resep dengan nama itu belum ada di `foods`.
  static const statusTidakDitemukan = 'tidak_ditemukan';

  factory ScanHistory.fromJson(Map<String, dynamic> json) {
    final food = json['foods'];
    return ScanHistory(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      foodId: json['food_id'] as String?,
      imageUrl: json['image_url'] as String?,
      aiConfidence: _toDouble(json['ai_confidence']),
      fuzzyScore: _toDouble(json['fuzzy_score']),
      fuzzyLabel: json['fuzzy_label'] as String?,
      scanStatus: json['scan_status'] as String? ?? 'tidak_diketahui',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      foodName: food is Map<String, dynamic> ? food['name'] as String? : null,
    );
  }

  /// Kolom yang dikirim saat insert. `id` dan `created_at` diisi database.
  Map<String, dynamic> toJson() => {
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
