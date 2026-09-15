import 'package:flutter/material.dart';

/// Tema Material 3. Semua warna diturunkan dari satu warna dasar (seed),
/// jadi mengganti identitas warna cukup mengubah [seed].
class AppTheme {
  const AppTheme._();

  static const seed = Color(0xFF2F7D4F); // hijau daun pandan

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      // Target sentuh minimal 48 dp — penting untuk aksesibilitas.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
      ),
    );
  }
}

/// Warna + ikon untuk label skor kesehatan. Warna TIDAK pernah berdiri
/// sendiri: selalu ditemani ikon dan teks, agar tetap terbaca oleh
/// pengguna buta warna.
class HealthStyle {
  const HealthStyle(this.color, this.icon);

  final Color color;
  final IconData icon;

  static HealthStyle of(String? label) {
    switch (label) {
      case 'Sehat':
        return const HealthStyle(Color(0xFF2E7D32), Icons.check_circle);
      case 'Cukup Sehat':
        return const HealthStyle(Color(0xFFB26A00), Icons.remove_circle);
      case 'Kurang Sehat':
        return const HealthStyle(Color(0xFFC62828), Icons.warning_rounded);
      default:
        return const HealthStyle(Colors.grey, Icons.help);
    }
  }
}
