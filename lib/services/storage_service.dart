import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengunggah foto ke Supabase Storage dan mengembalikan URL publiknya.
/// URL inilah yang disimpan ke kolom `image_url` / `avatar_url`.
class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  /// [folder] biasanya id pengguna, sehingga kebijakan Storage bisa
  /// memastikan setiap orang hanya menulis ke foldernya sendiri.
  Future<String> uploadJpeg({
    required String bucket,
    required String folder,
    required Uint8List bytes,
  }) async {
    final path = _newPath(folder);
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            // Nama file selalu baru (berisi waktu unggah) dan tidak pernah
            // ditimpa, jadi browser & CDN boleh menyimpannya setahun.
            cacheControl: '31536000',
          ),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  /// Menyalin foto dari [fromBucket] ke [toBucket]/[folder] di server
  /// Supabase (fotonya tidak lewat HP), lalu mengembalikan URL publik
  /// salinannya. Dipakai admin untuk menjadikan foto pindai sebagai foto
  /// resep: salinan tetap ada walau pemilik menghapus riwayat atau akunnya.
  Future<String> copyFromPublicUrl({
    required String publicUrl,
    required String fromBucket,
    required String toBucket,
    required String folder,
  }) async {
    final from = pathFromPublicUrl(publicUrl, fromBucket);
    if (from == null) {
      throw ArgumentError.value(publicUrl, 'publicUrl', 'bukan file di bucket $fromBucket');
    }
    final to = _newPath(folder);
    await _client.storage.from(fromBucket).copy(from, to, destinationBucket: toBucket);
    return _client.storage.from(toBucket).getPublicUrl(to);
  }

  /// `https://<ref>.supabase.co/storage/v1/object/public/<bucket>/<path>`
  /// → `<path>`. Null bila URL bukan file publik di [bucket].
  static String? pathFromPublicUrl(String url, String bucket) {
    final marker = '/storage/v1/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i < 0) return null;
    final path = url.substring(i + marker.length).split('?').first;
    return path.isEmpty ? null : Uri.decodeComponent(path);
  }

  static String _newPath(String folder) =>
      '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';

  /// Menghapus semua file di satu folder (dipakai saat hapus akun).
  /// `list` mengembalikan paling banyak 100 file, jadi diulang sampai kosong.
  Future<void> removeFolder({
    required String bucket,
    required String folder,
  }) async {
    final storage = _client.storage.from(bucket);
    while (true) {
      final files = await storage.list(
        path: folder,
        searchOptions: const SearchOptions(limit: 100),
      );
      if (files.isEmpty) return;
      await storage.remove([for (final f in files) '$folder/${f.name}']);
      if (files.length < 100) return;
    }
  }
}
