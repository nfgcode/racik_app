import 'package:flutter/material.dart';

import '../ai/fuzzy_health_score.dart';
import '../core/spacing.dart';
import '../model/food.dart';
import '../widget/food_image.dart';
import '../widget/health_score_card.dart';
import '../widget/nutrition_card.dart';
import '../widget/recipe_sections.dart';

/// Use case: Melihat Detail Resep
///   └─ `<<include>>` Menampilkan Bahan dan Langkah Memasak
///       └─ `<<include>>` Menampilkan Informasi Nutrisi
/// ditambah skor kesehatan fuzzy dari data nutrisinya.
///
/// Data resep sudah lengkap sejak dimuat di halaman daftar, jadi halaman
/// ini cukup menampilkan objek [food] yang dioper lewat konstruktor.
class FoodDetailPage extends StatelessWidget {
  final Food food;

  const FoodDetailPage({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(title: Text(food.name)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            sliver: SliverList.list(
              children: [
                if (food.imageUrl != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: FoodImage(url: food.imageUrl),
                  ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (food.category != null)
                      Chip(
                        avatar: const Icon(Icons.category, size: 18),
                        label: Text(food.category!),
                      ),
                    if (food.cookTimeMinutes != null)
                      Chip(
                        avatar: const Icon(Icons.timer, size: 18),
                        label: Text('${food.cookTimeMinutes} menit'),
                      ),
                    if (food.difficulty != null)
                      Chip(
                        avatar: const Icon(Icons.signal_cellular_alt, size: 18),
                        label: Text('Tingkat ${food.difficulty}'),
                      ),
                    if (food.servingSize != null)
                      Chip(
                        avatar: const Icon(Icons.restaurant, size: 18),
                        label: Text(food.servingSize!),
                      ),
                  ],
                ),
                if (food.description != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(food.description!, style: textTheme.bodyLarge),
                ],
                const SizedBox(height: AppSpacing.md),
                IngredientList(items: food.ingredients),
                StepList(steps: food.steps),
                if (food.nutrition != null) ...[
                  NutritionCard(
                    nutrition: food.nutrition!,
                    servingSize: food.servingSize,
                  ),
                  HealthScoreCard.fromResult(
                    FuzzyHealthScore.evaluate(food.nutrition!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
