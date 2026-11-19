import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../core/spacing.dart';
import '../model/app_user.dart';
import '../widget/state_views.dart';
import 'edit_profile_page.dart';

/// Tab Profil — pintu ke use case Mengubah Profil Akun dan Keluar.
class ProfilePage extends StatelessWidget {
  final AuthController authController;

  const ProfilePage({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          final user = authController.user;
          if (!authController.isLoggedIn || user == null) {
            return LoginRequired(
              feature: 'membuka profil',
              authController: authController,
            );
          }
          return ListView(
            padding: AppSpacing.page,
            children: [
              Center(child: UserAvatar(user: user, radius: 48)),
              const SizedBox(height: AppSpacing.md),
              Text(
                user.displayName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              Text(
                '@${user.username} · ${authController.email ?? ''}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Ubah profil'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditProfilePage(authController: authController),
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Keluar'),
                onTap: authController.logout,
              ),
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
          );
        },
      ),
    );
  }

  /// Hapus akun (syarat Google Play) dengan konfirmasi dulu.
  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Hapus akun?'),
        content: const Text(
          'Akun, profil, foto, dan seluruh riwayat pindai Anda akan dihapus '
          'permanen dan tidak bisa dikembalikan.',
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

    final success = await authController.deleteAccount();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Akun Anda sudah dihapus.' : authController.errorMessage,
        ),
      ),
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
      foregroundImage: url == null ? null : NetworkImage(url),
      child: Text(
        user.displayName.characters.first.toUpperCase(),
        style: TextStyle(fontSize: radius * 0.8),
      ),
    );
  }
}
