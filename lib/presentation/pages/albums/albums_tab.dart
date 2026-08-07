import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/providers/album_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:go_router/go_router.dart';

/// The album grid shown as the home tab of [MainPage].
///
/// Content only — the surrounding Scaffold, header, and navigation belong to
/// the main page.
class AlbumsTab extends ConsumerWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final albums = ref.watch(albumListProvider);

    return switch (albums) {
      AsyncLoading<List<Album>>() => const AppLoadingView(),
      AsyncError<List<Album>>(:final error) => AppErrorView(
        message: error is AppError ? error.message : l10n.commonError,
        onRetry: () => unawaited(ref.read(albumListProvider.notifier).reload()),
      ),
      AsyncData<List<Album>>(value: final items) when items.isEmpty =>
        AppEmptyView(
          message: '${l10n.albumsEmpty}\n${l10n.albumsEmptyHint}',
          icon: Icons.photo_album_outlined,
        ),
      AsyncData<List<Album>>(value: final items) => _AlbumGrid(albums: items),
    };
  }
}

class _AlbumGrid extends ConsumerWidget {
  const _AlbumGrid({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: ref.read(albumListProvider.notifier).reload,
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: AppSpacing.listItemGap,
          crossAxisSpacing: AppSpacing.listItemGap,
          childAspectRatio: 0.85,
        ),
        itemCount: albums.length,
        itemBuilder: (context, index) => _AlbumCard(album: albums[index]),
      ),
    );
  }
}

class _AlbumCard extends ConsumerWidget {
  const _AlbumCard({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cover = album.coverMediaId;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: () =>
          unawaited(context.push<void>(AppRoutes.albumDetailPath(album.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: cover == null
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.photo_album_outlined,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : ThumbnailImage(
                      bytes: ref.watch(
                        mediaThumbnailProvider((id: cover, size: 512)),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            album.title,
            style: theme.textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            l10n.albumsMediaCount(album.mediaCount),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
