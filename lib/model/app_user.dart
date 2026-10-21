/// Tabel `users` pada ERD.
///
/// Tabel ini TIDAK menyimpan email dan password. Keduanya disimpan oleh
/// Supabase Auth (tabel `auth.users`). Kolom `id` di sini sama dengan id
/// akun di Supabase Auth, sehingga satu akun = satu baris `users`.
class AppUser {
  AppUser({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
  });

  final String id; // uuid, PK
  final String username; // varchar(50), unik
  final String? fullName; // varchar(100)
  final String? avatarUrl; // text

  /// Nama yang ditampilkan di UI: nama lengkap bila ada, kalau tidak username.
  String get displayName =>
      (fullName == null || fullName!.trim().isEmpty) ? username : fullName!;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    username: json['username'] as String,
    fullName: json['full_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
  );
}
