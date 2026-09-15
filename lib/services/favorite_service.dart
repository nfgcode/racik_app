import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';

/// Tabel `favorites`. Belum ada use case-nya di diagram — lihat catatan
/// di dokumen belajar.
class FavoriteService {
  FavoriteService(this._client);

  final SupabaseClient _client;

  Future<bool> isFavorite({required String userId, required String foodId}) async {
    final row = await _client
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('food_id', foodId)
        .maybeSingle();
    return row != null;
  }

  /// Mengembalikan status favorit yang baru.
  Future<bool> toggle({required String userId, required String foodId}) async {
    if (await isFavorite(userId: userId, foodId: foodId)) {
      await _client
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('food_id', foodId);
      return false;
    }
    await _client.from('favorites').insert({
      'user_id': userId,
      'food_id': foodId,
    });
    return true;
  }

  Future<List<Food>> listOf(String userId) async {
    final rows = await _client
        .from('favorites')
        .select('foods(*, nutritions(*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows
        .where((r) => r['foods'] != null)
        .map((r) => Food.fromMap(r['foods'] as Map<String, dynamic>))
        .toList();
  }
}
