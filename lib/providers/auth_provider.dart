import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

/// Tiga aktor pada diagram use case + satu status sebelum sesi terbaca.
enum Actor { memuat, guest, pengguna, admin }

/// Menyimpan siapa yang sedang memakai aplikasi dan memberi tahu semua
/// widget yang "mendengarkan" (context.watch) setiap kali berubah.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._service) {
    // Supabase langsung memancarkan event initialSession saat didengarkan,
    // jadi sesi login yang tersimpan di HP terbaca otomatis.
    _subscription = _service.authChanges.listen(_onAuthChanged);
  }

  final AuthService _service;
  late final StreamSubscription<AuthState> _subscription;

  AppUser? _user;
  bool _sessionRead = false;
  bool _busy = false;
  String? _notice;

  AppUser? get user => _user;
  String? get email => _service.currentEmail;
  bool get isBusy => _busy;
  bool get isLoggedIn => _user != null;

  /// Pesan satu kali untuk UI, mis. "akun dinonaktifkan".
  String? takeNotice() {
    final n = _notice;
    _notice = null;
    return n;
  }

  Actor get actor {
    if (!_sessionRead) return Actor.memuat;
    if (_user == null) return Actor.guest;
    return _user!.isAdmin ? Actor.admin : Actor.pengguna;
  }

  Future<void> _onAuthChanged(AuthState state) async {
    final session = state.session;
    if (session == null) {
      _user = null;
    } else {
      try {
        final profile = await _service.fetchProfile(session.user.id);
        if (profile == null || !profile.isActive) {
          _notice = profile == null
              ? 'Profil akun tidak ditemukan. Hubungi admin.'
              : 'Akun Anda dinonaktifkan oleh admin.';
          await _service.logout();
          return; // event signedOut berikutnya akan membersihkan _user
        }
        _user = profile;
      } catch (e) {
        _notice = friendlyError(e);
        _user = null;
      }
    }
    _sessionRead = true;
    notifyListeners();
  }

  /// Semua method di bawah mengembalikan pesan error, atau null bila sukses.
  Future<String?> login(String email, String password) {
    return _run(() => _service.login(email: email.trim(), password: password));
  }

  /// Mengembalikan `null` bila sukses, atau pesan error. Bila Supabase
  /// meminta konfirmasi email, [onNeedsConfirmation] dipanggil.
  Future<String?> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required VoidCallback onNeedsConfirmation,
  }) {
    return _run(() async {
      final available = await _service.isUsernameAvailable(username);
      if (!available) throw const FormatException('Username sudah dipakai.');
      final loggedIn = await _service.register(
        email: email.trim(),
        password: password,
        username: username,
        fullName: fullName,
      );
      if (!loggedIn) onNeedsConfirmation();
    });
  }

  Future<String?> updateProfile(AppUser updated) {
    return _run(() async {
      _user = await _service.updateProfile(updated);
    });
  }

  Future<void> logout() => _service.logout();

  Future<String?> _run(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
      return null;
    } catch (e) {
      return friendlyError(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
