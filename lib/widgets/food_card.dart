import 'package:flutter/material.dart';

import '../ai/fuzzy_health_score.dart';
import '../core/formatters.dart';
import '../models/food.dart';
import 'food_image.dart';
import 'health_score_card.dart';

/// Satu baris resep di hasil pencarian.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.food, this.onTap, this.trailing});

  final Food food;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final health = food.nutrition == null
        ? null
        : FuzzyHealthScore.evaluate(food.nutrition!);

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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FoodImage(url: food.imageUrl, size: 72),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(food.name, style: textTheme.titleMedium),
                    if (info.isNotEmpty)
                      Text(info, style: textTheme.bodySmall),
                    if (health != null) ...[
                      const SizedBox(height: 6),
                      HealthScoreBadge(label: health.label, score: health.score),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
