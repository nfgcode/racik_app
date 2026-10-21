import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../pages/login_page.dart';
import '../pages/register_page.dart';

/// Tampilan saat daftar kosong atau fitur belum tersedia.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(message!, textAlign: TextAlign.center),
              ],
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tampilan saat data gagal dimuat, dengan tombol coba lagi.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off,
      title: 'Data belum bisa dimuat',
      message: message,
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Coba lagi'),
      ),
    );
  }
}

/// Ditampilkan kepada Guest saat membuka fitur milik aktor Pengguna.
class LoginRequired extends StatelessWidget {
  const LoginRequired({
    super.key,
    required this.feature,
    required this.authController,
  });

  /// Contoh: "memindai makanan".
  final String feature;
  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline,
      title: 'Masuk untuk $feature',
      message:
          'Tamu bisa mencari dan membaca resep. '
          'Fitur ini khusus untuk pengguna yang sudah masuk.',
      action: Container(
        child: Column(
          children: [
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoginPage(authController: authController),
                ),
              ),
              child: const Text('Masuk'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegisterPage(authController: authController),
                ),
              ),
              child: const Text('Belum punya akun? Daftar'),
            ),
          ],
        ),
      ),
    );
  }
}
