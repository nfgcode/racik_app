import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../model/nutrition.dart';

/// Use case "Menampilkan Informasi Nutrisi".
///
/// Bagian detail resep yang menampilkan nutrisi per porsi.
class NutritionCard extends StatelessWidget {
  const NutritionCard({super.key, required this.nutrition, this.servingSize});

  final Nutrition nutrition;
  final String? servingSize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = <(String, double?, String)>[
      ('Energi', nutrition.calories, 'kkal'),
      ('Protein', nutrition.proteinG, 'g'),
      ('Lemak', nutrition.fatG, 'g'),
      ('Karbohidrat', nutrition.carbsG, 'g'),
      ('Gula', nutrition.sugarG, 'g'),
      ('Natrium', nutrition.sodiumMg, 'mg'),
      ('Serat', nutrition.fiberG, 'g'),
    ];

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informasi nutrisi', style: textTheme.titleMedium),
            if (servingSize != null)
              Text('per porsi · $servingSize', style: textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final (name, value, unit) in rows)
              // MergeSemantics: pembaca layar membaca satu baris utuh,
              // "Protein 12 g", bukan dua potongan terpisah.
              MergeSemantics(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(name)),
                      Text(
                        value == null ? '-' : '${Fmt.number(value)} $unit',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
