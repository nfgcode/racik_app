import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config.dart';

/// Titik masuk aplikasi Racik.
///
/// `async` karena Supabase harus siap SEBELUM widget pertama dibangun.
/// ensureInitialized() wajib dipanggil sebelum memakai plugin apa pun
/// ketika main() melakukan await.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.isSupabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseKey,
    );
  }

  runApp(const RacikApp());
}
