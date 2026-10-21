/// Format angka tanpa paket tambahan.
class Fmt {
  const Fmt._();

  /// 12.5 → "12,5"   12.0 → "12"
  static String number(double? value, {int decimals = 1}) {
    if (value == null) return '-';
    final fixed = value.toStringAsFixed(decimals);
    final trimmed = fixed.contains('.')
        ? fixed.replaceFirst(RegExp(r'\.?0+$'), '')
        : fixed;
    return trimmed.replaceAll('.', ',');
  }
}
