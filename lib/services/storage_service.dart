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
    final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from(bucket).getPublicUrl(path);
  }
}
