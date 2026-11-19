import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/query_text.dart';
import '../models/food.dart';
import '../models/food_ingredient.dart';
import '../models/nutrition.dart';
import '../models/recipe_step.dart';

/// Use case: Mencari Resep, Melihat Detail Resep (Guest & Pengguna),
/// Mengelola Data Resep (Admin).
class FoodService {
  FoodService(this._client);

  final SupabaseClient _client;

  /// Satu query mengambil resep beserta seluruh relasinya (join otomatis
  /// PostgREST berdasarkan foreign key di ERD).
  static const _detailColumns =
      '*, nutritions(*), steps(*), food_ingredients(*, ingredients(*))';

  /// Mencari Resep. Tamu dan pengguna hanya melihat resep terverifikasi;
  /// Admin memakai [includeUnverified] untuk melihat semuanya.
  Future<List<Food>> search({
    String query = '',
    String? category,
    bool includeUnverified = false,
  }) async {
    var request = _client.from('foods').select('*, nutritions(*)');
    if (query.trim().isNotEmpty) {
      request = request.ilike('name', containsPattern(query));
    }
    if (category != null) request = request.eq('category', category);
    if (!includeUnverified) request = request.eq('is_verified', true);

    final rows = await request.order('name');
    return rows.map(Food.fromMap).toList();
  }

  /// Daftar kategori unik untuk filter di layar pencarian.
  Future<List<String>> categories() async {
    final rows = await _client
        .from('foods')
        .select('category')
        .eq('is_verified', true)
        .not('category', 'is', null);
    final set = {for (final r in rows) r['category'] as String};
    return set.toList()..sort();
  }

  /// Melihat Detail Resep — termasuk bahan, langkah, dan nutrisi
  /// (dua relasi `<<include>>` di diagram use case).
  Future<Food?> getDetail(String id) async {
    final row = await _client
        .from('foods')
        .select(_detailColumns)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Food.fromMap(row);
  }

  /// Dipakai ScanPipeline: cocokkan label AI ke nama resep
  /// (tanpa membedakan huruf besar/kecil, dengan fallback pencocokan parsial).
  Future<Food?> findByName(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;

    // 1. Cocokkan persis (case-insensitive). Label di-escape supaya % dan _
    //    dari AI tidak dianggap wildcard.
    final rows = await _client
        .from('foods')
        .select(_detailColumns)
        .ilike('name', escapeLike(cleanName))
        .eq('is_verified', true)
        .limit(1);
    if (rows.isNotEmpty) return Food.fromMap(rows.first);

    // 2. Cocokkan parsial jika nama resep mengandung nama dari AI
    final partial = await _client
        .from('foods')
        .select(_detailColumns)
        .ilike('name', containsPattern(cleanName))
        .eq('is_verified', true)
        .limit(1);
    if (partial.isNotEmpty) return Food.fromMap(partial.first);

    // 3. Bila label AI terdiri dari beberapa kata (misal: "Es Kopi Susu"),
    // coba cari berdasarkan kata utamanya
    final words = cleanName.split(RegExp(r'\s+'));
    if (words.length > 1) {
      final lead = words.take(2).join(' ');
      final leadMatch = await _client
          .from('foods')
          .select(_detailColumns)
          .ilike('name', containsPattern(lead))
          .eq('is_verified', true)
          .limit(1);
      if (leadMatch.isNotEmpty) return Food.fromMap(leadMatch.first);
    }

    return null;
  }

  /// Simpan makanan hasil pindai AI yang belum ada di database, lewat fungsi
  /// SQL `create_food_from_ai` (lihat supabase/schema.sql).
  ///
  /// Pengguna biasa tidak boleh menulis ke tabel `foods` (RLS khusus admin),
  /// jadi penyimpanan lewat fungsi itu. Resepnya selalu `is_verified = false`
  /// (menunggu ditinjau admin), dan resep + nutrisi tersimpan dalam satu
  /// transaksi sehingga tidak ada resep tanpa nutrisi.
  ///
  /// Fungsi itu mengembalikan resep + gizi yang TERSIMPAN. Bila makanan yang
  /// sama sudah pernah dipindai orang lain, angka gizi dari pindaian pertama
  /// yang dipakai, bukan tebakan AI kali ini, sehingga semua pengguna melihat
  /// angka yang sama.
  ///
  /// Bila penyimpanan gagal (mis. offline), tetap mengembalikan [Food] tanpa
  /// `id` supaya skor kesehatan dan nutrisi hasil AI tetap tampil.
  Future<Food> createFromAi({
    required String name,
    required Nutrition nutrition,
  }) async {
    try {
      final row = await _client.rpc('create_food_from_ai', params: {
        'p_name': name,
        'p_calories': nutrition.calories,
        'p_protein_g': nutrition.proteinG,
        'p_fat_g': nutrition.fatG,
        'p_carbs_g': nutrition.carbsG,
        'p_sugar_g': nutrition.sugarG,
        'p_sodium_mg': nutrition.sodiumMg,
        'p_fiber_g': nutrition.fiberG,
      });
      if (row is Map<String, dynamic>) {
        return Food.fromMap({
          ...row,
          // Seharusnya selalu ada; jaga-jaga memakai tebakan AI.
          if (row['nutritions'] == null) 'nutritions': nutrition.toMap(),
        });
      }
      debugPrint('Info: balasan create_food_from_ai tidak dikenal ($row). '
          'Sudah menjalankan supabase/patch-03-foto-kandidat.sql?');
    } catch (e) {
      debugPrint('Info: hasil AI tidak tersimpan ke database ($e), memakai objek Food lokal.');
    }

    return Food(
      name: name,
      description: 'Resep makanan teridentifikasi secara otomatis oleh AI.',
      category: 'Hasil Pindai AI',
      servingSize: '1 porsi',
      source: Food.sourceAi,
      isVerified: false,
      nutrition: nutrition,
    );
  }

  // ------------------------------------------------------------ Admin ---

  /// Simpan resep beserta nutrisi, bahan, dan langkahnya.
  /// Mengembalikan id resep.
  Future<String> saveFood({
    required Food food,
    required Nutrition nutrition,
    required List<FoodIngredient> ingredients,
    required List<RecipeStep> steps,
    required String adminId,
  }) async {
    final String foodId;
    if (food.id == null) {
      final row = await _client
          .from('foods')
          .insert({...food.toMap(), 'created_by': adminId})
          .select('id')
          .single();
      foodId = row['id'] as String;
    } else {
      foodId = food.id!;
      await _client.from('foods').update(food.toMap()).eq('id', foodId);
    }

    // nutritions berelasi 1 : 1 → upsert berdasarkan food_id yang unik.
    await _client.from('nutritions').upsert(
          {...nutrition.toMap(), 'food_id': foodId},
          onConflict: 'food_id',
        );

    // Cara paling sederhana untuk daftar anak: hapus semua, lalu isi ulang.
    await _client.from('food_ingredients').delete().eq('food_id', foodId);
    if (ingredients.isNotEmpty) {
      await _client
          .from('food_ingredients')
          .insert(ingredients.map((e) => e.toMap(foodId)).toList());
    }

    await _client.from('steps').delete().eq('food_id', foodId);
    if (steps.isNotEmpty) {
      await _client
          .from('steps')
          .insert(steps.map((e) => e.toMap(foodId)).toList());
    }

    return foodId;
  }

  /// Verifikasi resep: mengisi `is_verified`, `verified_by`, `verified_at`.
  Future<void> setVerified({
    required String foodId,
    required bool verified,
    required String adminId,
  }) {
    return _client.from('foods').update({
      'is_verified': verified,
      'verified_by': verified ? adminId : null,
      'verified_at': verified ? DateTime.now().toUtc().toIso8601String() : null,
    }).eq('id', foodId);
  }

  /// Nutrisi, bahan resep, langkah, dan favorit ikut terhapus
  /// (ON DELETE CASCADE). Riwayat pindai tetap ada dengan food_id = null.
  Future<void> deleteFood(String id) {
    return _client.from('foods').delete().eq('id', id);
  }
}
