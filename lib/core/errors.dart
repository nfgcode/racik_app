import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengubah exception teknis menjadi kalimat yang bisa dibaca pengguna.
String friendlyError(Object error) {
  if (error is SocketException || error is TimeoutException) {
    return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
  }
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login')) return 'Email atau password salah.';
    if (msg.contains('already registered')) return 'Email sudah terdaftar.';
    if (msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Buka tautan di email Anda dulu.';
    }
    if (msg.contains('password')) {
      return 'Password minimal 6 karakter.';
    }
    if (msg.contains('database error')) {
      return 'Pendaftaran gagal. Username mungkin sudah dipakai.';
    }
    return error.message;
  }
  if (error is PostgrestException) {
    // 23505 = unique_violation, 23503 = foreign_key_violation
    if (error.code == '23505') return 'Data dengan nama itu sudah ada.';
    if (error.code == '23503') {
      return 'Data ini masih dipakai di tempat lain, jadi belum bisa dihapus.';
    }
    if (error.code == '42501') {
      return 'Anda tidak punya izin untuk tindakan ini.';
    }
    return error.message;
  }
  if (error is StorageException) return 'Gagal mengunggah foto: ${error.message}';
  if (error is FormatException) return error.message;
  return 'Terjadi kesalahan: $error';
}
