import 'package:flutter/material.dart';

import 'spacing.dart';

/// Tema Material 3. Semua warna diturunkan dari satu warna dasar (seed),
/// jadi mengganti identitas warna cukup mengubah [seed].
class AppTheme {
  const AppTheme._();

  static const seed = Color(0xFF2F7D4F); // hijau daun pandan

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      // Kartu hanya diberi jarak atas-bawah, supaya tepi kirinya sejajar
      // dengan padding halaman (AppSpacing.lg) seperti kolom pencarian.
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      ),
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
