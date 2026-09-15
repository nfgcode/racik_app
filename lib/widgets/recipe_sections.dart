import 'package:flutter/material.dart';

import '../models/food_ingredient.dart';
import '../models/recipe_step.dart';

/// Use case "Menampilkan Bahan dan Langkah Memasak" — bagian bahan.
class IngredientList extends StatelessWidget {
  const IngredientList({super.key, required this.items});

  final List<FoodIngredient> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bahan', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty) const Text('Belum ada data bahan.'),
            for (final item in items)
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 96,
                        child: Text(
                          item.amountLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Expanded(
                        child: Text([
                          item.ingredient?.name ?? '(bahan terhapus)',
                          if (item.note != null && item.note!.isNotEmpty)
                            '— ${item.note}',
                        ].join(' ')),
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

/// Use case "Menampilkan Bahan dan Langkah Memasak" — bagian langkah.
class StepList extends StatelessWidget {
  const StepList({super.key, required this.steps});

  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Langkah memasak', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            if (steps.isEmpty) const Text('Belum ada langkah memasak.'),
            for (final step in steps)
              MergeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: scheme.primaryContainer,
                        child: Text(
                          '${step.stepOrder}',
                          semanticsLabel: 'Langkah ${step.stepOrder}',
                          style: TextStyle(color: scheme.onPrimaryContainer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(step.instruction),
                            if (step.durationMinutes != null)
                              Text(
                                '± ${step.durationMinutes} menit',
                                style: textTheme.bodySmall,
                              ),
                          ],
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
