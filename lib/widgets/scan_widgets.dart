import 'package:flutter/material.dart';

import '../core/config.dart';
import '../models/scan_history.dart';

/// Nama makanan hasil tebakan AI + seberapa yakin AI-nya.
/// Dipakai di hasil pindai dan di detail riwayat.
class ScanHeader extends StatelessWidget {
  const ScanHeader({
    super.key,
    required this.foodName,
    required this.confidencePercent,
  });

  final String foodName;
  final double confidencePercent; // 0..100

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final lowConfidence =
        confidencePercent < AppConfig.confidenceThreshold * 100;

    return Semantics(
      label: 'Terdeteksi $foodName, keyakinan AI '
          '${confidencePercent.toStringAsFixed(0)} persen',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Terdeteksi', style: textTheme.labelLarge),
          Text(foodName, style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: confidencePercent / 100,
                    minHeight: 6,
                    color: lowConfidence ? scheme.error : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('Keyakinan AI ${confidencePercent.toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pita penjelasan untuk status selain "berhasil".
class ScanStatusBanner extends StatelessWidget {
  const ScanStatusBanner({super.key, required this.status, required this.label});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, String text) = switch (status) {
      ScanHistory.statusTidakYakin => (
          Icons.help_outline,
          'AI kurang yakin dengan tebakan ini. Coba foto ulang dengan cahaya '
              'lebih terang, satu makanan per foto, dari jarak ±30 cm.',
        ),
      ScanHistory.statusTidakDitemukan => (
          Icons.info_outline,
          '"$label" dikenali, tetapi data resep dan nutrisinya belum ada '
              'di Racik.',
        ),
      _ => (Icons.check_circle_outline, 'Makanan berhasil dikenali.'),
    };

    if (status == ScanHistory.statusBerhasil) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label status dalam bahasa manusia, untuk daftar riwayat & statistik.
String scanStatusText(String status) => switch (status) {
      ScanHistory.statusBerhasil => 'Berhasil',
      ScanHistory.statusTidakYakin => 'Tidak yakin',
      ScanHistory.statusTidakDitemukan => 'Data belum ada',
      _ => status,
    };
