import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/album_media_item.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

/// One album's media grid. The route's deep-link target.
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
          AsyncData<AlbumDetail?>(value: final value) when value != null =>
            value.album.title,
          _ => l10n.albumsTitle,
        },
      ),
      body: switch (detail) {
        AsyncLoading<AlbumDetail?>() => const AppLoadingView(),
        AsyncError<AlbumDetail?>(:final error) => AppErrorView(
          message: describeLoadError(error, l10n),
          onRetry: () => ref.invalidate(albumDetailProvider(albumId)),
        ),
        AsyncData<AlbumDetail?>(value: final value) when value == null =>
          _NotFound(l10n: l10n),
        AsyncData<AlbumDetail?>(value: final value) when value!.media.isEmpty =>
          AppEmptyView(message: l10n.albumEmpty, icon: Icons.photo_outlined),
        AsyncData<AlbumDetail?>(value: final value) => _MediaGrid(
          media: value!.media,
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
  const _MediaGrid({required this.media});

  final List<AlbumMediaItem> media;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: AppSpacing.xs,
        crossAxisSpacing: AppSpacing.xs,
      ),
      itemCount: media.length,
      itemBuilder: (context, index) {
        final item = media[index];
        return InkWell(
          onTap: () => unawaited(_showFullImage(context, ref, item)),
          child: ThumbnailImage(
            bytes: ref.watch(mediaThumbnailProvider((id: item.id, size: 256))),
          ),
        );
      },
    );
  }

  /// Full-screen preview using the largest thumbnail rendition the server
  /// offers. Tapping anywhere dismisses it.
  static Future<void> _showFullImage(
    BuildContext context,
    WidgetRef ref,
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
}
