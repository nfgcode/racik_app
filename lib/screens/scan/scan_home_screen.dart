import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/recognizer_provider.dart';
import '../../widgets/state_views.dart';
import 'camera_capture_screen.dart';
import 'scan_result_screen.dart';

/// Tab "Pindai" — pintu masuk use case Memindai Makanan (Pengguna).
///
/// Kamera tidak dibuka langsung di tab ini. Ia dibuka sebagai layar penuh
/// terpisah (CameraCaptureScreen), sehingga kamera hanya menyala saat
/// benar-benar dipakai dan otomatis mati saat layarnya ditutup.
class ScanHomeScreen extends StatefulWidget {
  const ScanHomeScreen({super.key});

  @override
  State<ScanHomeScreen> createState() => _ScanHomeScreenState();
}

class _ScanHomeScreenState extends State<ScanHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Muat model AI lebih awal, selagi pengguna membaca petunjuk.
    context.read<RecognizerProvider>().obtain();
  }

  Future<void> _openCamera() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    if (bytes != null) _showResult(bytes);
  }

  Future<void> _pickFromGallery() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600, // cukup besar untuk AI, cukup kecil untuk diunggah
      imageQuality: 85,
    );
    if (file == null) return;
    _showResult(await file.readAsBytes());
  }

  void _showResult(Uint8List bytes) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScanResultScreen(imageBytes: bytes)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pindai makanan')),
        body: const LoginRequired(feature: 'memindai makanan'),
      );
    }

    final recognizer = context.watch<RecognizerProvider>();
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Pindai makanan')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.document_scanner_outlined, size: 72, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Arahkan kamera ke makanan, lalu Racik akan mengenalinya dan '
            'menghitung skor kesehatannya.',
            style: textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Aksi utama diletakkan SEBELUM petunjuk: dengan huruf besar di
          // HP kecil, pengguna tetap bisa langsung menekannya tanpa menggulir,
          // dan pembaca layar menjumpainya lebih dulu.
          FilledButton.icon(
            onPressed: _openCamera,
            icon: const Icon(Icons.photo_camera),
            label: const Text('Buka kamera'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pilih foto dari galeri'),
          ),
          if (recognizer.isDemo) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Mode demo: model AI belum dipasang di assets/models, jadi '
                'hasil tebakan adalah contoh, bukan hasil AI.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Agar hasilnya akurat', style: textTheme.titleSmall),
          const _Tip(icon: Icons.wb_sunny_outlined, text: 'Cari cahaya yang cukup terang'),
          const _Tip(icon: Icons.filter_1, text: 'Satu jenis makanan per foto'),
          const _Tip(icon: Icons.straighten, text: 'Jarak sekitar 30 cm dari piring'),
        ],
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
