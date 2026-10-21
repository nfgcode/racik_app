import 'package:flutter/material.dart';

/// Ditampilkan bila aplikasi dijalankan tanpa env.json.
class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Racik belum terhubung ke Supabase',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Salin env.example.json menjadi env.json lalu isi '
              'SUPABASE_URL dan SUPABASE_KEY dari dashboard Supabase '
              '(Project Settings → API).\n\n'
              '2. Jalankan ulang aplikasi dengan:\n'
              'flutter run --dart-define-from-file=env.json\n\n'
              'Di VS Code, pilih konfigurasi "Racik" atau "Racik (Chrome)" '
              'di panel Run and Debug.',
            ),
          ],
        ),
      ),
    );
  }
}
