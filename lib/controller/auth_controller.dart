import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors.dart';
import '../enum/auth_status.dart';
import '../enum/load_state.dart';
import '../model/app_user.dart';
import '../service/auth_service.dart';

/// Menyimpan siapa yang sedang memakai aplikasi (Guest atau Pengguna) dan
/// status proses login/daftar. Halaman mendengarkan lewat ListenableBuilder.
class AuthController extends ChangeNotifier {
  final AuthService authService;

  AuthController({required this.authService}) {
    // Supabase langsung memancarkan event initialSession saat didengarkan,
    // jadi sesi login yang tersimpan di HP terbaca otomatis.
    _subscription = authService.authChanges.listen(_onAuthChanged);
  }

  late final StreamSubscription<AuthState> _subscription;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  LoadState _loadState = LoadState.initial;
  String _errorMessage = '';
  bool _needsEmailConfirmation = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  String? get email => authService.currentEmail;
  bool get isLoggedIn => _status == AuthStatus.signedIn;
  LoadState get loadState => _loadState;
  bool get isLoading => _loadState == LoadState.loading;
  String get errorMessage => _errorMessage;

  /// True bila Supabase meminta konfirmasi email setelah daftar.
  bool get needsEmailConfirmation => _needsEmailConfirmation;

  Future<void> _onAuthChanged(AuthState state) async {
    final session = state.session;
    if (session == null) {
      _user = null;
      _status = AuthStatus.guest;
    } else {
      try {
        // Profil dibuat trigger `handle_new_user`; bila belum terbaca,
        // pakai username dari metadata pendaftaran.
        _user =
            await authService.fetchProfile(session.user.id) ??
            AppUser(
              id: session.user.id,
              username:
                  session.user.userMetadata?['username'] as String? ??
                  session.user.email ??
                  'pengguna',
              fullName: session.user.userMetadata?['full_name'] as String?,
            );
      } catch (e) {
        _errorMessage = friendlyError(e);
      }
      _status = AuthStatus.signedIn;
    }
    notifyListeners();
  }

  /// Mengembalikan true bila berhasil. Pesan gagal ada di [errorMessage].
  Future<bool> login(String email, String password) {
    return _run(
      () => authService.login(email: email.trim(), password: password),
    );
  }

  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) {
    _needsEmailConfirmation = false;
    return _run(() async {
      final available = await authService.isUsernameAvailable(username);
      if (!available) throw const FormatException('Username sudah dipakai.');
      final loggedIn = await authService.register(
        email: email.trim(),
        password: password,
        username: username,
        fullName: fullName,
      );
      _needsEmailConfirmation = !loggedIn;
    });
  }

  Future<void> logout() => authService.logout();

  Future<bool> _run(Future<void> Function() action) async {
    _loadState = LoadState.loading;
    _errorMessage = '';
    notifyListeners();
    try {
      await action();
      _loadState = LoadState.loaded;
      return true;
    } catch (e) {
      _errorMessage = friendlyError(e);
      _loadState = LoadState.error;
      return false;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
