import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';
import 'package:flutterbase/presentation/providers/media_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

/// The photos tab: everything on the server in capture order, grouped by
/// the day it was taken, paged in as it scrolls.
///
/// The album tabs only reach curated subsets; media that was never put in an
/// album is reachable only from here.
class MediaTab extends ConsumerWidget {
  const MediaTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryMediaProvider);
    return switch (library) {
      AsyncLoading<LibraryMediaState>() => const AppLoadingView(),
      AsyncError<LibraryMediaState>(:final error) => AppErrorView(
        message: describeLoadError(error, l10n),
        onRetry: () =>
            unawaited(ref.read(libraryMediaProvider.notifier).reload()),
      ),
      AsyncData<LibraryMediaState>(value: final value)
          when value.media.isEmpty =>
        AppEmptyView(message: l10n.photosEmpty, icon: Icons.photo_outlined),
      AsyncData<LibraryMediaState>(value: final value) => _Timeline(
        state: value,
      ),
    };
  }
}

/// The scrolling body: one section per capture day, newest first.
class _Timeline extends ConsumerWidget {
  const _Timeline({required this.state});

  final LibraryMediaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = groupMediaByCaptureDay(state.media);
    return RefreshIndicator(
      onRefresh: ref.read(libraryMediaProvider.notifier).reload,
      child: CustomScrollView(
        slivers: [
          for (final group in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageMargin,
                  AppSpacing.lg,
                  AppSpacing.pageMargin,
                  AppSpacing.sm,
                ),
                child: Text(
                  _formatDay(context, group.day),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageMargin,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  mainAxisSpacing: AppSpacing.xs,
                  crossAxisSpacing: AppSpacing.xs,
                ),
                itemCount: group.media.length,
                itemBuilder: (context, index) {
                  final item = group.media[index];
                  return InkWell(
                    onTap: () => unawaited(showMediaViewer(context, item)),
                    child: MediaTile(item: item),
                  );
                },
              ),
            ),
          ],
          SliverToBoxAdapter(child: _Tail(state: state)),
        ],
      ),
    );
  }

  /// The capture day as the reader's locale writes it. [day] is already the
  /// local calendar day — see [groupMediaByCaptureDay].
  static String _formatDay(BuildContext context, DateTime? day) {
    final l10n = AppLocalizations.of(context);
    if (day == null) return l10n.photosUndatedSection;
    return MaterialLocalizations.of(context).formatFullDate(day);
  }
}

/// One capture day's worth of media, in the order the server listed them.
final class MediaCaptureDay {
  const MediaCaptureDay({required this.day, required this.media});

  /// Midnight of the local calendar day, or null for media the server has
  /// no capture instant for.
  final DateTime? day;

  final List<MediaItem> media;
}

/// Splits [media] into consecutive runs that share a local capture day.
///
/// Runs rather than a regrouping: the server already ordered the list by
/// capture instant, so consecutive items of the same day are exactly one
/// section — and media whose day is unknown lands in its own run instead of
/// being silently folded into a neighbour.
///
/// The instants are UTC; the day is taken after converting to the device's
/// zone, so a photo taken at 23:00 local sits under the day the user
/// remembers rather than the next one.
List<MediaCaptureDay> groupMediaByCaptureDay(List<MediaItem> media) {
  final groups = <MediaCaptureDay>[];
  for (final item in media) {
    final shotAt = item.shotAt?.toLocal();
    final day = shotAt == null
        ? null
        : DateTime(shotAt.year, shotAt.month, shotAt.day);
    if (groups.isNotEmpty && groups.last.day == day) {
      groups.last.media.add(item);
      continue;
    }
    groups.add(MediaCaptureDay(day: day, media: <MediaItem>[item]));
  }
  return groups;
}

/// The strip under the last section: a spinner while the next page loads, a
/// retry after a failure, nothing once the library is fully read.
///
/// Building it is also the load trigger — it only comes into existence when
/// the reader has scrolled past everything loaded so far.
class _Tail extends ConsumerWidget {
  const _Tail({required this.state});

  final LibraryMediaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!state.hasMore) return const SizedBox(height: AppSpacing.lg);
    final l10n = AppLocalizations.of(context);
    if (state.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Center(
          child: TextButton.icon(
            onPressed: () =>
                unawaited(ref.read(libraryMediaProvider.notifier).loadMore()),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.photosLoadMoreRetry),
          ),
        ),
      );
    }
    // Scheduled, because notifying a provider during build is not allowed.
    unawaited(
      Future<void>.microtask(
        () => ref.read(libraryMediaProvider.notifier).loadMore(),
      ),
    );
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.pageMargin),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
