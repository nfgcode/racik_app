import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../profile/profile_screen.dart';

enum _AksiAkun { profil, keluar }

/// Menu akun admin di app bar setiap tab admin: membuka profil sendiri
/// (ubah profil, favorit) atau keluar. Tanpa ini admin hanya bisa keluar dari
/// tab Resep, dan tidak punya jalan ke profilnya sendiri.
class AdminAccountMenu extends StatelessWidget {
  const AdminAccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return PopupMenuButton<_AksiAkun>(
      tooltip: 'Akun saya',
      icon: user == null
          ? const Icon(Icons.account_circle_outlined)
          : UserAvatar(user: user, radius: 14),
      onSelected: (aksi) {
        switch (aksi) {
          case _AksiAkun.profil:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          case _AksiAkun.keluar:
            context.read<AuthProvider>().logout();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _AksiAkun.profil,
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profil saya'),
          ),
        ),
        PopupMenuItem(
          value: _AksiAkun.keluar,
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Keluar'),
          ),
        ),
      ],
    );
  }
}
