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
}
