import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/scan_history.dart';

/// Use case: Memindai Makanan (menyimpan hasil) dan
/// Melihat Hasil Pemindaian Makanan (Pengguna).
class ScanService {
  ScanService(this._client);

  final SupabaseClient _client;

  Future<ScanHistory> save(ScanHistory scan) async {
    final row = await _client
        .from('scan_history')
        .insert(scan.toMap())
        .select('*, foods(name)')
        .single();
    return ScanHistory.fromMap(row);
  }

  /// Riwayat milik satu pengguna, terbaru di atas. Join `foods(name)`
  /// supaya daftar bisa menampilkan nama makanan tanpa query tambahan.
  Future<List<ScanHistory>> historyOf(String userId) async {
    final rows = await _client
        .from('scan_history')
        .select('*, foods(name)')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(ScanHistory.fromMap).toList();
  }

  Future<void> delete(String id) {
    return _client.from('scan_history').delete().eq('id', id);
  }

  /// Izin pemilik agar foto pindai [scanId] boleh dijadikan foto resep oleh
  /// admin (fungsi SQL `share_scan_photo`). Mengembalikan `false` bila izin
  /// tidak diperlukan: resepnya sudah punya foto, atau riwayat ini tidak
  /// tertaut ke resep. Menarik izin ([share] = false) selalu berhasil.
  Future<bool> setSharePhoto(String scanId, {required bool share}) async {
    final result = await _client.rpc('share_scan_photo', params: {
      'p_scan_id': scanId,
      'p_share': share,
    });
    return result == true;
  }

  /// Admin: foto pindai resep [foodId] yang diizinkan pemiliknya untuk
  /// dijadikan foto resep, terbaru di atas. RLS hanya mengizinkan admin
  /// membaca riwayat milik orang lain.
  Future<List<ScanHistory>> photoCandidates(String foodId, {int limit = 12}) async {
    final rows = await _client
        .from('scan_history')
        .select('id, user_id, food_id, image_url, scan_status, share_photo, created_at')
        .eq('food_id', foodId)
        .eq('share_photo', true)
        .not('image_url', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(ScanHistory.fromMap).toList();
  }
}
