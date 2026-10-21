import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../model/food.dart';
import 'food_image.dart';

/// Satu baris resep di halaman daftar resep.
class FoodCard extends StatelessWidget {
  const FoodCard({super.key, required this.food, this.onTap});

  final Food food;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
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
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FoodImage(url: food.imageUrl, size: 72),
              const SizedBox(width: 12),
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
