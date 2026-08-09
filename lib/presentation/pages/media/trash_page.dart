import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

/// Media that was moved to the trash and can still be brought back.
///
/// Deliberately a list rather than a grid: the choice here is "restore this
/// one or leave it", which reads better with the filename next to the
/// thumbnail than as an anonymous tile. Tapping does not open the viewer —
/// the file may already be gone from disk.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final trashed = ref.watch(trashedMediaProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashTitle)),
      body: switch (trashed) {
        AsyncLoading<TrashedMediaState>() => const AppLoadingView(),
        AsyncError<TrashedMediaState>(:final error) => AppErrorView(
          message: describeLoadError(error, l10n),
          onRetry: () =>
              unawaited(ref.read(trashedMediaProvider.notifier).reload()),
        ),
        AsyncData<TrashedMediaState>(value: final value)
            when value.media.isEmpty =>
          AppEmptyView(message: l10n.trashEmpty, icon: Icons.delete_outline),
        AsyncData<TrashedMediaState>(value: final value) => _TrashList(
          state: value,
        ),
      },
    );
  }
}

/// The scrolling list, with the next window read as it reaches the end.
class _TrashList extends ConsumerWidget {
  const _TrashList({required this.state});

  final TrashedMediaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // One extra row while windows remain: building it is also the trigger,
    // so the lazy list only reads on once the reader is near the end.
    final tailRows = state.hasMore ? 1 : 0;
    return RefreshIndicator(
      onRefresh: ref.read(trashedMediaProvider.notifier).reload,
      child: ListView.builder(
        itemCount: state.media.length + tailRows,
        itemBuilder: (context, index) {
          if (index >= state.media.length) {
            return _LoadMoreRow(state: state);
          }
          return _TrashRow(item: state.media[index]);
        },
      ),
    );
  }
}

/// The row after the last deletion while windows remain: a spinner while the
/// next one loads, a retry after a failure.
class _LoadMoreRow extends ConsumerWidget {
  const _LoadMoreRow({required this.state});

  final TrashedMediaState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (state.loadMoreFailed) {
      return ListTile(
        leading: const Icon(Icons.refresh),
        title: Text(l10n.commonRetry),
        onTap: () =>
            unawaited(ref.read(trashedMediaProvider.notifier).loadMore()),
      );
    }
    if (!state.loadingMore) {
      // Reading during build is what makes reaching the end fetch the next
      // window; the notifier ignores a second call while one is running.
      unawaited(
        Future<void>.microtask(
          () => ref.read(trashedMediaProvider.notifier).loadMore(),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: AppSpacing.lg,
          height: AppSpacing.lg,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// One trashed item: its thumbnail, its name, and the way back.
class _TrashRow extends ConsumerWidget {
  const _TrashRow({required this.item});

  final MediaItem item;

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final restored = await ref
        .read(mediaCurationProvider.notifier)
        .restore(item);
    if (!context.mounted) return;
    if (!restored) {
      ref.read(mediaCurationProvider.notifier).acknowledgeFailure();
      messenger.showSnackBar(SnackBar(content: Text(l10n.trashRestoreFailed)));
      return;
    }
    // Drop it here rather than re-reading the trash: the reader is looking
    // at the list, and a reload would jump them back to the top.
    ref.read(trashedMediaProvider.notifier).forget(item.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.trashRestored)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(mediaCurationProvider).isBusy(item.id);
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 56,
        child: ThumbnailImage(
          bytes: ref.watch(mediaThumbnailProvider((id: item.id, size: 256))),
        ),
      ),
      title: Text(item.filename, overflow: TextOverflow.ellipsis),
      subtitle: item.isVideo ? Text(l10n.mediaVideoLabel) : null,
      trailing: busy
          ? const SizedBox(
              width: AppSpacing.lg,
              height: AppSpacing.lg,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => unawaited(_restore(context, ref)),
              child: Text(l10n.trashRestore),
            ),
    );
  }
}
