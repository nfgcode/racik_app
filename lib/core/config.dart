/// Konfigurasi aplikasi.
///
/// URL dan key Supabase TIDAK ditulis langsung di kode. Keduanya dibaca dari
/// `--dart-define` saat menjalankan aplikasi:
///
///   flutter run --dart-define-from-file=env.json
///
/// Contoh isi env.json ada di env.example.json.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// Publishable key (dulu disebut anon key). Aman dipakai di aplikasi
  /// karena akses data tetap dibatasi Row Level Security di database.
  /// JANGAN pernah memasukkan secret / service_role key ke aplikasi.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  /// Kunci API OpenRouter untuk model Vision pengenal makanan.
  static const openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');

  /// Model Vision OpenRouter yang dipakai (default: Qwen 2.5 VL 72B Instruct).
  static const openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'qwen/qwen-2.5-vl-72b-instruct',
  );

  static bool get isOpenRouterConfigured => openRouterApiKey.isNotEmpty;

  /// Di bawah angka ini hasil AI dianggap "tidak yakin".
  static const confidenceThreshold = 0.60;

  // Nama bucket di Supabase Storage (dibuat oleh supabase/schema.sql).
  static const scanBucket = 'scan-images';
  static const foodBucket = 'food-images';
  static const avatarBucket = 'avatars';
}
