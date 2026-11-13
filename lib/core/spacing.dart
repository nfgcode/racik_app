import 'package:flutter/widgets.dart';

/// Skala jarak aplikasi (kelipatan 4). Semua padding dan SizedBox memakai
/// nilai dari sini, supaya jarak di setiap halaman konsisten.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4; // antarbaris label–nilai
  static const double sm = 8; // antarchip, judul kartu → isi
  static const double md = 12; // gambar → teks, antarbagian kecil
  static const double lg = 16; // tepi halaman, isi kartu, antarkolom isian
  static const double xl = 24; // antarbagian besar, sebelum tombol utama
  // ruang lega di tengah layar (splash, state kosong)
  static const double xxl = 32;

  /// Jarak tepi semua halaman.
  static const page = EdgeInsets.all(lg);
}
