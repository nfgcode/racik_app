import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/recognizer_provider.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/home/main_shell.dart';
import 'services/auth_service.dart';
import 'services/favorite_service.dart';
import 'services/food_service.dart';
import 'services/ingredient_service.dart';
import 'services/scan_service.dart';
import 'services/stats_service.dart';
import 'services/storage_service.dart';
import 'services/user_service.dart';

class RacikApp extends StatelessWidget {
  const RacikApp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isSupabaseConfigured) {
      return MaterialApp(
        title: 'Racik',
        theme: AppTheme.light(),
        home: const _SetupRequiredScreen(),
      );
    }

    final client = Supabase.instance.client;

    // MultiProvider menaruh objek di atas seluruh pohon widget, sehingga
    // layar mana pun bisa mengambilnya dengan context.read<T>() tanpa
    // mengoper lewat konstruktor dari layar ke layar.
    return MultiProvider(
      providers: [
        Provider(create: (_) => FoodService(client)),
        Provider(create: (_) => IngredientService(client)),
        Provider(create: (_) => ScanService(client)),
        Provider(create: (_) => StorageService(client)),
        Provider(create: (_) => FavoriteService(client)),
        Provider(create: (_) => UserService(client)),
        Provider(create: (_) => StatsService(client)),
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthService(client))),
        ChangeNotifierProvider(create: (_) => RecognizerProvider()),
      ],
      child: MaterialApp(
        title: 'Racik',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const AuthGate(),
      ),
    );
  }
}

/// Memilih kerangka layar sesuai aktor pada diagram use case.
///
/// Karena memakai context.watch, AuthGate otomatis membangun ulang dirinya
/// setiap kali pengguna login, logout, atau perannya berubah.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Tampilkan pesan satu kali (mis. "akun dinonaktifkan") setelah frame ini.
    final notice = auth.takeNotice();
    if (notice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice)));
      });
    }

    return switch (auth.actor) {
      Actor.memuat => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      Actor.admin => const AdminShell(),
      Actor.guest || Actor.pengguna => const MainShell(),
    };
  }
}

class _SetupRequiredScreen extends StatelessWidget {
  const _SetupRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Racik belum terhubung ke Supabase',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const Text(
              '1. Salin env.example.json menjadi env.json lalu isi '
              'SUPABASE_URL dan SUPABASE_KEY dari dashboard Supabase '
              '(Project Settings → API).\n\n'
              '2. Jalankan ulang aplikasi dengan:\n'
              'flutter run --dart-define-from-file=env.json',
            ),
          ],
        ),
      ),
    );
  }
}
