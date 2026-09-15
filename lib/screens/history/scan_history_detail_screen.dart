import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/fuzzy_health_score.dart';
import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../models/food.dart';
import '../../models/scan_history.dart';
import '../../services/food_service.dart';
import '../../services/scan_service.dart';
import '../../widgets/food_image.dart';
import '../../widgets/health_score_card.dart';
import '../../widgets/nutrition_card.dart';
import '../../widgets/scan_widgets.dart';
import '../recipe/recipe_detail_screen.dart';

/// Detail satu riwayat pindai. Memakai ulang widget yang sama dengan
/// layar hasil pindai (ScanHeader, HealthScoreCard, NutritionCard).
/// Mengembalikan `true` lewat Navigator.pop bila riwayat dihapus.
class ScanHistoryDetailScreen extends StatefulWidget {
  const ScanHistoryDetailScreen({super.key, required this.scan});

  final ScanHistory scan;

  @override
  State<ScanHistoryDetailScreen> createState() =>
      _ScanHistoryDetailScreenState();
}

class _ScanHistoryDetailScreenState extends State<ScanHistoryDetailScreen> {
  Future<Food?>? _food;

  @override
  void initState() {
    super.initState();
    final foodId = widget.scan.foodId;
    if (foodId != null) _food = context.read<FoodService>().getDetail(foodId);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus riwayat ini?'),
        content: const Text('Foto dan skor dari pindaian ini akan dihapus.'),
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
    final navigator = Navigator.of(context);
    try {
      await context.read<ScanService>().delete(widget.scan.id!);
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(Fmt.dateTime(scan.createdAt)),
        actions: [
          IconButton(
            tooltip: 'Hapus riwayat',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: FoodImage(url: scan.imageUrl, borderRadius: 16),
          ),
          const SizedBox(height: 16),
          ScanHeader(
            foodName: scan.foodName ?? 'Makanan belum terdata',
            confidencePercent: scan.aiConfidence ?? 0,
          ),
          const SizedBox(height: 12),
          ScanStatusBanner(
            status: scan.scanStatus,
            label: scan.foodName ?? 'Makanan ini',
          ),
          const SizedBox(height: 16),
          if (_food != null)
            FutureBuilder<Food?>(
              future: _food,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final food = snapshot.data;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Skor yang ditampilkan adalah skor saat dipindai
                    // (tersimpan di scan_history). Rinciannya dihitung ulang
                    // dari data nutrisi resep saat ini.
                    if (scan.fuzzyScore != null && scan.fuzzyLabel != null)
                      HealthScoreCard(
                        score: scan.fuzzyScore!,
                        label: scan.fuzzyLabel!,
                        result: food?.nutrition == null
                            ? null
                            : FuzzyHealthScore.evaluate(food!.nutrition!),
                      ),
                    if (food != null && food.nutrition != null)
                      NutritionCard(
                        nutrition: food.nutrition!,
                        servingSize: food.servingSize,
                      ),
                    if (food != null && food.id != null) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RecipeDetailScreen(foodId: food.id!),
                          ),
                        ),
                        icon: const Icon(Icons.menu_book),
                        label: const Text('Lihat resep lengkap'),
                      ),
                    ],
                    if (food == null)
                      Text(
                        'Resep untuk pindaian ini sudah tidak tersedia.',
                        style: textTheme.bodyMedium,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
