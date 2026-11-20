import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/state_views.dart';
import '../profile/profile_screen.dart';
import 'admin_account_menu.dart';

/// Use case: Mengelola Akun Pengguna (Admin) — ubah peran & status aktif.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  // Badan blok, bukan `=>`: fungsi panah ikut mengembalikan Future hasil
  // assignment, dan setState(_load) menolak callback yang mengembalikan Future
  // (error "setState() callback argument returned a Future" di mode debug).
  void _load() {
    _future = context.read<UserService>().list(query: _query.text);
  }

  void _reload() => setState(_load);

  /// Menyimpan peran / status aktif. [successMessage] ditampilkan bila
  /// berhasil (misalnya pengingat login ulang setelah peran berubah).
  Future<void> _update(AppUser updated, {String? successMessage}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<UserService>().updateAccess(updated);
      _reload();
      if (successMessage != null) {
        messenger.showSnackBar(SnackBar(
          content: Text(successMessage),
          duration: const Duration(seconds: 6),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola akun'),
        actions: const [AdminAccountMenu()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(
                hintText: 'Cari username atau nama',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _reload);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Ketuk akun untuk mengubah peran (pengguna/admin). '
              'Sakelar di kanan untuk mengaktifkan atau menonaktifkan akun.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppUser>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return ErrorState(
                    message: friendlyError(snapshot.error!),
                    onRetry: _reload,
                  );
                }
                final users = snapshot.data!;
                if (users.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_search,
                    title: 'Akun tidak ditemukan',
                  );
                }
                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isMe = user.id == myId;
                    final tile = ListTile(
                      leading: UserAvatar(user: user),
                      title: Text(user.displayName),
                      subtitle: Text(
                        '@${user.username} · ${user.role}'
                        '${user.isActive ? '' : ' · nonaktif'}'
                        '${isMe ? ' · akun kamu' : ''}',
                      ),
                      onTap: isMe ? null : () => _showRoleDialog(user),
                      // Admin tidak bisa menonaktifkan akunnya sendiri,
                      // supaya tidak terkunci dari aplikasi.
                      trailing: Switch(
                        value: user.isActive,
                        onChanged: isMe
                            ? null
                            : (v) => _update(user.copyWith(isActive: v)),
                      ),
                    );
                    // Pembaca layar mendengar "ketuk dua kali untuk ubah peran".
                    return isMe
                        ? tile
                        : Semantics(onTapHint: 'ubah peran', child: tile);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRoleDialog(AppUser user) async {
    final role = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Peran ${user.displayName}'),
        children: [
          for (final r in [AppUser.rolePengguna, AppUser.roleAdmin])
            ListTile(
              leading: Icon(
                r == user.role
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(r),
              onTap: () => Navigator.pop(context, r),
            ),
        ],
      ),
    );
    if (role == null || role == user.role || !mounted) return;

    // Hak admin besar, jadi mengangkat maupun menurunkan admin dikonfirmasi.
    final jadiAdmin = role == AppUser.roleAdmin;
    final nama = user.displayName;
    final setuju = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(jadiAdmin ? 'Jadikan $nama admin?' : 'Turunkan $nama jadi pengguna?'),
        content: Text(
          jadiAdmin
              ? 'Admin bisa menambah, mengubah, dan menghapus resep dan bahan, '
                  'melihat statistik, serta mengubah peran dan menonaktifkan '
                  'akun lain.'
              : '$nama tidak bisa lagi membuka menu admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(jadiAdmin ? 'Jadikan admin' : 'Turunkan'),
          ),
        ],
      ),
    );
    if (setuju != true) return;

    // Server langsung menerapkan peran baru (RLS membaca users.role), tetapi
    // aplikasi di HP orang itu baru membaca ulang perannya saat ia login lagi.
    _update(
      user.copyWith(role: role),
      successMessage: jadiAdmin
          ? '$nama sekarang admin. Minta $nama keluar lalu login lagi '
              'supaya menu admin muncul.'
          : '$nama sekarang pengguna. Hak adminnya langsung dicabut; menu '
              'admin di HP-nya hilang setelah ia login lagi.',
    );
  }
}
