import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';
import 'package:flutterbase/presentation/providers/media_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/thumbnail_image.dart';
import 'package:flutterbase/presentation/widgets/ui/video_playback_view.dart';

/// Opens [item] full screen — the player for a video, the still viewer
/// otherwise.
///
/// Shared by every grid that lists server media, so both the album detail
/// grid and the library timeline open media the same way.
Future<void> showMediaViewer(BuildContext context, MediaItem item) {
  return item.isVideo
      ? _showVideo(context, item)
      : _showFullImage(context, item);
}

/// Full-screen preview using the largest thumbnail rendition the server
/// offers. Tapping anywhere dismisses it.
Future<void> _showFullImage(BuildContext context, MediaItem item) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Consumer(
          builder: (context, ref, _) => InteractiveViewer(
            child: Center(
              child: ThumbnailImage(
                bytes: ref.watch(
                  mediaThumbnailProvider((id: item.id, size: 2048)),
                ),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Full-screen player. The signed streaming URL is requested on open — it
/// expires in minutes, so caching one would only serve dead links.
Future<void> _showVideo(BuildContext context, MediaItem item) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Consumer(
              builder: (context, ref, _) {
                final l10n = AppLocalizations.of(context);
                final source = ref.watch(mediaPlaybackSourceProvider(item.id));
                return switch (source) {
                  AsyncData<MediaPlaybackSource>(value: final value) =>
                    VideoPlaybackView(url: value.url),
                  AsyncError<MediaPlaybackSource>(:final error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.pageMargin),
                      child: Text(
                        describePlaybackError(error, l10n),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                };
              },
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            left: AppSpacing.xs,
            child: IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
