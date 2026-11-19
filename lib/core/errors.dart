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
    // Kode error Supabase Auth lebih tepat daripada isi pesan; pesan dipakai
    // sebagai cadangan untuk versi server yang belum mengirim kode.
    final code = error.code;
    final msg = error.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login')) {
      return 'Email atau password salah.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered')) {
      return 'Email sudah terdaftar.';
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Buka tautan di email Anda dulu.';
    }
    if (code == 'same_password') {
      return 'Password baru harus berbeda dari password lama.';
    }
    if (msg.contains('at least 6 characters')) {
      return 'Password minimal 6 karakter.';
    }
    if (code == 'weak_password') {
      // Aturan kekuatan password lain (huruf besar, angka, dsb.) diatur di
      // dashboard Supabase; tampilkan pesan aslinya supaya jelas syaratnya.
      return 'Password terlalu lemah. ${error.message}';
    }
    if (msg.contains('database error')) {
      return 'Pendaftaran gagal. Username mungkin sudah dipakai.';
    }
    return error.message;
  }
  if (error is FunctionException) {
    if (error.status == 401) return 'Sesi berakhir. Silakan masuk lagi.';
    if (error.status == 404) {
      return 'Layanan AI belum siap (fungsi recognize-food belum di-deploy).';
    }
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Layanan AI sedang bermasalah. Coba lagi sebentar lagi.';
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
