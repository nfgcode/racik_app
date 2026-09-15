import '../models/nutrition.dart';

/// Derajat keanggotaan satu variabel input, mis. Gula = 14 g →
/// {rendah: 0.0, sedang: 0.85, tinggi: 0.15}.
class FuzzyInput {
  const FuzzyInput({
    required this.name,
    required this.unit,
    required this.value,
    required this.degrees,
    this.isMissing = false,
  });

  final String name;
  final String unit;
  final double value;
  final Map<String, double> degrees;

  /// true bila kolomnya kosong di tabel `nutritions` (dianggap 0).
  final bool isMissing;

  /// Himpunan dengan derajat tertinggi, untuk ringkasan di UI.
  String get dominantSet =>
      degrees.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Satu aturan yang "menyala" (α > 0).
class FuzzyRuleFiring {
  const FuzzyRuleFiring({
    required this.antecedent,
    required this.alpha,
    required this.z,
  });

  /// Contoh: {'Gula': 'rendah', 'Lemak': 'sedang', ...}
  final Map<String, String> antecedent;

  /// Kekuatan aturan = min(derajat semua syarat).
  final double alpha;

  /// Nilai keluaran aturan (konstanta Sugeno orde-nol).
  final double z;

  String get description {
    final syarat = antecedent.entries
        .map((e) => '${e.key} ${e.value}')
        .join(' DAN ');
    return 'JIKA $syarat MAKA skor ${z.toStringAsFixed(0)}';
  }
}

/// Keluaran logika fuzzy: disimpan ke `scan_history.fuzzy_score`
/// dan `scan_history.fuzzy_label`.
class HealthScoreResult {
  const HealthScoreResult({
    required this.score,
    required this.label,
    required this.inputs,
    required this.firedRules,
  });

  final double score; // 0..100
  final String label; // 'Sehat' | 'Cukup Sehat' | 'Kurang Sehat'
  final List<FuzzyInput> inputs;
  final List<FuzzyRuleFiring> firedRules; // urut dari α terbesar

  bool get hasMissingData => inputs.any((i) => i.isMissing);
}

/// Skor kesehatan makanan dengan logika fuzzy metode Sugeno orde-nol.
///
/// Langkah:
///   1. Fuzzifikasi   : ubah angka nutrisi → derajat keanggotaan (0..1).
///   2. Inferensi     : setiap aturan diberi α = min(derajat syaratnya).
///   3. Defuzzifikasi : skor = Σ(α·z) / Σα  (rata-rata terbobot).
///
/// Batas himpunan di bawah adalah CONTOH untuk nilai per porsi.
/// Sesuaikan dengan rancangan fuzzy tim dan sumber gizi yang dipakai
/// (mis. Tabel Komposisi Pangan Indonesia / anjuran Kemenkes).
class FuzzyHealthScore {
  const FuzzyHealthScore._();

  // Titik a–b–c untuk tiga himpunan: rendah turun a→b, sedang puncak di b,
  // tinggi naik b→c. Susunan ini membuat jumlah derajat di setiap titik = 1.
  static const gula = FuzzyVariable('Gula', 'g', 5, 12, 25);
  static const lemak = FuzzyVariable('Lemak', 'g', 5, 12, 21);
  static const natrium = FuzzyVariable('Natrium', 'mg', 300, 600, 1000);

  // Serat hanya dua himpunan: rendah turun 2→5, tinggi naik 2→5.
  static const seratA = 2.0;
  static const seratB = 5.0;

  // Konsekuen aturan: skor dasar dikurangi penalti tiap zat,
  // ditambah bonus bila serat tinggi.
  static const skorDasar = 90.0;
  static const penalti = {'rendah': 0.0, 'sedang': 10.0, 'tinggi': 30.0};
  static const bonusSerat = 10.0;

  static const batasSehat = 75.0;
  static const batasCukupSehat = 50.0;

  static HealthScoreResult evaluate(Nutrition n) {
    // 1. Fuzzifikasi
    final inputs = [
      gula.fuzzify(n.sugarG),
      lemak.fuzzify(n.fatG),
      natrium.fuzzify(n.sodiumMg),
      _fuzzifySerat(n.fiberG),
    ];

    // 2. Inferensi — 3 × 3 × 3 × 2 = 54 aturan, dibentuk dengan perulangan
    // agar tidak ada kombinasi yang terlewat.
    final fired = <FuzzyRuleFiring>[];
    for (final g in inputs[0].degrees.entries) {
      for (final l in inputs[1].degrees.entries) {
        for (final s in inputs[2].degrees.entries) {
          for (final f in inputs[3].degrees.entries) {
            final alpha = [g.value, l.value, s.value, f.value]
                .reduce((a, b) => a < b ? a : b);
            if (alpha <= 0) continue;

            var z = skorDasar -
                penalti[g.key]! -
                penalti[l.key]! -
                penalti[s.key]!;
            if (f.key == 'tinggi') z += bonusSerat;

            fired.add(FuzzyRuleFiring(
              antecedent: {
                'Gula': g.key,
                'Lemak': l.key,
                'Natrium': s.key,
                'Serat': f.key,
              },
              alpha: alpha,
              z: z.clamp(0, 100).toDouble(),
            ));
          }
        }
      }
    }

    // 3. Defuzzifikasi (weighted average)
    var sumAlphaZ = 0.0;
    var sumAlpha = 0.0;
    for (final r in fired) {
      sumAlphaZ += r.alpha * r.z;
      sumAlpha += r.alpha;
    }
    final score = sumAlpha == 0 ? 0.0 : sumAlphaZ / sumAlpha;

    fired.sort((a, b) => b.alpha.compareTo(a.alpha));
    return HealthScoreResult(
      score: double.parse(score.toStringAsFixed(2)), // numeric(5,2)
      label: labelFor(score),
      inputs: inputs,
      firedRules: fired,
    );
  }

  static String labelFor(double score) {
    if (score >= batasSehat) return 'Sehat';
    if (score >= batasCukupSehat) return 'Cukup Sehat';
    return 'Kurang Sehat';
  }

  static FuzzyInput _fuzzifySerat(double? value) {
    final x = value ?? 0;
    return FuzzyInput(
      name: 'Serat',
      unit: 'g',
      value: x,
      isMissing: value == null,
      degrees: {
        'rendah': Membership.down(x, seratA, seratB),
        'tinggi': Membership.up(x, seratA, seratB),
      },
    );
  }
}

/// Fungsi keanggotaan linear yang dipakai di atas.
class Membership {
  const Membership._();

  /// Bahu kiri: 1 saat x ≤ a, turun lurus ke 0 saat x ≥ b.
  static double down(double x, double a, double b) {
    if (x <= a) return 1;
    if (x >= b) return 0;
    return (b - x) / (b - a);
  }

  /// Bahu kanan: 0 saat x ≤ a, naik lurus ke 1 saat x ≥ b.
  static double up(double x, double a, double b) {
    if (x <= a) return 0;
    if (x >= b) return 1;
    return (x - a) / (b - a);
  }

  /// Segitiga: 0 di a, puncak 1 di b, kembali 0 di c.
  static double triangle(double x, double a, double b, double c) {
    if (x <= a || x >= c) return 0;
    if (x <= b) return (x - a) / (b - a);
    return (c - x) / (c - b);
  }
}

/// Variabel input dengan tiga himpunan: rendah, sedang, tinggi.
class FuzzyVariable {
  const FuzzyVariable(this.name, this.unit, this.a, this.b, this.c);

  final String name;
  final String unit;
  final double a;
  final double b;
  final double c;

  FuzzyInput fuzzify(double? value) {
    final x = value ?? 0;
    return FuzzyInput(
      name: name,
      unit: unit,
      value: x,
      isMissing: value == null,
      degrees: {
        'rendah': Membership.down(x, a, b),
        'sedang': Membership.triangle(x, a, b, c),
        'tinggi': Membership.up(x, b, c),
      },
    );
  }
}
