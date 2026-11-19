import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

/// Tiga aktor pada diagram use case, ditambah status "memuat" (sesi belum
/// terbaca) dan "gagal memuat" (sesi ada, profil gagal dimuat).
enum Actor {
  memuat,
  guest,
  pengguna,
  admin,

  /// Sesi login ada, tetapi profil gagal dimuat (mis. offline saat aplikasi
  /// dibuka). Bukan Guest: AuthGate menampilkan layar "Coba lagi".
  gagalMemuat,
}

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
  String? _profileError;
  String? _pendingUserId;

  AppUser? get user => _user;

  /// Pesan bila profil gagal dimuat padahal sesi login masih ada.
  String? get profileError => _profileError;
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
    if (_user == null) {
      return _profileError == null ? Actor.guest : Actor.gagalMemuat;
    }
    return _user!.isAdmin ? Actor.admin : Actor.pengguna;
  }

  Future<void> _onAuthChanged(AuthState state) async {
    final session = state.session;
    if (session == null) {
      _user = null;
      _profileError = null;
      _pendingUserId = null;
    } else if (!await _loadProfile(session.user.id)) {
      return; // akun tanpa profil / dinonaktifkan: event signedOut menyusul
    }
    _sessionRead = true;
    notifyListeners();
  }

  /// Memuat profil dari tabel `users`. Mengembalikan false bila pengguna
  /// harus di-logout (profil tidak ada atau akun dinonaktifkan).
  Future<bool> _loadProfile(String userId) async {
    try {
      final profile = await _service.fetchProfile(userId);
      if (profile == null || !profile.isActive) {
        _notice = profile == null
            ? 'Profil akun tidak ditemukan. Hubungi admin.'
            : 'Akun Anda dinonaktifkan oleh admin.';
        await _service.logout();
        return false;
      }
      _user = profile;
      _profileError = null;
      _pendingUserId = null;
    } catch (e) {
      // Sesi masih ada, hanya profil yang gagal dimuat (mis. offline).
      // Jangan dianggap Guest; simpan id-nya supaya bisa dicoba lagi.
      _user = null;
      _profileError = friendlyError(e);
      _pendingUserId = userId;
    }
    return true;
  }

  /// Dipanggil tombol "Coba lagi" saat [actor] == [Actor.gagalMemuat].
  Future<void> retryProfile() async {
    final userId = _pendingUserId;
    if (userId == null || _busy) return;
    _busy = true;
    notifyListeners();
    final keepSession = await _loadProfile(userId);
    _busy = false;
    if (keepSession) notifyListeners();
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

  /// Hapus akun (syarat Google Play): foto di Storage dihapus dulu, lalu akun
  /// beserta profil, riwayat pindai, dan favoritnya. Mengembalikan `null` bila
  /// berhasil, atau pesan error.
  Future<String?> deleteAccount(StorageService storage) {
    final userId = _user!.id;
    return _run(() async {
      for (final bucket in [AppConfig.scanBucket, AppConfig.avatarBucket]) {
        await storage.removeFolder(bucket: bucket, folder: userId);
      }
      await _service.deleteAccount();
    });
  }

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
