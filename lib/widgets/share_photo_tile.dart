import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/errors.dart';
import '../services/scan_service.dart';

/// Sakelar izin "Jadikan foto resep" untuk satu riwayat pindai.
///
/// Dipakai di layar hasil pindai (memberi izin) dan di detail riwayat
/// (supaya izin bisa ditarik kembali kapan saja). Penyimpanannya lewat
/// `ScanService.setSharePhoto` → RPC `share_scan_photo`, yang menolak izin
/// baru bila resepnya sudah punya foto.
class SharePhotoTile extends StatefulWidget {
  const SharePhotoTile({
    super.key,
    required this.scanId,
    this.foodName,
    this.initialValue = false,
  });

  final String scanId;

  /// Null bila nama resep belum bisa dibaca (resep belum diverifikasi).
  final String? foodName;
  final bool initialValue;

  @override
  State<SharePhotoTile> createState() => _SharePhotoTileState();
}

class _SharePhotoTileState extends State<SharePhotoTile> {
  late bool _shared = widget.initialValue;
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    final scans = context.read<ScanService>();
    final messenger = ScaffoldMessenger.of(context);
    final before = _shared;
    setState(() {
      _busy = true;
      _shared = value;
    });

    var result = value;
    String? message;
    try {
      final ok = await scans.setSharePhoto(widget.scanId, share: value);
      if (!ok) {
        result = false;
        if (value) {
          message = 'Resep ini sudah punya foto, jadi fotomu tidak diperlukan.';
        }
      } else if (!value) {
        message = 'Izin ditarik. Foto ini tidak akan dipakai sebagai foto resep.';
      }
    } catch (e) {
      result = before;
      message = friendlyError(e);
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _shared = result;
    });
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final resep = widget.foodName == null ? 'Resep ini' : 'Resep ${widget.foodName}';
    return Card(
      child: SwitchListTile(
        value: _shared,
        onChanged: _busy ? null : _toggle,
        secondary: const Icon(Icons.add_photo_alternate_outlined),
        title: const Text('Jadikan foto resep'),
        subtitle: Text(
          _shared
              ? 'Admin boleh memakai foto ini sebagai foto resep. Matikan '
                  'untuk menarik izin. Foto yang sudah dipilih admin tetap '
                  'dipakai, tanpa namamu.'
              : '$resep belum punya foto. Izinkan admin memakai foto ini? '
                  'Bila dipilih admin, salinannya tetap dipakai walau '
                  'riwayat atau akunmu dihapus.',
        ),
      ),
    );
  }
}
