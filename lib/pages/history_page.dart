import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../controller/history_controller.dart';
import '../core/formatters.dart';
import '../core/spacing.dart';
import '../enum/load_state.dart';
import '../widget/food_image.dart';
import '../widget/health_score_card.dart';
import '../widget/scan_widgets.dart';
import '../widget/state_views.dart';
import 'history_detail_page.dart';

/// Use case: Melihat Hasil Pemindaian Makanan (Pengguna).
class HistoryPage extends StatelessWidget {
  final AuthController authController;
  final HistoryController historyController;

  const HistoryPage({
    super.key,
    required this.authController,
    required this.historyController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat pindai')),
      body: ListenableBuilder(
        listenable: Listenable.merge([authController, historyController]),
        builder: (context, _) {
          if (!authController.isLoggedIn) {
            return LoginRequired(
              feature: 'melihat riwayat pindai',
              authController: authController,
            );
          }
          return _buildList(context);
        },
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final controller = historyController;
    switch (controller.loadState) {
      case LoadState.initial:
      case LoadState.loading:
        return const Center(child: CircularProgressIndicator());
      case LoadState.error:
        return ErrorState(
          message: controller.errorMessage,
          onRetry: controller.loadHistory,
        );
      case LoadState.loaded:
        if (controller.items.isEmpty) {
          return const EmptyState(
            icon: Icons.history,
            title: 'Belum ada riwayat',
            message: 'Hasil pemindaian makanan Anda akan muncul di sini.',
          );
        }
        return RefreshIndicator(
          onRefresh: controller.loadHistory,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: controller.items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final scan = controller.items[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                leading: FoodImage(url: scan.imageUrl, size: 56),
                title: Text(scan.foodName ?? 'Makanan belum terdata'),
                subtitle: Text(
                  '${Fmt.dateTime(scan.createdAt)} · '
                  '${scanStatusText(scan.scanStatus)}',
                ),
                trailing: scan.fuzzyLabel == null
                    ? null
                    : HealthScoreBadge(
                        label: scan.fuzzyLabel!,
                        score: scan.fuzzyScore,
                      ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HistoryDetailPage(
                      scan: scan,
                      historyController: controller,
                    ),
                  ),
                ),
              );
            },
          ),
        );
    }
  }
}
