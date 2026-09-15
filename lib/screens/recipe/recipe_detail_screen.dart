import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/fuzzy_health_score.dart';
import '../../core/errors.dart';
import '../../models/food.dart';
import '../../providers/auth_provider.dart';
import '../../services/favorite_service.dart';
import '../../services/food_service.dart';
import '../../widgets/food_image.dart';
import '../../widgets/health_score_card.dart';
import '../../widgets/nutrition_card.dart';
import '../../widgets/recipe_sections.dart';
import '../../widgets/state_views.dart';

/// Use case: Melihat Detail Resep
///   └─ `<<include>>` Menampilkan Bahan dan Langkah Memasak
///       └─ `<<include>>` Menampilkan Informasi Nutrisi
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({super.key, required this.foodId});

  final String foodId;

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  late Future<Food?> _future;

  @override
  void initState() {
    super.initState();
    // Future disimpan di state, BUKAN dibuat di build(). Kalau dibuat di
    // build(), setiap rebuild akan memicu query baru ke database.
    _future = context.read<FoodService>().getDetail(widget.foodId);
  }

  void _reload() {
    setState(() {
      _future = context.read<FoodService>().getDetail(widget.foodId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Food?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            ),
          );
        }
        final food = snapshot.data;
        if (food == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.no_food,
              title: 'Resep tidak ditemukan',
              message: 'Resep ini mungkin sudah dihapus admin.',
            ),
          );
        }
        return _DetailView(food: food);
      },
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loggedIn = context.watch<AuthProvider>().isLoggedIn;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(food.name),
            actions: [if (loggedIn) _FavoriteButton(foodId: food.id!)],
          ),
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

/// Tombol hati — tabel `favorites`.
class _FavoriteButton extends StatefulWidget {
  const _FavoriteButton({required this.foodId});

  final String foodId;

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton> {
  bool? _isFavorite; // null = sedang dimuat

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthProvider>().user!.id;
    context
        .read<FavoriteService>()
        .isFavorite(userId: userId, foodId: widget.foodId)
        .then((value) {
      if (mounted) setState(() => _isFavorite = value);
    }).catchError((_) {
      if (mounted) setState(() => _isFavorite = false);
    });
  }

  Future<void> _toggle() async {
    final messenger = ScaffoldMessenger.of(context);
    final userId = context.read<AuthProvider>().user!.id;
    try {
      final value = await context
          .read<FavoriteService>()
          .toggle(userId: userId, foodId: widget.foodId);
      if (!mounted) return;
      setState(() => _isFavorite = value);
      messenger.showSnackBar(SnackBar(
        content: Text(value ? 'Disimpan ke favorit' : 'Dihapus dari favorit'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fav = _isFavorite ?? false;
    return IconButton(
      tooltip: fav ? 'Hapus dari favorit' : 'Simpan ke favorit',
      onPressed: _isFavorite == null ? null : _toggle,
      icon: Icon(fav ? Icons.favorite : Icons.favorite_border),
    );
  }
}
