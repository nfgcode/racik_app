import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/food.dart';

/// Use case: Mencari Resep dan Melihat Detail Resep.
class FoodService {
  FoodService(this._client);

  final SupabaseClient _client;

  /// Satu query mengambil resep beserta seluruh relasinya (join otomatis
  /// PostgREST berdasarkan foreign key di ERD), jadi halaman detail tidak
  /// perlu query lagi.
  static const _columns =
      '*, nutritions(*), steps(*), food_ingredients(*, ingredients(*))';

  /// Hanya resep yang sudah diverifikasi yang boleh dilihat (dijaga juga
  /// oleh Row Level Security di database).
  Future<List<Food>> getFoods({String query = '', String? category}) async {
    var request = _client
        .from('foods')
        .select(_columns)
        .eq('is_verified', true);
    if (query.trim().isNotEmpty) {
      request = request.ilike('name', '%${query.trim()}%');
    }
    if (category != null) request = request.eq('category', category);

    final rows = await request.order('name');
    return rows.map(Food.fromJson).toList();
  }

  /// Daftar kategori unik untuk filter di halaman resep.
  Future<List<String>> getCategories() async {
    final rows = await _client
        .from('foods')
        .select('category')
        .eq('is_verified', true)
        .not('category', 'is', null);
    final set = {for (final r in rows) r['category'] as String};
    return set.toList()..sort();
  }

  /// Satu resep lengkap berdasarkan id (dipakai detail riwayat pindai).
  Future<Food?> getById(String id) async {
    final row = await _client
        .from('foods')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Food.fromJson(row);
  }

  /// Cocokkan label hasil AI ke nama resep: persis dulu (tanpa beda huruf
  /// besar/kecil), lalu mengandung kata tersebut.
  Future<Food?> findByName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return null;
    for (final pattern in [clean, '%$clean%']) {
      final rows = await _client
          .from('foods')
          .select(_columns)
          .eq('is_verified', true)
          .ilike('name', pattern)
          .limit(1);
      if (rows.isNotEmpty) return Food.fromJson(rows.first);
    }
    return null;
  }
}
