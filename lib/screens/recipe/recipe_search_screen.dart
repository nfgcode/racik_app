import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/food.dart';
import '../../services/food_service.dart';
import '../../widgets/food_card.dart';
import '../../widgets/state_views.dart';
import 'recipe_detail_screen.dart';

/// Use case: Mencari Resep (Guest & Pengguna).
class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;

  List<Food> _results = [];
  List<String> _categories = [];
  String? _category;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<FoodService>().categories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Filter kategori bersifat tambahan; abaikan bila gagal.
    }
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await context
          .read<FoodService>()
          .search(query: _query.text, category: _category);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Debounce: tunggu pengguna berhenti mengetik 400 ms sebelum mencari,
  /// supaya tidak mengirim satu query per huruf.
  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cari resep')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Contoh: soto, rendang, gado-gado',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _query.clear();
                          _search();
                        },
                      ),
              ),
            ),
          ),
          if (_categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final c in [null, ..._categories])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c ?? 'Semua'),
                        selected: _category == c,
                        onSelected: (_) {
                          setState(() => _category = c);
                          _search();
                        },
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _search);
    }
    if (_results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'Resep tidak ditemukan',
        message: 'Coba kata kunci lain atau pilih kategori "Semua".',
      );
    }
    return RefreshIndicator(
      onRefresh: _search,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final food = _results[index];
          return FoodCard(
            food: food,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(foodId: food.id!),
              ),
            ),
          );
        },
      ),
    );
  }
}
