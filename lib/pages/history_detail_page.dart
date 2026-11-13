import 'package:flutter/material.dart';

import '../ai/fuzzy_health_score.dart';
import '../controller/history_controller.dart';
import '../core/errors.dart';
import '../core/formatters.dart';
import '../core/spacing.dart';
import '../model/food.dart';
import '../model/scan_history.dart';
import '../widget/food_image.dart';
import '../widget/health_score_card.dart';
import '../widget/nutrition_card.dart';
import '../widget/scan_widgets.dart';
import 'food_detail_page.dart';

/// Detail satu riwayat pindai. Memakai ulang widget yang sama dengan halaman
/// hasil pindai (ScanHeader, HealthScoreCard, NutritionCard).
class HistoryDetailPage extends StatefulWidget {
  final ScanHistory scan;
  final HistoryController historyController;

  const HistoryDetailPage({
    super.key,
    required this.scan,
    required this.historyController,
  });

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  Future<Food?>? _food;

  @override
  void initState() {
    super.initState();
    // Future disimpan di State, bukan dibuat di build().
    final foodId = widget.scan.foodId;
    if (foodId != null) _food = widget.historyController.getFood(foodId);
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
      await widget.historyController.delete(widget.scan);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Riwayat dihapus')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;

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
        padding: AppSpacing.page,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: FoodImage(url: scan.imageUrl, borderRadius: 16),
          ),
          const SizedBox(height: AppSpacing.lg),
          ScanHeader(
            foodName: scan.foodName ?? 'Makanan belum terdata',
            confidencePercent: scan.aiConfidence ?? 0,
          ),
          const SizedBox(height: AppSpacing.md),
          ScanStatusBanner(
            status: scan.scanStatus,
            label: scan.foodName ?? 'Makanan ini',
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_food == null &&
              scan.fuzzyScore != null &&
              scan.fuzzyLabel != null)
            HealthScoreCard(score: scan.fuzzyScore!, label: scan.fuzzyLabel!),
          if (_food != null)
            FutureBuilder<Food?>(
              future: _food,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _FoodSection(scan: scan, food: snapshot.data);
              },
            ),
        ],
      ),
    );
  }
}

class _FoodSection extends StatelessWidget {
  const _FoodSection({required this.scan, required this.food});

  final ScanHistory scan;
  final Food? food;

  @override
  Widget build(BuildContext context) {
    final food = this.food;
    final nutrition = food?.nutrition;
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Skor yang ditampilkan adalah skor saat dipindai. Rinciannya
          // dihitung ulang dari data nutrisi resep saat ini.
          if (scan.fuzzyScore != null && scan.fuzzyLabel != null)
            HealthScoreCard(
              score: scan.fuzzyScore!,
              label: scan.fuzzyLabel!,
              result: nutrition == null
                  ? null
                  : FuzzyHealthScore.evaluate(nutrition),
            ),
          if (food != null && nutrition != null)
            NutritionCard(nutrition: nutrition, servingSize: food.servingSize),
          if (food != null) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FoodDetailPage(food: food)),
              ),
              icon: const Icon(Icons.menu_book),
              label: const Text('Lihat resep lengkap'),
            ),
          ] else
            Text(
              'Resep untuk pindaian ini sudah tidak tersedia.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }
}
