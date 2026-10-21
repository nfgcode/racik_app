import 'dart:async';

import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../enum/load_state.dart';
import '../model/food.dart';
import '../service/food_service.dart';

/// Menyimpan daftar resep, kata kunci, dan kategori yang sedang dipilih.
/// Halaman mendengarkan perubahan lewat ListenableBuilder.
class FoodController extends ChangeNotifier {
  final FoodService foodService;
  FoodController({required this.foodService});

  List<Food> _foods = [];
  List<String> _categories = [];
  String _query = '';
  String? _category;
  LoadState _loadState = LoadState.initial;
  String _errorMessage = '';
  Timer? _debounce;

  List<Food> get allFoods => _foods;
  List<String> get categories => _categories;
  String get query => _query;
  String? get selectedCategory => _category;
  LoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;

  Future<void> loadFoods() async {
    _loadState = LoadState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _foods = await foodService.getFoods(query: _query, category: _category);
      _loadState = LoadState.loaded;
    } catch (e) {
      _errorMessage = friendlyError(e);
      _loadState = LoadState.error;
    }
    notifyListeners();
  }

  /// Filter kategori bersifat tambahan, jadi kegagalannya diabaikan.
  Future<void> loadCategories() async {
    try {
      _categories = await foodService.getCategories();
      notifyListeners();
    } catch (_) {}
  }

  /// Debounce: tunggu pengguna berhenti mengetik 400 ms sebelum mencari,
  /// supaya tidak mengirim satu query per huruf.
  void search(String query) {
    _query = query;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), loadFoods);
  }

  void selectCategory(String? category) {
    _category = category;
    loadFoods();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
