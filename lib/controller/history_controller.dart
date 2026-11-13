import 'package:flutter/material.dart';

import '../core/errors.dart';
import '../enum/load_state.dart';
import '../model/food.dart';
import '../model/scan_history.dart';
import '../service/food_service.dart';
import '../service/scan_service.dart';

/// Riwayat pindai milik pengguna yang sedang login.
class HistoryController extends ChangeNotifier {
  final ScanService scanService;
  final FoodService foodService;
  HistoryController({required this.scanService, required this.foodService});

  String? _userId;
  List<ScanHistory> _items = [];
  LoadState _loadState = LoadState.initial;
  String _errorMessage = '';

  List<ScanHistory> get items => _items;
  LoadState get loadState => _loadState;
  String get errorMessage => _errorMessage;

  /// Dipanggil setiap kali pengguna berganti (login, logout, ganti akun).
  void setUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _items = [];
    _loadState = LoadState.initial;
    notifyListeners();
    if (userId != null) loadHistory();
  }

  Future<void> loadHistory() async {
    final userId = _userId;
    if (userId == null) return;
    _loadState = LoadState.loading;
    _errorMessage = '';
    notifyListeners();

    try {
      _items = await scanService.getHistory(userId);
      _loadState = LoadState.loaded;
    } catch (e) {
      _errorMessage = friendlyError(e);
      _loadState = LoadState.error;
    }
    notifyListeners();
  }

  /// Menghapus satu riwayat. Melempar exception bila gagal, supaya halaman
  /// bisa menampilkan pesannya.
  Future<void> delete(ScanHistory scan) async {
    await scanService.delete(scan.id!);
    _items = _items.where((s) => s.id != scan.id).toList();
    notifyListeners();
  }

  /// Resep lengkap untuk detail riwayat. Skor yang ditampilkan tetap skor
  /// saat dipindai (tersimpan di scan_history).
  Future<Food?> getFood(String foodId) => foodService.getById(foodId);
}
