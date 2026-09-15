/// Format tanggal dan angka tanpa paket tambahan.
class Fmt {
  const Fmt._();

  static const _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// 11 Sep 2026, 13.05
  static String dateTime(DateTime? value) {
    if (value == null) return '-';
    final d = value.toLocal();
    final jam = d.hour.toString().padLeft(2, '0');
    final menit = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${_bulan[d.month - 1]} ${d.year}, $jam.$menit';
  }

  static String shortDate(DateTime d) => '${d.day} ${_bulan[d.month - 1]}';

  /// 12.5 → "12,5"   12.0 → "12"
  static String number(double? value, {int decimals = 1}) {
    if (value == null) return '-';
    final fixed = value.toStringAsFixed(decimals);
    final trimmed = fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
    return trimmed.replaceAll('.', ',');
  }

  static String percent(double? value) =>
      value == null ? '-' : '${value.toStringAsFixed(0)}%';
}
