import 'package:flutter/material.dart';

import '../controller/auth_controller.dart';
import '../widget/state_views.dart';

/// Use case: Melihat Hasil Pemindaian Makanan (Pengguna).
///
/// Untuk progress ini baru tampilannya. Riwayat dari tabel `scan_history`
/// dikerjakan bersama fitur pindai untuk UAS.
class HistoryPage extends StatelessWidget {
  final AuthController authController;

  const HistoryPage({super.key, required this.authController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat pindai')),
      body: ListenableBuilder(
        listenable: authController,
        builder: (context, _) {
          if (!authController.isLoggedIn) {
            return LoginRequired(
              feature: 'melihat riwayat pindai',
              authController: authController,
            );
          }
          return const EmptyState(
            icon: Icons.history,
            title: 'Belum ada riwayat',
            message: 'Hasil pemindaian makanan Anda akan muncul di sini.',
          );
        },
      ),
    );
  }
}
