import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengubah exception teknis menjadi kalimat yang bisa dibaca pengguna.
String friendlyError(Object error) {
  // Di web, gangguan jaringan datang sebagai ClientException, bukan SocketException.
  if (error is SocketException ||
      error is TimeoutException ||
      error is ClientException) {
    return 'Tidak ada koneksi internet. Periksa jaringan lalu coba lagi.';
  }
  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login')) return 'Email atau password salah.';
    if (msg.contains('already registered')) return 'Email sudah terdaftar.';
    if (msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Buka tautan di email Anda dulu.';
    }
    if (msg.contains('password')) return 'Password minimal 6 karakter.';
    if (msg.contains('database error')) {
      return 'Pendaftaran gagal. Username mungkin sudah dipakai.';
    }
    return error.message;
  }
  if (error is PostgrestException) return error.message;
  if (error is FormatException) return error.message;
  return 'Terjadi kesalahan: $error';
}
