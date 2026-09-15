import 'package:flutter_test/flutter_test.dart';
import 'package:racik_app/ai/fuzzy_health_score.dart';
import 'package:racik_app/models/nutrition.dart';

void main() {
  group('Membership', () {
    test('tiga himpunan selalu berjumlah 1 (partisi lengkap)', () {
      const v = FuzzyHealthScore.gula;
      for (var x = 0.0; x <= 40; x += 0.5) {
        final d = v.fuzzify(x).degrees;
        final sum = d['rendah']! + d['sedang']! + d['tinggi']!;
        expect(sum, closeTo(1, 1e-9), reason: 'gula = $x');
      }
    });

    test('titik-titik kunci gula', () {
      const v = FuzzyHealthScore.gula;
      expect(v.fuzzify(5).degrees['rendah'], 1);
      expect(v.fuzzify(12).degrees['sedang'], 1);
      expect(v.fuzzify(25).degrees['tinggi'], 1);
    });
  });

  group('FuzzyHealthScore.evaluate', () {
    test('semua zat rendah + serat tinggi → Sehat', () {
      final r = FuzzyHealthScore.evaluate(const Nutrition(
        calories: 60, sugarG: 2, fatG: 1, sodiumMg: 100, fiberG: 6,
      ));
      expect(r.score, 100);
      expect(r.label, 'Sehat');
    });

    test('gula, lemak, dan natrium tinggi → Kurang Sehat', () {
      final r = FuzzyHealthScore.evaluate(const Nutrition(
        calories: 800, sugarG: 30, fatG: 30, sodiumMg: 1500, fiberG: 0,
      ));
      expect(r.score, 0);
      expect(r.label, 'Kurang Sehat');
    });

    test('menambah gula tidak pernah menaikkan skor', () {
      double scoreAt(double sugar) => FuzzyHealthScore.evaluate(Nutrition(
            calories: 300, sugarG: sugar, fatG: 10, sodiumMg: 500, fiberG: 3,
          )).score;
      var previous = scoreAt(0);
      for (var sugar = 1.0; sugar <= 40; sugar++) {
        final current = scoreAt(sugar);
        expect(current, lessThanOrEqualTo(previous + 1e-9));
        previous = current;
      }
    });

    test('kolom kosong ditandai hasMissingData', () {
      final r = FuzzyHealthScore.evaluate(const Nutrition(calories: 100));
      expect(r.hasMissingData, isTrue);
    });

    // Contoh hitungan yang dipakai di dokumen belajar (data seed.sql).
    test('contoh Gado-Gado', () {
      final r = FuzzyHealthScore.evaluate(const Nutrition(
        calories: 380, sugarG: 9, fatG: 20, sodiumMg: 600, fiberG: 7,
      ));
      expect(r.firedRules.length, 4);
      expect(r.score, closeTo(58.05, 0.01));
      expect(r.label, 'Cukup Sehat');
    });

    test('label untuk seluruh data seed', () {
      final seed = {
        'Nasi Goreng': const Nutrition(calories: 520, sugarG: 5, fatG: 18, sodiumMg: 950, fiberG: 2.5),
        'Gado-Gado': const Nutrition(calories: 380, sugarG: 9, fatG: 20, sodiumMg: 600, fiberG: 7),
        'Soto Ayam': const Nutrition(calories: 310, sugarG: 3, fatG: 12, sodiumMg: 1100, fiberG: 2),
        'Rendang': const Nutrition(calories: 470, sugarG: 4, fatG: 37, sodiumMg: 800, fiberG: 2),
        'Pisang Goreng': const Nutrition(calories: 330, sugarG: 18, fatG: 16, sodiumMg: 150, fiberG: 3),
        'Sayur Bening Bayam': const Nutrition(calories: 60, sugarG: 2, fatG: 1, sodiumMg: 350, fiberG: 3),
      };
      final labels = {
        for (final e in seed.entries)
          e.key: FuzzyHealthScore.evaluate(e.value).label,
      };
      expect(labels, {
        'Nasi Goreng': 'Kurang Sehat',
        'Gado-Gado': 'Cukup Sehat',
        'Soto Ayam': 'Cukup Sehat',
        'Rendang': 'Kurang Sehat',
        'Pisang Goreng': 'Cukup Sehat',
        'Sayur Bening Bayam': 'Sehat',
      });
    });
  });
}
