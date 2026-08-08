import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          onTap: () => unawaited(
            showMediaViewer(context, items: media, initialIndex: index),
          ),
          child: MediaTile(item: item),
        );
      },
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
