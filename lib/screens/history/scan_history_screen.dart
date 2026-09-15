import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../models/scan_history.dart';
import '../../providers/auth_provider.dart';
import '../../services/scan_service.dart';
import '../../widgets/food_image.dart';
import '../../widgets/health_score_card.dart';
import '../../widgets/scan_widgets.dart';
import '../../widgets/state_views.dart';
import 'scan_history_detail_screen.dart';

/// Use case: Melihat Hasil Pemindaian Makanan (Pengguna).
class ScanHistoryScreen extends StatefulWidget {
  const ScanHistoryScreen({super.key});

  @override
  State<ScanHistoryScreen> createState() => _ScanHistoryScreenState();
}

class _ScanHistoryScreenState extends State<ScanHistoryScreen> {
  String? _loadedFor; // id pengguna pemilik riwayat yang sedang ditampilkan
  Future<List<ScanHistory>>? _future;

  Future<void> _refresh() async {
    final userId = context.read<AuthProvider>().user!.id;
    final future = context.read<ScanService>().historyOf(userId);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    // context.select: hanya bereaksi bila id pengguna berubah (tamu → login,
    // atau ganti akun), bukan pada setiap perubahan lain di AuthProvider.
    // select hanya boleh dipanggil di dalam build().
    final userId = context.select<AuthProvider, String?>((a) => a.user?.id);
    if (userId != _loadedFor) {
      // Query dikirim HANYA saat pengguna berganti, bukan di setiap build.
      _loadedFor = userId;
      _future = userId == null
          ? null
          : context.read<ScanService>().historyOf(userId);
    }

    if (_future == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Riwayat pindai')),
        body: const LoginRequired(feature: 'melihat riwayat pindai'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat pindai')),
      body: FutureBuilder<List<ScanHistory>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _refresh,
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.history,
              title: 'Belum ada riwayat',
              message: 'Hasil pindai Anda akan muncul di sini.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final scan = items[index];
                return ListTile(
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
                  onTap: () async {
                    final deleted = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ScanHistoryDetailScreen(scan: scan),
                      ),
                    );
                    if (deleted == true) _refresh();
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
