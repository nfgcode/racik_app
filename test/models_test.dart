import 'package:flutter_test/flutter_test.dart';
import 'package:racik_app/ai/tflite_food_recognizer.dart';
import 'package:racik_app/models/food.dart';
import 'package:racik_app/models/scan_history.dart';

void main() {
  test('Food.fromMap membaca relasi hasil join Supabase', () {
    // Bentuk JSON persis seperti balasan
    // select('*, nutritions(*), steps(*), food_ingredients(*, ingredients(*))')
    final food = Food.fromMap({
      'id': 'f1',
      'name': 'Nasi Goreng',
      'cook_time_minutes': 20,
      'is_verified': true,
      'nutritions': {'calories': '520.00', 'sugar_g': 5, 'sodium_mg': 950.5},
      'steps': [
        {'step_order': 2, 'instruction': 'Goreng'},
        {'step_order': 1, 'instruction': 'Haluskan bumbu'},
      ],
      'food_ingredients': [
        {
          'ingredient_id': 'i1',
          'quantity': 2,
          'ingredients': {'id': 'i1', 'name': 'Telur ayam', 'unit': 'butir'},
        },
      ],
    });

    expect(food.nutrition!.calories, 520); // numeric sebagai String
    expect(food.nutrition!.sodiumMg, 950.5);
    expect(food.steps.map((s) => s.stepOrder), [1, 2]); // diurutkan
    expect(food.ingredients.single.amountLabel, '2 butir');
    expect(food.ingredients.single.ingredient!.name, 'Telur ayam');
  });

  test('nutritions sebagai list berisi satu objek juga terbaca', () {
    final food = Food.fromMap({
      'name': 'Soto Ayam',
      'nutritions': [
        {'calories': 310},
      ],
    });
    expect(food.nutrition!.calories, 310);
  });

  test('ScanHistory.fromMap membaca nama makanan dari join foods(name)', () {
    final scan = ScanHistory.fromMap({
      'id': 's1',
      'user_id': 'u1',
      'food_id': 'f1',
      'ai_confidence': '87.50',
      'scan_status': 'berhasil',
      'created_at': '2026-09-11T06:05:00+00:00',
      'foods': {'name': 'Rendang'},
    });
    expect(scan.foodName, 'Rendang');
    expect(scan.aiConfidence, 87.5);
  });

  test('label Teachable Machine dibersihkan dari nomor urut', () {
    final labels = TfliteFoodRecognizer.parseLabels(
      '0 Nasi Goreng\n1 Gado-Gado\r\n2 Soto Ayam\n\n',
    );
    expect(labels, ['Nasi Goreng', 'Gado-Gado', 'Soto Ayam']);
  });
}
