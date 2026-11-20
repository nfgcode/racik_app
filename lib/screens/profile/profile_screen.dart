import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/state_views.dart';
import 'edit_profile_screen.dart';
import 'favorites_screen.dart';

/// Tab Profil — pintu ke use case Mengubah Profil Akun dan Logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: const LoginRequired(feature: 'membuka profil'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(child: UserAvatar(user: user, radius: 48)),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          Text(
            '@${user.username} · ${auth.email ?? ''}',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Ubah profil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfileScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('Resep favorit'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FavoritesScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () {
              final auth = context.read<AuthProvider>();
              // Admin membuka layar ini lewat menu akun (di atas AdminShell),
              // jadi tutup dulu supaya setelah keluar langsung ke layar tamu.
              Navigator.of(context).popUntil((route) => route.isFirst);
              auth.logout();
            },
          ),
          // Admin tidak menghapus akunnya dari aplikasi supaya Racik tidak
          // kehilangan satu-satunya admin. Perannya diturunkan dulu oleh
          // admin lain, atau minta hapus lewat halaman web hapus akun.
          if (user.isAdmin)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Hapus akun'),
              subtitle: Text(
                'Akun admin tidak bisa dihapus dari aplikasi. Minta admin lain '
                'mengubah peranmu menjadi pengguna dulu.',
              ),
            )
          else
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Hapus akun',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _confirmDelete(context),
            ),
        ],
      ),
    );
  }

  /// Use case: Hapus akun (syarat Google Play), dengan konfirmasi dulu.
  Future<void> _confirmDelete(BuildContext context) async {
    // Ambil dependensi dari context SEBELUM await pertama.
    final auth = context.read<AuthProvider>();
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Hapus akun?'),
        content: const Text(
          'Akun, profil, foto, resep favorit, dan seluruh riwayat pindai Anda '
          'akan dihapus permanen dan tidak bisa dikembalikan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final error = await auth.deleteAccount(storage);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Akun Anda sudah dihapus.')),
    );
  }
}

/// Foto profil, atau huruf pertama nama bila belum ada foto.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 20});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    return CircleAvatar(
      radius: radius,
      foregroundImage: url == null ? null : CachedNetworkImageProvider(url),
      child: Text(
        user.displayName.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.8),
      ),
    );
  }
}
