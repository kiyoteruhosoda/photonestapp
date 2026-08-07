import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Renders thumbnail bytes that arrive asynchronously.
///
/// Shared by the album grids (server thumbnails) and the upload grid (device
/// previews): the loading shimmer, the broken-image fallback, and the
/// cross-fade on arrival look the same everywhere.
class ThumbnailImage extends StatelessWidget {
  const ThumbnailImage({
    required this.bytes,
    this.fit = BoxFit.cover,
    super.key,
  });

  /// The bytes as a provider exposes them. A null payload means the source
  /// image is gone (deleted asset, missing thumbnail) and renders the
  /// fallback icon.
  final AsyncValue<Uint8List?> bytes;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (bytes) {
      AsyncData<Uint8List?>(value: final data) when data != null =>
        Image.memory(data, fit: fit, gaplessPlayback: true),
      AsyncData<Uint8List?>() || AsyncError<Uint8List?>() => ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.broken_image_outlined,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      _ => ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    };
  }
}
