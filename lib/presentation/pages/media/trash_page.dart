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
        AsyncLoading<List<MediaItem>>() => const AppLoadingView(),
        AsyncError<List<MediaItem>>(:final error) => AppErrorView(
          message: describeLoadError(error, l10n),
          onRetry: () =>
              unawaited(ref.read(trashedMediaProvider.notifier).reload()),
        ),
        AsyncData<List<MediaItem>>(value: final items) when items.isEmpty =>
          AppEmptyView(message: l10n.trashEmpty, icon: Icons.delete_outline),
        AsyncData<List<MediaItem>>(value: final items) => RefreshIndicator(
          onRefresh: ref.read(trashedMediaProvider.notifier).reload,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _TrashRow(item: items[index]),
          ),
        ),
      },
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
