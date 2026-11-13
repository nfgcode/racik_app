import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controller/auth_controller.dart';
import '../core/errors.dart';
import '../core/spacing.dart';
import '../widget/state_views.dart';
import 'profile_page.dart';

/// Use case: Mengubah Profil Akun (Pengguna).
/// Kolom yang boleh diubah: username, full_name, avatar_url.
class EditProfilePage extends StatefulWidget {
  final AuthController authController;

  const EditProfilePage({super.key, required this.authController});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  String? _avatarUrl;
  bool _uploading = false;
  String? _error;

  static final _usernamePattern = RegExp(r'^[a-z0-9_]{3,50}$');

  @override
  void initState() {
    super.initState();
    final user = widget.authController.user!;
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

    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final url = await widget.authController.uploadAvatar(
        await file.readAsBytes(),
      );
      if (mounted) setState(() => _avatarUrl = url);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal mengunggah foto: ${friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = widget.authController;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final success = await auth.updateProfile(
      auth.user!.copyWith(
        username: _username.text.trim().toLowerCase(),
        fullName: _fullName.text.trim(),
        avatarUrl: _avatarUrl,
      ),
    );
    if (!mounted) return;
    if (!success) {
      setState(() => _error = auth.errorMessage);
      return;
    }
    messenger.showSnackBar(const SnackBar(content: Text('Profil tersimpan')));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authController;
    final preview = auth.user!.copyWith(avatarUrl: _avatarUrl);

    return Scaffold(
      appBar: AppBar(title: const Text('Ubah profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            Center(child: UserAvatar(user: preview, radius: 48)),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton.icon(
                onPressed: _uploading ? null : _pickAvatar,
                icon: _uploading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_outlined),
                label: const Text('Ganti foto profil'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _fullName,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nama lengkap'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _username,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Username',
                helperText: 'Huruf kecil, angka, atau garis bawah',
              ),
              validator: (v) =>
                  _usernamePattern.hasMatch(v?.trim().toLowerCase() ?? '')
                  ? null
                  : 'Minimal 3 karakter: a–z, 0–9, atau _',
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.lg),
              InlineError(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            ListenableBuilder(
              listenable: auth,
              builder: (context, _) {
                final busy = auth.isLoading || _uploading;
                return FilledButton(
                  onPressed: busy ? null : _save,
                  child: auth.isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
