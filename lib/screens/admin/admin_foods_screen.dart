import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/food.dart';
import '../../providers/auth_provider.dart';
import '../../services/food_service.dart';
import '../../widgets/food_card.dart';
import '../../widgets/state_views.dart';
import 'food_form_screen.dart';

/// Use case: Mengelola Data Resep (Admin) — daftar, verifikasi, hapus.
class AdminFoodsScreen extends StatefulWidget {
  const AdminFoodsScreen({super.key});

  @override
  State<AdminFoodsScreen> createState() => _AdminFoodsScreenState();
}

class _AdminFoodsScreenState extends State<AdminFoodsScreen> {
  late Future<List<Food>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<FoodService>().search(includeUnverified: true);
  }

  void _reload() => setState(_load);

  Future<void> _openForm([Food? food]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FoodFormScreen(foodId: food?.id)),
    );
    if (saved == true) _reload();
  }

  Future<void> _toggleVerified(Food food) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FoodService>().setVerified(
            foodId: food.id!,
            verified: !food.isVerified,
            adminId: context.read<AuthProvider>().user!.id,
          );
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(Food food) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Hapus "${food.name}"?'),
        content: const Text(
          'Nutrisi, bahan, dan langkah resep ini ikut terhapus. '
          'Riwayat pindai pengguna tetap ada tanpa tautan resep.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FoodService>().deleteFood(food.id!);
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola resep'),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () => context.read<AuthProvider>().logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // heroTag unik: AdminShell menyimpan semua tab di IndexedStack, jadi
        // dua FAB dengan tag bawaan yang sama akan bentrok saat pindah layar.
        heroTag: 'fab-resep',
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Resep baru'),
      ),
      body: FutureBuilder<List<Food>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final foods = snapshot.data!;
          if (foods.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book,
              title: 'Belum ada resep',
              message: 'Tambahkan resep pertama dengan tombol "Resep baru".',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final food in foods)
                  FoodCard(
                    food: food,
                    onTap: () => _openForm(food),
                    trailing: Column(
                      children: [
                        Tooltip(
                          message: food.isVerified
                              ? 'Terverifikasi'
                              : 'Belum diverifikasi — tidak terlihat pengguna',
                          child: Icon(
                            food.isVerified
                                ? Icons.verified
                                : Icons.pending_outlined,
                            color: food.isVerified
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Tindakan',
                          onSelected: (action) => switch (action) {
                            'verify' => _toggleVerified(food),
                            'delete' => _delete(food),
                            _ => null,
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'verify',
                              child: Text(food.isVerified
                                  ? 'Batalkan verifikasi'
                                  : 'Verifikasi'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
