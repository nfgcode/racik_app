import 'package:supabase_flutter/supabase_flutter.dart';

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
    var request = _client.from('users').select();
    if (query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or('username.ilike.%$q%,full_name.ilike.%$q%');
    }
    final rows = await request.order('created_at', ascending: false);
    return rows.map(AppUser.fromMap).toList();
  }

  Future<void> updateAccess(AppUser user) {
    return _client.from('users').update(user.toAdminMap()).eq('id', user.id);
  }
}
