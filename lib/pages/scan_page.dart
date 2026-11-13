import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../controller/auth_controller.dart';
import '../controller/history_controller.dart';
import '../controller/scan_controller.dart';
import '../core/spacing.dart';
import '../widget/state_views.dart';
import 'camera_page.dart';
import 'scan_result_page.dart';

/// Use case: Memindai Makanan (Pengguna) — pintu masuknya.
///
/// Kamera tidak dibuka langsung di tab ini, tetapi sebagai halaman penuh
/// terpisah (CameraPage), sehingga kamera hanya menyala saat dipakai.
class ScanPage extends StatelessWidget {
  final AuthController authController;
  final ScanController scanController;
  final HistoryController historyController;

  const ScanPage({
    super.key,
    required this.authController,
    required this.scanController,
    required this.historyController,
  });

  Future<void> _openCamera(BuildContext context) async {
    final navigator = Navigator.of(context);
    final bytes = await navigator.push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraPage(),
      ),
    );
    if (bytes != null) _showResult(navigator, bytes);
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    final navigator = Navigator.of(context);
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600, // cukup besar untuk AI, cukup kecil untuk diunggah
      imageQuality: 85,
    );
    if (file == null) return;
    _showResult(navigator, await file.readAsBytes());
  }

  void _showResult(NavigatorState navigator, Uint8List bytes) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ScanResultPage(
          imageBytes: bytes,
          authController: authController,
          scanController: scanController,
          historyController: historyController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

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
          return ListView(
            padding: AppSpacing.page,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Icon(
                Icons.document_scanner_outlined,
                size: 72,
                color: scheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Arahkan kamera ke makanan, lalu Racik akan mengenalinya dan '
                'menghitung skor kesehatannya.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => _openCamera(context),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Buka kamera'),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _pickFromGallery(context),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pilih foto dari galeri'),
              ),
              if (scanController.isDemo) ...[
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Mode demo: OPENROUTER_API_KEY belum diisi di env.json, '
                    'jadi hasil tebakan adalah contoh, bukan hasil AI.',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text('Agar hasilnya akurat', style: textTheme.titleSmall),
              const _Tip(
                icon: Icons.wb_sunny_outlined,
                text: 'Cari cahaya yang cukup terang',
              ),
              const _Tip(
                icon: Icons.filter_1,
                text: 'Satu jenis makanan per foto',
              ),
              const _Tip(
                icon: Icons.straighten,
                text: 'Jarak sekitar 30 cm dari piring',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(text),
    );
  }
}
