import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/query_text.dart';
import '../models/app_user.dart';

/// Use case: Mengelola Akun Pengguna (Admin).
///
/// Admin bisa mengubah peran dan menonaktifkan akun. Menghapus akun
/// Supabase Auth butuh secret key, jadi TIDAK dilakukan dari aplikasi —
/// akun cukup dinonaktifkan (`is_active = false`).
class UserService {
  UserService(this._client);

  final SupabaseClient _client;

  Future<List<AppUser>> list({String query = ''}) async {
    if (query.trim().isEmpty) {
      final rows = await _client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      return rows.map(AppUser.fromMap).toList();
    }

    // Cari di username ATAU nama lengkap. Dua query terpisah, bukan
    // `.or('username.ilike.…,full_name.ilike.…')`: teks pencarian yang memuat
    // koma atau tanda kurung akan merusak sintaks filter or() PostgREST.
    final pattern = containsPattern(query);
    final results = await Future.wait([
      for (final column in ['username', 'full_name'])
        _client
            .from('users')
            .select()
            .ilike(column, pattern)
            .order('created_at', ascending: false),
    ]);

    final byId = <String, AppUser>{
      for (final rows in results)
        for (final row in rows) row['id'] as String: AppUser.fromMap(row),
    };
    final users = byId.values.toList()
      ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return users;
  }

  Future<void> updateAccess(AppUser user) {
    return _client.from('users').update(user.toAdminMap()).eq('id', user.id);
  }
}
