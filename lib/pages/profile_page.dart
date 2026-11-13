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
            ],
          );
        },
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
