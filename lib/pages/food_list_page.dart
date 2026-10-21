import 'package:flutter/material.dart';

import '../controller/food_controller.dart';
import '../enum/load_state.dart';
import '../widget/food_card.dart';
import '../widget/state_views.dart';
import 'food_detail_page.dart';

/// Use case: Mencari Resep (Guest & Pengguna).
class FoodListPage extends StatefulWidget {
  final FoodController foodController;

  const FoodListPage({super.key, required this.foodController});

  @override
  State<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends State<FoodListPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.foodController;

    return Scaffold(
      appBar: AppBar(title: const Text('Cari resep')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return Container(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _query,
                    onChanged: controller.search,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Contoh: soto, rendang, gado-gado',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _query.clear();
                                controller.search('');
                              },
                            ),
                    ),
                  ),
                ),
                if (controller.categories.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final c in [null, ...controller.categories])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c ?? 'Semua'),
                              selected: controller.selectedCategory == c,
                              onSelected: (_) => controller.selectCategory(c),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(child: _buildList(controller)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(FoodController controller) {
    switch (controller.loadState) {
      case LoadState.initial:
      case LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadState.error:
        return ErrorState(
          message: controller.errorMessage,
          onRetry: controller.loadFoods,
        );
      case LoadState.loaded:
        if (controller.allFoods.isEmpty) {
          return const EmptyState(
            icon: Icons.search_off,
            title: 'Resep tidak ditemukan',
            message: 'Coba kata kunci lain atau pilih kategori "Semua".',
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadFoods,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: controller.allFoods.length,
            itemBuilder: (context, index) {
              final food = controller.allFoods[index];
              return FoodCard(
                food: food,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FoodDetailPage(food: food),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}
