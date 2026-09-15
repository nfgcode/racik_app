import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/errors.dart';
import '../../models/food.dart';
import '../../models/food_ingredient.dart';
import '../../models/ingredient.dart';
import '../../models/nutrition.dart';
import '../../models/recipe_step.dart';
import '../../providers/auth_provider.dart';
import '../../services/food_service.dart';
import '../../services/ingredient_service.dart';
import '../../services/storage_service.dart';

/// Use case: Mengelola Data Resep — tambah & ubah.
///
/// Satu formulir mengisi empat tabel sekaligus:
///   foods, nutritions (1:1), food_ingredients (1:*), steps (1:*).
/// Mengembalikan `true` lewat Navigator.pop setelah tersimpan.
class FoodFormScreen extends StatefulWidget {
  const FoodFormScreen({super.key, this.foodId});

  /// null = resep baru.
  final String? foodId;

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _servingSize = TextEditingController();
  final _cookTime = TextEditingController();
  final _imageUrl = TextEditingController();
  String? _difficulty;
  String _source = Food.sourceAdmin;

  // Satu controller per kolom tabel nutritions.
  final _nutrition = {
    'calories': TextEditingController(),
    'protein_g': TextEditingController(),
    'fat_g': TextEditingController(),
    'carbs_g': TextEditingController(),
    'sugar_g': TextEditingController(),
    'sodium_mg': TextEditingController(),
    'fiber_g': TextEditingController(),
  };
  static const _nutritionLabels = {
    'calories': 'Energi (kkal) *',
    'protein_g': 'Protein (g)',
    'fat_g': 'Lemak (g)',
    'carbs_g': 'Karbohidrat (g)',
    'sugar_g': 'Gula (g)',
    'sodium_mg': 'Natrium (mg)',
    'fiber_g': 'Serat (g)',
  };

  List<Ingredient> _allIngredients = [];
  final List<_IngredientRow> _ingredientRows = [];
  final List<_StepRow> _stepRows = [];

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  bool get _isNew => widget.foodId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final foodService = context.read<FoodService>();
    final ingredientService = context.read<IngredientService>();
    try {
      _allIngredients = await ingredientService.list();
      if (!_isNew) {
        final food = await foodService.getDetail(widget.foodId!);
        if (food != null) _fill(food);
      }
      if (_stepRows.isEmpty) _stepRows.add(_StepRow());
    } catch (e) {
      _loadError = friendlyError(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _fill(Food food) {
    _name.text = food.name;
    _description.text = food.description ?? '';
    _category.text = food.category ?? '';
    _servingSize.text = food.servingSize ?? '';
    _cookTime.text = food.cookTimeMinutes?.toString() ?? '';
    _imageUrl.text = food.imageUrl ?? '';
    _difficulty = food.difficulty;
    _source = food.source;

    final n = food.nutrition;
    if (n != null) {
      final values = n.toMap();
      for (final entry in _nutrition.entries) {
        final v = values[entry.key];
        entry.value.text = v == null ? '' : _formatNumber(v as double);
      }
    }
    for (final item in food.ingredients) {
      _ingredientRows.add(_IngredientRow(
        ingredientId: item.ingredientId,
        quantity: item.quantity == null ? '' : _formatNumber(item.quantity!),
        note: item.note ?? '',
      ));
    }
    for (final step in food.steps) {
      _stepRows.add(_StepRow(
        instruction: step.instruction,
        duration: step.durationMinutes?.toString() ?? '',
      ));
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _description, _category, _servingSize, _cookTime, _imageUrl,
      ..._nutrition.values,
    ]) {
      c.dispose();
    }
    for (final row in _ingredientRows) {
      row.dispose();
    }
    for (final row in _stepRows) {
      row.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ helpers ---

  static String _formatNumber(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toString();

  /// Menerima koma maupun titik sebagai pemisah desimal.
  static double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static String? _optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = _parse(v);
    return (n == null || n < 0) ? 'Angka tidak valid' : null;
  }

  static String? _requiredNumber(String? v) {
    if (v == null || v.trim().isEmpty) return 'Wajib diisi';
    return _optionalNumber(v);
  }

  String? _emptyToNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  // --------------------------------------------------------------- save ---

  Future<void> _uploadImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await storage.uploadJpeg(
        bucket: AppConfig.foodBucket,
        folder: 'foods',
        bytes: await file.readAsBytes(),
      );
      setState(() => _imageUrl.text = url);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final food = Food(
      id: widget.foodId,
      name: _name.text.trim(),
      description: _emptyToNull(_description),
      category: _emptyToNull(_category),
      servingSize: _emptyToNull(_servingSize),
      cookTimeMinutes: int.tryParse(_cookTime.text.trim()),
      difficulty: _difficulty,
      source: _source,
      imageUrl: _emptyToNull(_imageUrl),
    );
    final nutrition = Nutrition(
      calories: _parse(_nutrition['calories']!.text)!,
      proteinG: _parse(_nutrition['protein_g']!.text),
      fatG: _parse(_nutrition['fat_g']!.text),
      carbsG: _parse(_nutrition['carbs_g']!.text),
      sugarG: _parse(_nutrition['sugar_g']!.text),
      sodiumMg: _parse(_nutrition['sodium_mg']!.text),
      fiberG: _parse(_nutrition['fiber_g']!.text),
    );
    final ingredients = [
      for (final row in _ingredientRows)
        if (row.ingredientId != null)
          FoodIngredient(
            ingredientId: row.ingredientId!,
            quantity: _parse(row.quantity.text),
            note: _emptyToNull(row.note),
          ),
    ];
    final filledSteps = _stepRows.where((r) => r.instruction.text.trim().isNotEmpty);
    final steps = [
      for (final (i, row) in filledSteps.indexed)
        RecipeStep(
          stepOrder: i + 1,
          instruction: row.instruction.text.trim(),
          durationMinutes: int.tryParse(row.duration.text.trim()),
        ),
    ];

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<FoodService>().saveFood(
            food: food,
            nutrition: nutrition,
            ingredients: ingredients,
            steps: steps,
            adminId: context.read<AuthProvider>().user!.id,
          );
      messenger.showSnackBar(const SnackBar(content: Text('Resep tersimpan')));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
      if (mounted) setState(() => _saving = false);
    }
  }

  // -------------------------------------------------------------- build ---

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'Resep baru' : 'Ubah resep';
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(child: Text(_loadError!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('Informasi resep'),
            TextFormField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Nama makanan *',
                helperText: 'Harus sama persis dengan label model AI',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Deskripsi'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _category,
                    maxLength: 50,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingSize,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: 'Porsi'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cookTime,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Waktu masak (menit)'),
                    validator: _optionalNumber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _difficulty,
                    decoration: const InputDecoration(labelText: 'Kesulitan'),
                    items: [
                      for (final d in Food.difficulties)
                        DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: (v) => _difficulty = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'Sumber data'),
              items: const [
                DropdownMenuItem(
                  value: Food.sourceAdmin,
                  child: Text('admin — diinput manual'),
                ),
                DropdownMenuItem(
                  value: Food.sourceAi,
                  child: Text('ai — perkiraan AI, perlu dicek'),
                ),
              ],
              onChanged: (v) => _source = v ?? Food.sourceAdmin,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _imageUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'URL foto',
                suffixIcon: IconButton(
                  tooltip: 'Unggah foto dari galeri',
                  onPressed: _uploadImage,
                  icon: const Icon(Icons.upload),
                ),
              ),
            ),

            const _SectionTitle('Nutrisi per porsi'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in _nutrition.entries)
                  SizedBox(
                    width: 160,
                    child: TextFormField(
                      controller: entry.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _nutritionLabels[entry.key],
                      ),
                      validator: entry.key == 'calories'
                          ? _requiredNumber
                          : _optionalNumber,
                    ),
                  ),
              ],
            ),

            const _SectionTitle('Bahan'),
            if (_allIngredients.isEmpty)
              const Text('Belum ada data bahan. Tambahkan dulu di tab Bahan.'),
            for (final row in _ingredientRows)
              _IngredientRowField(
                key: ObjectKey(row),
                row: row,
                options: _allIngredients,
                onRemove: () => setState(() {
                  _ingredientRows.remove(row);
                  row.dispose();
                }),
              ),
            if (_allIngredients.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _ingredientRows.add(_IngredientRow())),
                icon: const Icon(Icons.add),
                label: const Text('Tambah bahan'),
              ),

            const _SectionTitle('Langkah memasak'),
            for (final (i, row) in _stepRows.indexed)
              _StepRowField(
                key: ObjectKey(row),
                number: i + 1,
                row: row,
                onRemove: _stepRows.length == 1
                    ? null
                    : () => setState(() {
                          _stepRows.remove(row);
                          row.dispose();
                        }),
              ),
            TextButton.icon(
              onPressed: () => setState(() => _stepRows.add(_StepRow())),
              icon: const Icon(Icons.add),
              label: const Text('Tambah langkah'),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Menyimpan…' : 'Simpan resep'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// Data satu baris bahan di formulir (belum tentu sudah tersimpan).
class _IngredientRow {
  _IngredientRow({this.ingredientId, String quantity = '', String note = ''})
      : quantity = TextEditingController(text: quantity),
        note = TextEditingController(text: note);

  String? ingredientId;
  final TextEditingController quantity;
  final TextEditingController note;

  void dispose() {
    quantity.dispose();
    note.dispose();
  }
}

class _IngredientRowField extends StatelessWidget {
  const _IngredientRowField({
    super.key,
    required this.row,
    required this.options,
    required this.onRemove,
  });

  final _IngredientRow row;
  final List<Ingredient> options;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: row.ingredientId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Bahan'),
              items: [
                for (final i in options)
                  DropdownMenuItem(
                    value: i.id,
                    child: Text(
                      i.unit == null ? i.name : '${i.name} (${i.unit})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => row.ingredientId = v,
              validator: (v) => v == null ? 'Pilih bahan' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: row.quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Jumlah'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: row.note,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
          ),
          IconButton(
            tooltip: 'Hapus bahan',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _StepRow {
  _StepRow({String instruction = '', String duration = ''})
      : instruction = TextEditingController(text: instruction),
        duration = TextEditingController(text: duration);

  final TextEditingController instruction;
  final TextEditingController duration;

  void dispose() {
    instruction.dispose();
    duration.dispose();
  }
}

class _StepRowField extends StatelessWidget {
  const _StepRowField({
    super.key,
    required this.number,
    required this.row,
    required this.onRemove,
  });

  final int number;
  final _StepRow row;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 8),
            child: CircleAvatar(radius: 14, child: Text('$number')),
          ),
          Expanded(
            flex: 4,
            child: TextFormField(
              controller: row.instruction,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Instruksi'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: TextFormField(
              controller: row.duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Menit'),
            ),
          ),
          IconButton(
            tooltip: 'Hapus langkah',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
