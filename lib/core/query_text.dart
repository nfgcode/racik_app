/// Menyiapkan teks dari pengguna atau dari AI sebelum dipakai di filter
/// `ilike` Supabase.
///
/// Di pola LIKE/ILIKE, `%` berarti "teks apa pun" dan `_` berarti "satu
/// karakter apa pun". Tanpa di-escape, label AI "Es_Teh" juga cocok dengan
/// "Es Teh", dan "100% Jus" cocok dengan nama apa pun yang diawali "100".
/// Postgres memakai `\` sebagai karakter escape bawaan untuk LIKE.
///
/// Catatan: PostgREST juga menganggap `*` sebagai pengganti `%`, tetapi nama
/// makanan hampir tidak pernah memuat `*`, jadi tidak ditangani di sini.
String escapeLike(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll('%', r'\%')
    .replaceAll('_', r'\_');

/// Pola "mengandung teks ini": `%<teks yang sudah di-escape>%`.
String containsPattern(String text) => '%${escapeLike(text.trim())}%';
