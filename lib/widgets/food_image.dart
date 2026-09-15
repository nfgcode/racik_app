import 'package:flutter/material.dart';

/// Gambar makanan dari URL, dengan pengganti bila URL kosong atau gagal.
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
          : Image.network(
              url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              // Gambar dekoratif: nama makanan sudah dibacakan di sebelahnya.
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}
