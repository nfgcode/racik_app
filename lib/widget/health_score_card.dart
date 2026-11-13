import 'package:flutter/material.dart';

import '../ai/fuzzy_health_score.dart';
import '../core/formatters.dart';
import '../core/spacing.dart';
import '../core/theme.dart';

/// Lencana kecil "● Sehat 82" untuk kartu resep dan daftar riwayat.
class HealthScoreBadge extends StatelessWidget {
  const HealthScoreBadge({super.key, required this.label, this.score});

  final String label;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final style = HealthStyle.of(label);
    final text = score == null ? label : '$label ${score!.toStringAsFixed(0)}';
    return Semantics(
      label: 'Skor kesehatan $text',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(style.icon, size: 16, color: style.color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: TextStyle(color: style.color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Use case "Menampilkan Detail Skor Kesehatan": angka skor, labelnya, dan
/// (bila [result] ada) alasan perhitungan fuzzy di balik skor itu.
class HealthScoreCard extends StatelessWidget {
  const HealthScoreCard({
    super.key,
    required this.score,
    required this.label,
    this.result,
  });

  HealthScoreCard.fromResult(HealthScoreResult r, {super.key})
    : score = r.score,
      label = r.label,
      result = r;

  final double score;
  final String label;
  final HealthScoreResult? result;

  @override
  Widget build(BuildContext context) {
    final style = HealthStyle.of(label);
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skor kesehatan', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              label:
                  'Skor kesehatan ${score.toStringAsFixed(0)} dari 100, '
                  'kategori $label',
              excludeSemantics: true,
              child: Container(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      score.toStringAsFixed(0),
                      style: textTheme.displayMedium?.copyWith(
                        color: style.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text('/ 100', style: textTheme.titleMedium),
                    const Spacer(),
                    HealthScoreBadge(label: label),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                color: style.color,
              ),
            ),
            if (result != null) ...[
              if (result!.hasMissingData) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Sebagian data nutrisi kosong dan dianggap 0, '
                  'jadi skor ini bisa kurang akurat.',
                  style: textTheme.bodySmall,
                ),
              ],
              _FuzzyDetails(result: result!),
            ],
          ],
        ),
      ),
    );
  }
}

/// Isi "Mengapa skornya segini?": derajat keanggotaan tiap zat dan aturan
/// fuzzy yang paling kuat.
class _FuzzyDetails extends StatelessWidget {
  const _FuzzyDetails({required this.result});

  final HealthScoreResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Theme(
      // Menghilangkan garis bawaan ExpansionTile agar menyatu dengan Card.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: const Text('Mengapa skornya segini?'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final input in result.inputs)
            Container(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${input.name}: ${Fmt.number(input.value)} ${input.unit}'
                    ' → ${input.dominantSet}',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    input.degrees.entries
                        .map((e) => '${e.key} ${e.value.toStringAsFixed(2)}')
                        .join('  ·  '),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text('Aturan terkuat', style: textTheme.labelLarge),
          for (final rule in result.firedRules.take(3))
            Container(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'α ${rule.alpha.toStringAsFixed(2)} — ${rule.description}',
                style: textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
