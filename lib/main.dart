import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller/auth_controller.dart';
import 'controller/food_controller.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'enum/auth_status.dart';
import 'pages/main_page.dart';
import 'pages/setup_page.dart';
import 'service/auth_service.dart';
import 'service/food_service.dart';

/// Titik masuk aplikasi Racik.
///
/// `async` karena Supabase harus siap SEBELUM widget pertama dibangun.
/// ensureInitialized() wajib dipanggil sebelum memakai plugin apa pun
/// ketika main() melakukan await.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!AppConfig.isSupabaseConfigured) {
    runApp(const MaterialApp(title: 'Racik', home: SetupPage()));
    return;
  }

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );
  final client = Supabase.instance.client;

  // Service dibuat sekali, lalu dioper ke controller lewat konstruktor.
  final authController = AuthController(authService: AuthService(client));
  final foodController = FoodController(foodService: FoodService(client))
    ..loadFoods()
    ..loadCategories();

  runApp(
    RacikApp(authController: authController, foodController: foodController),
  );
}

class RacikApp extends StatelessWidget {
  final AuthController authController;
  final FoodController foodController;

  const RacikApp({
    super.key,
    required this.authController,
    required this.foodController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Racik',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          // Tunggu sampai sesi login yang tersimpan selesai dibaca.
          if (authController.status == AuthStatus.unknown) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return MainPage(
            authController: authController,
            foodController: foodController,
          );
        },
      ),
    );
  }
}
