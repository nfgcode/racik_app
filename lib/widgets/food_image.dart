import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Gambar makanan dari URL, dengan pengganti bila URL kosong atau gagal.
///
/// Memakai cached_network_image: gambar yang sudah pernah diunduh disimpan
/// di penyimpanan HP, jadi tidak diunduh ulang walau aplikasi ditutup.
/// Di web, penyimpanannya diserahkan ke cache browser.
class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.url,
    this.size,
    this.borderRadius = 12,
  });

  final String? url;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.restaurant,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: (url?.isEmpty ?? true)
          ? placeholder
          // Gambar dekoratif: nama makanan sudah dibacakan di sebelahnya.
          : ExcludeSemantics(
              child: CachedNetworkImage(
                imageUrl: url!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
            ),
    );
  }
}
