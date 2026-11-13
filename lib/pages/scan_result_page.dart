import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../controller/auth_controller.dart';
import '../controller/history_controller.dart';
import '../controller/scan_controller.dart';
import '../core/spacing.dart';
import '../enum/load_state.dart';
import '../model/scan_history.dart';
import '../widget/health_score_card.dart';
import '../widget/nutrition_card.dart';
import '../widget/scan_widgets.dart';
import '../widget/state_views.dart';
import 'food_detail_page.dart';

/// Use case: Memindai Makanan
///   └─ `<<include>>` Mengidentifikasi Citra Makanan
///       └─ `<<include>>` Menampilkan Detail Skor Kesehatan dan Informasi Nutrisi
class ScanResultPage extends StatefulWidget {
  final Uint8List imageBytes;
  final AuthController authController;
  final ScanController scanController;
  final HistoryController historyController;

  const ScanResultPage({
    super.key,
    required this.imageBytes,
    required this.authController,
    required this.scanController,
    required this.historyController,
  });

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  final _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _scan();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _scan() async {
    final controller = widget.scanController;
    await controller.scan(
      imageBytes: widget.imageBytes,
      userId: widget.authController.user?.id ?? '',
    );
    final outcome = controller.outcome;
    if (outcome == null || !mounted) return;
    // Riwayat dimuat ulang supaya hasil ini langsung muncul di tab Riwayat.
    if (outcome.saved != null) widget.historyController.loadHistory();
    // Pengguna pembaca layar (TalkBack) langsung mendengar hasilnya.
    SemanticsService.sendAnnouncement(
      View.of(context),
      _spokenSummary(outcome),
      TextDirection.ltr,
    );
  }

  Future<void> _speak(ScanOutcome outcome) async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(_spokenSummary(outcome));
  }

  /// Kalimat ringkas yang dibacakan, tanpa singkatan agar TTS lancar.
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
    final buffer = StringBuffer(
      'Terdeteksi ${o.food!.name}, keyakinan $confidence.',
    );
    if (o.health != null) {
      buffer.write(
        ' Skor kesehatan ${o.health!.score.toStringAsFixed(0)} '
        'dari 100, ${o.health!.label}.',
      );
    }
    final nutrition = o.food!.nutrition;
    if (nutrition != null) {
      buffer.write(
        ' Energi ${nutrition.calories.toStringAsFixed(0)} kilokalori per porsi.',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.scanController;
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil pindai')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          switch (controller.loadState) {
            case LoadState.initial:
            case LoadState.loading:
              return _Analyzing(imageBytes: widget.imageBytes);
            case LoadState.error:
              return ErrorState(
                message: controller.errorMessage,
                onRetry: _scan,
              );
            case LoadState.loaded:
              final outcome = controller.outcome!;
              return _ResultBody(
                outcome: outcome,
                onSpeak: () => _speak(outcome),
              );
          }
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
      padding: AppSpacing.page,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(imageBytes, height: 240, fit: BoxFit.cover),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: AppSpacing.lg),
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
      padding: AppSpacing.page,
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
        if (outcome.recognition.isDemo) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Mode demo — tebakan ini bukan hasil AI.',
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ScanHeader(
          foodName: food?.name ?? top.label,
          confidencePercent: top.percent,
        ),
        const SizedBox(height: AppSpacing.md),
        ScanStatusBanner(status: outcome.status, label: top.label),
        if (outcome.recognition.alternatives.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Kemungkinan lain: ${outcome.recognition.alternatives.map((p) => '${p.label} (${p.percent.toStringAsFixed(0)}%)').join(', ')}',
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: onSpeak,
          icon: const Icon(Icons.volume_up),
          label: const Text('Bacakan hasil'),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (outcome.health != null) HealthScoreCard.fromResult(outcome.health!),
        if (food != null && food.nutrition != null)
          NutritionCard(
            nutrition: food.nutrition!,
            servingSize: food.servingSize,
          ),
        // Resep lengkap hanya ada untuk makanan yang terdaftar di database.
        if (food != null && food.id != null) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FoodDetailPage(food: food)),
            ),
            icon: const Icon(Icons.menu_book),
            label: const Text('Lihat resep lengkap'),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (outcome.saved != null)
          Text(
            'Hasil ini tersimpan di Riwayat.',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          )
        else
          InlineError(message: 'Hasil belum tersimpan: ${outcome.saveError}'),
      ],
    );
  }
}
