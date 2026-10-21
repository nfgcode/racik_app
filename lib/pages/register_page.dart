import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import 'login_page.dart';

/// Use case: Mendaftar Akun (Guest).
class RegisterPage extends StatefulWidget {
  final AuthController authController;

  const RegisterPage({super.key, required this.authController});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  // Batasan mengikuti ERD: username varchar(50), full_name varchar(100).
  static final _usernamePattern = RegExp(r'^[a-z0-9_]{3,50}$');

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = widget.authController;
    final navigator = Navigator.of(context);

    final success = await auth.register(
      email: _email.text,
      password: _password.text,
      username: _username.text.trim().toLowerCase(),
      fullName: _fullName.text.trim(),
    );

    if (!mounted) return;
    if (!success) {
      setState(() => _error = auth.errorMessage);
      return;
    }
    if (auth.needsEmailConfirmation) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cek email Anda'),
          content: Text(
            'Kami mengirim tautan konfirmasi ke ${_email.text}. '
            'Buka tautan itu, lalu masuk dengan akun baru Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Mengerti'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => LoginPage(authController: auth)),
      );
      return;
    }
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daftar akun')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Nama lengkap'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _username,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Masukkan email yang valid'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'Minimal 6 karakter',
                ),
                validator: (v) => (v == null || v.length < 6)
                    ? 'Password minimal 6 karakter'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              ListenableBuilder(
                listenable: widget.authController,
                builder: (context, _) {
                  final busy = widget.authController.isLoading;
                  return FilledButton(
                    onPressed: busy ? null : _submit,
                    child: busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Daftar'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
