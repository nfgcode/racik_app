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
}
