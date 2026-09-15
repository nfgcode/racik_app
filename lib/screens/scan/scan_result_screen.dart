import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/scan_history.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recognizer_provider.dart';
import '../../services/food_service.dart';
import '../../services/scan_pipeline.dart';
import '../../services/scan_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/health_score_card.dart';
import '../../widgets/nutrition_card.dart';
import '../../widgets/scan_widgets.dart';
import '../../widgets/state_views.dart';
import '../recipe/recipe_detail_screen.dart';

/// Use case: Memindai Makanan → Mengidentifikasi Citra Makanan →
/// Menampilkan Detail Skor Kesehatan dan Informasi Nutrisi.
class ScanResultScreen extends StatefulWidget {
  const ScanResultScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final _tts = FlutterTts();
  late Future<ScanOutcome> _future;

  @override
  void initState() {
    super.initState();
    _future = _runPipeline();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<ScanOutcome> _runPipeline() async {
    // Ambil semua dependensi dari context SEBELUM await pertama.
    final recognizerProvider = context.read<RecognizerProvider>();
    final foods = context.read<FoodService>();
    final scans = context.read<ScanService>();
    final storage = context.read<StorageService>();
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id ?? '';

    final pipeline = ScanPipeline(
      recognizer: await recognizerProvider.obtain(),
      foods: foods,
      scans: scans,
      storage: storage,
    );
    final outcome = await pipeline.run(
      imageBytes: widget.imageBytes,
      userId: userId,
    );

    // Pengguna pembaca layar (TalkBack) langsung mendengar hasilnya.
    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        _spokenSummary(outcome),
        TextDirection.ltr,
      );
    }
    return outcome;
  }

  Future<void> _speak(ScanOutcome outcome) async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(_spokenSummary(outcome));
  }

  /// Kalimat ringkas yang dibacakan — tanpa singkatan agar TTS lancar.
  String _spokenSummary(ScanOutcome o) {
    final top = o.recognition.top;
    final confidence = '${top.percent.toStringAsFixed(0)} persen';
    if (o.status == ScanHistory.statusTidakYakin) {
      return 'AI kurang yakin. Tebakan terbaik ${top.label}, keyakinan '
          '$confidence. Coba foto ulang dengan cahaya lebih terang.';
    }
    if (o.food == null) {
      return 'Terdeteksi ${top.label}, tetapi datanya belum ada di Racik.';
    }
    final foodName = o.food?.name ?? top.label;
    final buffer = StringBuffer('Terdeteksi $foodName, keyakinan $confidence.');
    if (o.health != null) {
      buffer.write(' Skor kesehatan ${o.health!.score.toStringAsFixed(0)} '
          'dari 100, ${o.health!.label}.');
    }
    if (o.food?.nutrition != null) {
      buffer.write(' Energi ${o.food!.nutrition!.calories.toStringAsFixed(0)} '
          'kilokalori per porsi.');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil pindai')),
      body: FutureBuilder<ScanOutcome>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _Analyzing(imageBytes: widget.imageBytes);
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: () => setState(() => _future = _runPipeline()),
            );
          }
          return _ResultBody(
            outcome: snapshot.data!,
            onSpeak: () => _speak(snapshot.data!),
          );
        },
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(imageBytes, height: 240, fit: BoxFit.cover),
        ),
        const SizedBox(height: 32),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        // liveRegion: pembaca layar ikut membacakan teks ini saat muncul.
        Semantics(
          liveRegion: true,
          child: const Text(
            'Mengenali makanan dan menghitung skor kesehatan…',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.outcome, required this.onSpeak});

  final ScanOutcome outcome;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final top = outcome.recognition.top;
    final food = outcome.food;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            outcome.imageBytes,
            height: 220,
            fit: BoxFit.cover,
            semanticLabel: 'Foto yang dipindai',
          ),
        ),
        if (outcome.recognition.isDemo)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Mode demo — tebakan ini bukan hasil AI.',
              style: textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        ScanHeader(foodName: food?.name ?? top.label, confidencePercent: top.percent),
        const SizedBox(height: 12),
        ScanStatusBanner(status: outcome.status, label: top.label),
        if (outcome.recognition.alternatives.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Kemungkinan lain: ${outcome.recognition.alternatives.map(
                  (p) => '${p.label} (${p.percent.toStringAsFixed(0)}%)',
                ).join(', ')}',
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onSpeak,
          icon: const Icon(Icons.volume_up),
          label: const Text('Bacakan hasil'),
        ),
        const SizedBox(height: 16),
        if (outcome.health != null) HealthScoreCard.fromResult(outcome.health!),
        if (food != null && food.nutrition != null)
          NutritionCard(nutrition: food.nutrition!, servingSize: food.servingSize),
        if (food != null && food.id != null) ...[
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecipeDetailScreen(foodId: food.id!),
              ),
            ),
            icon: const Icon(Icons.menu_book),
            label: const Text('Lihat resep lengkap'),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          outcome.saved != null
              ? 'Hasil ini tersimpan di Riwayat.'
              : 'Hasil belum tersimpan: ${outcome.saveError}',
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
