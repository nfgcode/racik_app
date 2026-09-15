import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../services/stats_service.dart';
import '../../widgets/scan_widgets.dart';
import '../../widgets/state_views.dart';

/// Use case: Melihat Statistik Pemindaian Pengguna (Admin).
class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late Future<ScanStats> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<StatsService>().load();
  }

  Future<void> _refresh() async {
    final future = context.read<StatsService>().load();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistik pemindaian')),
      body: FutureBuilder<ScanStats>(
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
          final s = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    _StatTile(label: 'Total pindai', value: '${s.totalScans}'),
                    const SizedBox(width: 12),
                    _StatTile(label: '7 hari terakhir', value: '${s.scansThisWeek}'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatTile(label: 'Pengguna', value: '${s.totalUsers}'),
                    const SizedBox(width: 12),
                    _StatTile(
                      label: 'Rata-rata keyakinan AI',
                      value: Fmt.percent(s.averageConfidence),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Pindai per hari',
                  child: _DailyBars(days: s.last7Days),
                ),
                _Section(
                  title: 'Status pindai (7 hari)',
                  child: _Breakdown(
                    counts: {
                      for (final e in s.byStatus.entries)
                        scanStatusText(e.key): e.value,
                    },
                  ),
                ),
                _Section(
                  title: 'Skor kesehatan (7 hari)',
                  child: _Breakdown(
                    counts: s.byLabel,
                    colorOf: (label) => HealthStyle.of(label).color,
                  ),
                ),
                _Section(
                  title: 'Paling sering dipindai',
                  child: s.topFoods.isEmpty
                      ? const Text('Belum ada data.')
                      : Column(
                          children: [
                            for (final (i, food) in s.topFoods.indexed)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(child: Text('${i + 1}')),
                                title: Text(food.name),
                                subtitle: food.category == null
                                    ? null
                                    : Text(food.category!),
                                trailing: Text('${food.scanCount}×'),
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

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: textTheme.headlineMedium),
                Text(label, style: textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Diagram batang sederhana tanpa paket grafik: tinggi batang =
/// jumlah pindai hari itu dibagi jumlah tertinggi minggu ini.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.days});

  final List<DailyCount> days;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = days.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    const barArea = 120.0;

    return SizedBox(
      height: barArea + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                label: '${Fmt.shortDate(d.day)}: ${d.count} pindai',
                excludeSemantics: true,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${d.count}', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      height: max == 0 ? 2 : 2 + (barArea - 2) * d.count / max,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Fmt.shortDate(d.day).split(' ').first,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Daftar "label → jumlah" dengan batang proporsional.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.counts, this.colorOf});

  final Map<String, int> counts;
  final Color Function(String label)? colorOf;

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const Text('Belum ada data.');
    final total = counts.values.fold(0, (a, b) => a + b);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (final e in entries)
          MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 120, child: Text(e.key)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: e.value / total,
                        minHeight: 10,
                        color: colorOf?.call(e.key),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text('${e.value}', textAlign: TextAlign.end),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
