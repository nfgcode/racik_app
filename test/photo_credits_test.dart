import 'package:flutter_test/flutter_test.dart';
import 'package:racik_app/core/photo_credits.dart';

void main() {
  const base = 'https://abcd.supabase.co/storage/v1/object/public/food-images';

  test('foto resep contoh mendapat kredit', () {
    final credit = photoCreditFor('$base/resep/rendang.jpg');
    expect(credit?.caption, 'Foto: Midori · CC BY 3.0 · Wikimedia Commons');
  });

  test('foto unggahan admin dan URL kosong tidak diberi kredit', () {
    expect(photoCreditFor('$base/foods/1726040000000.jpg'), isNull);
    expect(photoCreditFor('$base/resep/foto-lain.jpg'), isNull);
    expect(photoCreditFor(null), isNull);
  });

  test('setiap file di foto-resep-contoh.sql punya kredit', () {
    for (final file in [
      'nasi-goreng.jpg',
      'gado-gado.jpg',
      'soto-ayam.jpg',
      'rendang.jpg',
      'pisang-goreng.jpg',
      'sayur-bening-bayam.jpg',
    ]) {
      expect(sampleRecipePhotoCredits[file], isNotNull, reason: file);
    }
  });
}
