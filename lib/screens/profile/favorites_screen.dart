import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/food.dart';
import '../../providers/auth_provider.dart';
import '../../services/favorite_service.dart';
import '../../widgets/food_card.dart';
import '../../widgets/state_views.dart';
import '../recipe/recipe_detail_screen.dart';

/// Daftar resep favorit (tabel `favorites`).
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<Food>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = context.read<AuthProvider>().user!.id;
    _future = context.read<FavoriteService>().listOf(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resep favorit')),
      body: FutureBuilder<List<Food>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: () => setState(_load),
            );
          }
          final foods = snapshot.data!;
          if (foods.isEmpty) {
            return const EmptyState(
              icon: Icons.favorite_border,
              title: 'Belum ada favorit',
              message: 'Ketuk ikon hati di halaman resep untuk menyimpannya.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final food in foods)
                FoodCard(
                  food: food,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(foodId: food.id!),
                      ),
                    );
                    // Muat ulang: bisa jadi favoritnya baru saja dihapus.
                    if (mounted) setState(_load);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
