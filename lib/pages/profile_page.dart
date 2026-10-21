import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../model/app_user.dart';
import '../widget/state_views.dart';

/// Tab Profil — menampilkan akun yang sedang login dan tombol Keluar.
/// Use case Mengubah Profil Akun dikerjakan untuk UAS.
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
                '@${user.username} · ${authController.email ?? ''}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
