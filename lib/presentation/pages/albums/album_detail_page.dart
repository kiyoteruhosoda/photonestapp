import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/album_media_item.dart';
import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

/// One album's media grid, paged in from the server as it scrolls. The
/// route's deep-link target.
///
/// [id] is null when the path parameter was not a valid id — links arrive
/// from outside the app, so that renders the not-found state rather than
/// crashing.
class AlbumDetailPage extends ConsumerWidget {
  const AlbumDetailPage({required this.id, super.key});

  final AlbumId? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final albumId = id;
    if (albumId == null) {
      return Scaffold(
        appBar: AppMainHeader(title: l10n.albumsTitle),
        body: _NotFound(l10n: l10n),
      );
    }

    final detail = ref.watch(albumDetailProvider(albumId));
    return Scaffold(
      appBar: AppMainHeader(
        title: switch (detail) {
          AsyncData<AlbumDetailState?>(value: final value) when value != null =>
            value.album.title,
          _ => l10n.albumsTitle,
        },
      ),
      body: switch (detail) {
        AsyncLoading<AlbumDetailState?>() => const AppLoadingView(),
        AsyncError<AlbumDetailState?>(:final error) => AppErrorView(
          message: describeLoadError(error, l10n),
          onRetry: () => ref.invalidate(albumDetailProvider(albumId)),
        ),
        AsyncData<AlbumDetailState?>(value: final value) when value == null =>
          _NotFound(l10n: l10n),
        AsyncData<AlbumDetailState?>(value: final value)
            when value!.media.isEmpty =>
          AppEmptyView(message: l10n.albumEmpty, icon: Icons.photo_outlined),
        AsyncData<AlbumDetailState?>(value: final value) => _MediaGrid(
          albumId: albumId,
          state: value!,
        ),
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      message: '${l10n.albumNotFound}\n${l10n.albumNotFoundHint}',
      icon: Icons.photo_album_outlined,
    );
  }
}

class _MediaGrid extends ConsumerWidget {
  const _MediaGrid({required this.albumId, required this.state});

  final AlbumId albumId;
  final AlbumDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = state.media;
    // One extra slot at the tail while pages remain: it renders the
    // loading/retry tile, and building it is also the load trigger.
    final tailSlots = state.hasMore ? 1 : 0;
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
      ),
      itemCount: media.length + tailSlots,
      itemBuilder: (context, index) {
        if (index >= media.length) {
          return _LoadMoreTile(albumId: albumId, state: state);
        }
        // Nearing the tail is the prefetch signal — scheduled, because
        // notifying a provider during build is not allowed.
        if (state.hasMore &&
            !state.loadMoreFailed &&
            index >= media.length - 12) {
          unawaited(
            Future<void>.microtask(
              () => ref.read(albumDetailProvider(albumId).notifier).loadMore(),
            ),
          );
        }
        final item = media[index];
        return InkWell(
          onTap: () => unawaited(_openMedia(context, item)),
          child: _MediaTile(item: item),
        );
      },
    );
  }

  Future<void> _openMedia(BuildContext context, AlbumMediaItem item) {
    return item.isVideo
        ? _showVideo(context, item)
        : _showFullImage(context, item);
  }

  /// Full-screen preview using the largest thumbnail rendition the server
  /// offers. Tapping anywhere dismisses it.
  static Future<void> _showFullImage(
    BuildContext context,
    AlbumMediaItem item,
  ) {
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

  /// Full-screen player. The signed streaming URL is requested on open —
  /// it expires in minutes, so caching one would only serve dead links.
  static Future<void> _showVideo(BuildContext context, AlbumMediaItem item) {
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
                  final source = ref.watch(
                    mediaPlaybackSourceProvider(item.id),
                  );
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
}

/// One grid cell: the thumbnail, plus a play badge for videos.
class _MediaTile extends ConsumerWidget {
  const _MediaTile({required this.item});

  final AlbumMediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ThumbnailImage(
      bytes: ref.watch(mediaThumbnailProvider((id: item.id, size: 256))),
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

/// The tail cell while more pages remain: a spinner during a fetch, a retry
/// affordance after a failure.
class _LoadMoreTile extends ConsumerWidget {
  const _LoadMoreTile({required this.albumId, required this.state});

  final AlbumId albumId;
  final AlbumDetailState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.loadMoreFailed) {
      final l10n = AppLocalizations.of(context);
      return InkWell(
        onTap: () => unawaited(
          ref.read(albumDetailProvider(albumId).notifier).loadMore(),
        ),
        child: Tooltip(
          message: l10n.albumLoadMoreRetry,
          child: Icon(
            Icons.refresh,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
