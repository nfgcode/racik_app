import 'dart:async';

import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../controller/food_controller.dart';
import '../core/spacing.dart';
import '../enum/auth_status.dart';
import 'main_page.dart';

/// Layar pembuka: logo Racik muncul dengan animasi, lalu pindah ke
/// MainPage setelah minimal [minDuration] DAN sesi login selesai dibaca.
class SplashPage extends StatefulWidget {
  final AuthController authController;
  final FoodController foodController;

  const SplashPage({
    super.key,
    required this.authController,
    required this.foodController,
  });

  static const minDuration = Duration(milliseconds: 1800);

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _animation,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.8,
    end: 1,
  ).animate(CurvedAnimation(parent: _animation, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _openMainPage();
  }

  @override
  void dispose() {
    // AnimationController memegang ticker — selalu dispose.
    _animation.dispose();
    super.dispose();
  }

  Future<void> _openMainPage() async {
    final navigator = Navigator.of(context);
    await Future.wait([
      Future<void>.delayed(SplashPage.minDuration),
      _waitForSession(),
    ]);
    if (!mounted) return;
    navigator.pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => MainPage(
          authController: widget.authController,
          foodController: widget.foodController,
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Selesai saat AuthController sudah tahu pengguna Guest atau sudah login.
  Future<void> _waitForSession() {
    final auth = widget.authController;
    if (auth.status != AuthStatus.unknown) return Future.value();

    final completer = Completer<void>();
    void listener() {
      if (auth.status != AuthStatus.unknown && !completer.isCompleted) {
        auth.removeListener(listener);
        completer.complete();
      }
    }

    auth.addListener(listener);
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: _fade,
                child: ScaleTransition(
                  scale: _scale,
                  child: Image.asset(
                    'assets/images/logo_racik.png',
                    width: 168,
                    height: 168,
                    semanticLabel: 'Logo Racik',
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  'Pemindai makanan berbasis AI',
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  semanticsLabel: 'Memuat',
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
