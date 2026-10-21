import 'package:flutter/material.dart';

import '../model/food.dart';
import '../widget/food_image.dart';
import '../widget/nutrition_card.dart';
import '../widget/recipe_sections.dart';

/// Use case: Melihat Detail Resep
///   └─ `<<include>>` Menampilkan Bahan dan Langkah Memasak
///       └─ `<<include>>` Menampilkan Informasi Nutrisi
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList.list(
              children: [
                if (food.imageUrl != null)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: FoodImage(url: food.imageUrl),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                  const SizedBox(height: 12),
                  Text(food.description!, style: textTheme.bodyLarge),
                ],
                const SizedBox(height: 12),
                IngredientList(items: food.ingredients),
                StepList(steps: food.steps),
                if (food.nutrition != null)
                  NutritionCard(
                    nutrition: food.nutrition!,
                    servingSize: food.servingSize,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
