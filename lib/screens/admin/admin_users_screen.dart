import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/state_views.dart';
import '../profile/profile_screen.dart';

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

  void _load() => _future = context.read<UserService>().list(query: _query.text);

  void _reload() => setState(_load);

  Future<void> _update(AppUser updated) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<UserService>().updateAccess(updated);
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola akun')),
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
                    return ListTile(
                      leading: UserAvatar(user: user),
                      title: Text(user.displayName),
                      subtitle: Text(
                        '@${user.username} · ${user.role}'
                        '${user.isActive ? '' : ' · nonaktif'}',
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
    if (role != null && role != user.role) {
      _update(user.copyWith(role: role));
    }
  }
}
