/// Tabel `users` pada ERD.
///
/// Tabel ini TIDAK menyimpan email dan password. Keduanya disimpan oleh
/// Supabase Auth (tabel `auth.users`). Kolom `id` di sini sama dengan id
/// akun di Supabase Auth, sehingga satu akun = satu baris `users`.
class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    this.fullName,
    this.avatarUrl,
    this.createdAt,
  });

  final String id; // uuid, PK
  final String username; // varchar(50), unik, NN
  final String? fullName; // varchar(100)
  final String? avatarUrl; // text
  final String role; // varchar(20), NN → 'pengguna' | 'admin'
  final bool isActive; // boolean, NN
  final DateTime? createdAt; // timestamptz

  static const roleAdmin = 'admin';
  static const rolePengguna = 'pengguna';

  bool get isAdmin => role == roleAdmin;

  /// Nama yang ditampilkan di UI: nama lengkap bila ada, kalau tidak username.
  String get displayName =>
      (fullName == null || fullName!.trim().isEmpty) ? username : fullName!;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      username: map['username'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: map['role'] as String? ?? rolePengguna,
      isActive: map['is_active'] as bool? ?? true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.parse(map['created_at'] as String),
    );
  }

  /// Hanya kolom yang boleh diubah pengguna sendiri (use case "Mengubah
  /// Profil Akun"). `role` dan `is_active` diubah lewat [toAdminMap].
  Map<String, dynamic> toProfileMap() => {
        'username': username,
        'full_name': fullName,
        'avatar_url': avatarUrl,
      };

  Map<String, dynamic> toAdminMap() => {
        'role': role,
        'is_active': isActive,
      };

  AppUser copyWith({
    String? username,
    String? fullName,
    String? avatarUrl,
    String? role,
    bool? isActive,
  }) {
    return AppUser(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
