import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/providers/media_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/thumbnail_image.dart';

/// One media cell: the server thumbnail, plus a play badge for videos.
///
/// Shared by every grid that lists server media — the album detail grid and
/// the library timeline — so a change to how media reads applies to both.
class MediaTile extends ConsumerWidget {
  const MediaTile({required this.item, super.key, this.size = 256});

  final MediaItem item;

  /// Thumbnail rendition to request, in pixels. Grids ask for a small one;
  /// the full-screen viewer asks for the largest the server offers.
  final int size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ThumbnailImage(
      bytes: ref.watch(mediaThumbnailProvider((id: item.id, size: size))),
    );
    if (!item.isVideo) return thumbnail;
    final l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        thumbnail,
        Center(
          child: Semantics(
            label: l10n.mediaVideoLabel,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
