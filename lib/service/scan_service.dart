import 'package:supabase_flutter/supabase_flutter.dart';

import '../model/scan_history.dart';

/// Use case: Memindai Makanan (menyimpan hasil) dan Melihat Hasil
/// Pemindaian Makanan.
class ScanService {
  ScanService(this._client);

  final SupabaseClient _client;

  /// Join `foods(name)` supaya daftar bisa menampilkan nama makanan tanpa
  /// query tambahan.
  static const _columns = '*, foods(name)';

  Future<ScanHistory> save(ScanHistory scan) async {
    final row = await _client
        .from('scan_history')
        .insert(scan.toJson())
        .select(_columns)
        .single();
    return ScanHistory.fromJson(row);
  }

  /// Riwayat milik satu pengguna, terbaru di atas.
  Future<List<ScanHistory>> getHistory(String userId) async {
    final rows = await _client
        .from('scan_history')
        .select(_columns)
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map(ScanHistory.fromJson).toList();
  }

  Future<void> delete(String id) =>
      _client.from('scan_history').delete().eq('id', id);
}
