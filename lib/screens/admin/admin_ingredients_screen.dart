import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors.dart';
import '../../models/ingredient.dart';
import '../../services/ingredient_service.dart';
import '../../widgets/state_views.dart';

/// Use case: Mengelola Data Bahan (Admin) — tambah, ubah, hapus.
class AdminIngredientsScreen extends StatefulWidget {
  const AdminIngredientsScreen({super.key});

  @override
  State<AdminIngredientsScreen> createState() => _AdminIngredientsScreenState();
}

class _AdminIngredientsScreenState extends State<AdminIngredientsScreen> {
  late Future<List<Ingredient>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = context.read<IngredientService>().list();

  void _reload() => setState(_load);

  /// Dialog yang sama untuk tambah (ingredient == null) dan ubah.
  Future<void> _edit([Ingredient? ingredient]) async {
    final result = await showDialog<Ingredient>(
      context: context,
      builder: (_) => _IngredientDialog(initial: ingredient),
    );
    if (result == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<IngredientService>().save(result);
      _reload();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _delete(Ingredient ingredient) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<IngredientService>().delete(ingredient.id!);
      _reload();
      messenger.showSnackBar(
        SnackBar(content: Text('"${ingredient.name}" dihapus')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelola bahan')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-bahan', // lihat catatan heroTag di admin_foods_screen.dart
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Bahan baru'),
      ),
      body: FutureBuilder<List<Ingredient>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: friendlyError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.egg_alt_outlined,
              title: 'Belum ada bahan',
              message: 'Bahan dipakai saat menyusun resep.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: item.unit == null ? null : Text('Satuan: ${item.unit}'),
                onTap: () => _edit(item),
                trailing: IconButton(
                  tooltip: 'Hapus ${item.name}',
                  onPressed: () => _delete(item),
                  icon: const Icon(Icons.delete_outline),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _IngredientDialog extends StatefulWidget {
  const _IngredientDialog({this.initial});

  final Ingredient? initial;

  @override
  State<_IngredientDialog> createState() => _IngredientDialogState();
}

class _IngredientDialogState extends State<_IngredientDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _unit = TextEditingController(text: widget.initial?.unit);

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Bahan baru' : 'Ubah bahan'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Nama bahan'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            TextFormField(
              controller: _unit,
              maxLength: 20,
              decoration: const InputDecoration(
                labelText: 'Satuan',
                hintText: 'gram, butir, sdm, siung',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.pop(
              context,
              Ingredient(
                id: widget.initial?.id,
                name: _name.text.trim(),
                unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
