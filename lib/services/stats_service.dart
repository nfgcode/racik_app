import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/food.dart';

class DailyCount {
  const DailyCount(this.day, this.count);

  final DateTime day;
  final int count;
}

class ScanStats {
  const ScanStats({
    required this.totalScans,
    required this.totalUsers,
    required this.last7Days,
    required this.byStatus,
    required this.byLabel,
    required this.averageConfidence,
    required this.topFoods,
  });

  final int totalScans;
  final int totalUsers;
  final List<DailyCount> last7Days;
  final Map<String, int> byStatus;
  final Map<String, int> byLabel;
  final double? averageConfidence; // 0..100
  final List<Food> topFoods;

  int get scansThisWeek => last7Days.fold(0, (sum, d) => sum + d.count);
}

/// Use case: Melihat Statistik Pemindaian Pengguna (Admin).
///
/// Data 7 hari terakhir diambil mentah lalu dihitung di Dart. Untuk data
/// besar, pindahkan agregasi ke VIEW atau fungsi SQL.
class StatsService {
  StatsService(this._client);

  final SupabaseClient _client;

  Future<ScanStats> load() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));

    // Empat query berjalan bersamaan, bukan bergantian.
    final results = await Future.wait<Object>([
      _client.from('scan_history').count(),
      _client.from('users').count(),
      _client
          .from('scan_history')
          .select('created_at, scan_status, fuzzy_label, ai_confidence')
          .gte('created_at', start.toUtc().toIso8601String()),
      _client
          .from('foods')
          .select('id, name, category, scan_count')
          .gt('scan_count', 0)
          .order('scan_count', ascending: false)
          .limit(5),
    ]);

    return summarize(
      totalScans: results[0] as int,
      totalUsers: results[1] as int,
      recent: results[2] as List<Map<String, dynamic>>,
      topFoods: (results[3] as List<Map<String, dynamic>>)
          .map(Food.fromMap)
          .toList(),
      today: today,
    );
  }

  /// Mengolah baris mentah 7 hari terakhir menjadi ringkasan. Dipisah dari
  /// [load] supaya bisa dites tanpa Supabase.
  ///
  /// Kolom `scan_status` dan `created_at` boleh kosong di database, jadi
  /// keduanya ditangani: status kosong dihitung sebagai `tidak_diketahui`,
  /// baris tanpa tanggal tidak masuk hitungan per hari.
  static ScanStats summarize({
    required int totalScans,
    required int totalUsers,
    required List<Map<String, dynamic>> recent,
    required List<Food> topFoods,
    required DateTime today,
  }) {
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));
    final perDay = {for (final d in days) d: 0};
    final byStatus = <String, int>{};
    final byLabel = <String, int>{};
    var confidenceSum = 0.0;
    var confidenceCount = 0;

    for (final row in recent) {
      final createdRaw = row['created_at'] as String?;
      if (createdRaw != null) {
        final created = DateTime.parse(createdRaw).toLocal();
        final day = DateTime(created.year, created.month, created.day);
        if (perDay.containsKey(day)) perDay[day] = perDay[day]! + 1;
      }

      final status = row['scan_status'] as String? ?? 'tidak_diketahui';
      byStatus[status] = (byStatus[status] ?? 0) + 1;

      final label = row['fuzzy_label'] as String?;
      if (label != null) byLabel[label] = (byLabel[label] ?? 0) + 1;

      final confidence = double.tryParse(row['ai_confidence']?.toString() ?? '');
      if (confidence != null) {
        confidenceSum += confidence;
        confidenceCount++;
      }
    }

    return ScanStats(
      totalScans: totalScans,
      totalUsers: totalUsers,
      last7Days: [for (final d in days) DailyCount(d, perDay[d]!)],
      byStatus: byStatus,
      byLabel: byLabel,
      averageConfidence:
          confidenceCount == 0 ? null : confidenceSum / confidenceCount,
      topFoods: topFoods,
    );
  }
}
