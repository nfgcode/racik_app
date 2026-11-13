import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controller/auth_controller.dart';
import 'controller/food_controller.dart';
import 'controller/history_controller.dart';
import 'controller/scan_controller.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'pages/setup_page.dart';
import 'pages/splash_page.dart';
import 'service/auth_service.dart';
import 'service/food_service.dart';
import 'service/scan_service.dart';
import 'service/storage_service.dart';

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
  final foodService = FoodService(client);
  final scanService = ScanService(client);
  final storageService = StorageService(client);

  final authController = AuthController(
    authService: AuthService(client),
    storageService: storageService,
  );
  final foodController = FoodController(foodService: foodService)
    ..loadFoods()
    ..loadCategories();
  final scanController = ScanController(
    foodService: foodService,
    scanService: scanService,
    storageService: storageService,
  );
  final historyController = HistoryController(
    scanService: scanService,
    foodService: foodService,
  );
  // Riwayat mengikuti akun yang sedang login (login, logout, ganti akun).
  authController.addListener(
    () => historyController.setUser(authController.user?.id),
  );

  runApp(
    RacikApp(
      authController: authController,
      foodController: foodController,
      scanController: scanController,
      historyController: historyController,
    ),
  );
}

class RacikApp extends StatelessWidget {
  final AuthController authController;
  final FoodController foodController;
  final ScanController scanController;
  final HistoryController historyController;

  const RacikApp({
    super.key,
    required this.authController,
    required this.foodController,
    required this.scanController,
    required this.historyController,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Racik',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      // SplashPage pindah ke MainPage setelah sesi login selesai dibaca.
      home: SplashPage(
        authController: authController,
        foodController: foodController,
        scanController: scanController,
        historyController: historyController,
      ),
    );
  }
}
