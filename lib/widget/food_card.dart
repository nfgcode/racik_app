import 'package:flutter/material.dart';

import '../ai/fuzzy_health_score.dart';
import '../core/formatters.dart';
import '../core/spacing.dart';
import '../model/food.dart';
import 'food_image.dart';
import 'health_score_card.dart';

/// Satu baris resep di halaman daftar resep.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.food, this.onTap});

  final Food food;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final nutrition = food.nutrition;
    final health = nutrition == null
        ? null
        : FuzzyHealthScore.evaluate(nutrition);
    final info = [
      if (food.category != null) food.category!,
      if (food.cookTimeMinutes != null) '${food.cookTimeMinutes} menit',
      if (food.nutrition != null)
        '${Fmt.number(food.nutrition!.calories, decimals: 0)} kkal',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              FoodImage(url: food.imageUrl, size: 72),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Container(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(food.name, style: textTheme.titleMedium),
                      if (info.isNotEmpty)
                        Text(info, style: textTheme.bodySmall),
                      if (food.difficulty != null)
                        Text(
                          'Tingkat ${food.difficulty}',
                          style: textTheme.bodySmall,
                        ),
                      if (health != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        HealthScoreBadge(
                          label: health.label,
                          score: health.score,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
