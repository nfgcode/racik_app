import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../widget/state_views.dart';

/// Use case: Memindai Makanan (Pengguna).
///
/// Untuk progress ini baru tampilannya. Kamera, pengenalan AI, dan skor
/// kesehatan dikerjakan untuk UAS (lihat branch `uas`).
class ScanPage extends StatelessWidget {
  final AuthController authController;

  const ScanPage({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pindai makanan')),
      body: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          if (!authController.isLoggedIn) {
            return LoginRequired(
              feature: 'memindai makanan',
              authController: authController,
            );
          }
          return const EmptyState(
            icon: Icons.document_scanner_outlined,
            title: 'Segera hadir',
            message:
                'Arahkan kamera ke makanan, lalu Racik akan mengenalinya '
                'dan menghitung skor kesehatan serta informasi nutrisinya.',
          );
        },
      ),
    );
  }
}
