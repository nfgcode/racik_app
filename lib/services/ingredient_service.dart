import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ingredient.dart';

/// Use case: Mengelola Data Bahan (Admin).
class IngredientService {
  IngredientService(this._client);

  final SupabaseClient _client;

  Future<List<Ingredient>> list({String query = ''}) async {
    var request = _client.from('ingredients').select();
    if (query.trim().isNotEmpty) {
      request = request.ilike('name', '%${query.trim()}%');
    }
    final rows = await request.order('name');
    return rows.map(Ingredient.fromMap).toList();
  }

  Future<void> save(Ingredient ingredient) async {
    if (ingredient.id == null) {
      await _client.from('ingredients').insert(ingredient.toMap());
    } else {
      await _client
          .from('ingredients')
          .update(ingredient.toMap())
          .eq('id', ingredient.id!);
    }
  }

  /// Gagal (kode 23503) bila bahan masih dipakai di food_ingredients.
  Future<void> delete(String id) {
    return _client.from('ingredients').delete().eq('id', id);
  }
}
