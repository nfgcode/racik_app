/// Kredit foto resep contoh. Fotonya dari Wikimedia Commons dengan lisensi
/// Creative Commons, yang mewajibkan nama pembuat dan lisensi dicantumkan.
/// Rincian lengkap: supabase/gambar-resep/KREDIT.md
class PhotoCredit {
  const PhotoCredit(this.author, this.license);

  final String author;
  final String license;

  String get caption => 'Foto: $author · $license · Wikimedia Commons';
}

/// Nama file di Storage `food-images/resep/` → kreditnya.
const sampleRecipePhotoCredits = {
  'nasi-goreng.jpg': PhotoCredit('shankar s.', 'CC BY 2.0'),
  'gado-gado.jpg': PhotoCredit('Piknikdong', 'CC BY-SA 4.0'),
  'soto-ayam.jpg': PhotoCredit('Sakurai Midori', 'CC BY-SA 3.0'),
  'rendang.jpg': PhotoCredit('Midori', 'CC BY 3.0'),
  'pisang-goreng.jpg': PhotoCredit('Iloveporotta', 'CC BY-SA 4.0'),
  'sayur-bening-bayam.jpg': PhotoCredit('Midori', 'CC BY 3.0'),
};

/// Kredit untuk [imageUrl] bila itu foto resep contoh, selain itu null
/// (misalnya foto yang diunggah admin sendiri).
PhotoCredit? photoCreditFor(String? imageUrl) {
  if (imageUrl == null) return null;
  const folder = '/food-images/resep/';
  final i = imageUrl.indexOf(folder);
  if (i < 0) return null;
  return sampleRecipePhotoCredits[imageUrl.substring(i + folder.length)];
}
