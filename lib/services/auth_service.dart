import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_user.dart';

/// Use case: Mendaftar Akun, Melakukan Login, Mengubah Profil Akun (+ Logout).
///
/// Service hanya berbicara dengan Supabase. Ia tidak tahu apa pun tentang
/// widget — tugas memberi tahu UI ada di AuthProvider.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  /// Stream yang memancarkan event setiap kali status login berubah
  /// (initialSession, signedIn, signedOut, tokenRefreshed, ...).
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  String? get currentEmail => _client.auth.currentUser?.email;

  /// Cek username lewat fungsi SQL `username_available` (lihat schema.sql).
  /// Perlu RPC karena tamu belum login sehingga tidak boleh membaca tabel
  /// `users` secara langsung.
  Future<bool> isUsernameAvailable(String username) async {
    final result = await _client.rpc(
      'username_available',
      params: {'p_username': username},
    );
    return result as bool;
  }

  /// Membuat akun di Supabase Auth. Baris di tabel `users` dibuat otomatis
  /// oleh trigger `handle_new_user` dari metadata `username` & `full_name`.
  ///
  /// Mengembalikan `true` bila langsung login, `false` bila Supabase
  /// meminta konfirmasi email terlebih dahulu.
  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'full_name': fullName},
    );
    return response.session != null;
  }

  Future<void> login({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> logout() => _client.auth.signOut();

  Future<AppUser?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : AppUser.fromMap(row);
  }

  Future<AppUser> updateProfile(AppUser user) async {
    final row = await _client
        .from('users')
        .update(user.toProfileMap())
        .eq('id', user.id)
        .select()
        .single();
    return AppUser.fromMap(row);
  }
}
