import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/errors.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import 'profile_screen.dart';

/// Use case: Mengubah Profil Akun (Pengguna).
/// Kolom yang boleh diubah: username, full_name, avatar_url.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  String? _avatarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _fullName = TextEditingController(text: user.fullName);
    _username = TextEditingController(text: user.username);
    _avatarUrl = user.avatarUrl;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (file == null || !mounted) return;

    final storage = context.read<StorageService>();
    final userId = context.read<AuthProvider>().user!.id;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    try {
      final url = await storage.uploadJpeg(
        bucket: AppConfig.avatarBucket,
        folder: userId,
        bytes: await file.readAsBytes(),
      );
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final updated = auth.user!.copyWith(
      username: _username.text.trim().toLowerCase(),
      fullName: _fullName.text.trim(),
      avatarUrl: _avatarUrl,
    );
    final error = await auth.updateProfile(updated);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil tersimpan')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final preview = auth.user!.copyWith(avatarUrl: _avatarUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(child: UserAvatar(user: preview, radius: 48)),
            TextButton.icon(
              onPressed: _uploading ? null : _pickAvatar,
              icon: _uploading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.photo_camera_outlined),
              label: const Text('Ganti foto profil'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullName,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _username,
              maxLength: 50,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: (v) =>
                  RegExp(r'^[a-z0-9_]{3,50}$')
                          .hasMatch(v?.trim().toLowerCase() ?? '')
                      ? null
                      : 'Minimal 3 karakter: a–z, 0–9, atau _',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: auth.isBusy || _uploading ? null : _save,
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
