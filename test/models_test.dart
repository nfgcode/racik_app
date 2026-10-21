import 'package:flutter_test/flutter_test.dart';
import 'package:racik_app/model/app_user.dart';
import 'package:racik_app/model/food.dart';

void main() {
  test('Food.fromJson membaca relasi hasil join Supabase', () {
    // Bentuk JSON persis seperti balasan
    // select('*, nutritions(*), steps(*), food_ingredients(*, ingredients(*))')
    final food = Food.fromJson({
      'id': 'f1',
      'name': 'Nasi Goreng',
      'cook_time_minutes': 20,
      'nutritions': {'calories': '520.00', 'sugar_g': 5, 'sodium_mg': 950.5},
      'steps': [
        {'step_order': 2, 'instruction': 'Goreng'},
        {'step_order': 1, 'instruction': 'Haluskan bumbu'},
      ],
      'food_ingredients': [
        {
          'quantity': 2,
          'ingredients': {'name': 'Telur ayam', 'unit': 'butir'},
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
    final food = Food.fromJson({
      'id': 'f2',
      'name': 'Soto Ayam',
      'nutritions': [
        {'calories': 310},
      ],
    });
    expect(food.nutrition!.calories, 310);
  });

  test('AppUser.displayName memakai username bila nama lengkap kosong', () {
    final user = AppUser.fromJson({
      'id': 'u1',
      'username': 'racik',
      'full_name': ' ',
    });
    expect(user.displayName, 'racik');
  });
}
