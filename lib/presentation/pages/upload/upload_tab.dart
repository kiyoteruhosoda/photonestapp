import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/application/usecases/upload/list_device_albums_usecase.dart';
import 'package:photonest/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:photonest/domain/entities/upload_failure.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/upload_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

/// The upload tab: the auto-upload switch and a grid of recent device
/// photos to upload by hand.
class UploadTab extends ConsumerStatefulWidget {
  const UploadTab({super.key});

  @override
  ConsumerState<UploadTab> createState() => _UploadTabState();
}

class _UploadTabState extends ConsumerState<UploadTab> {
  /// Local ids the user has ticked for manual upload.
  final Set<String> _selected = <String>{};

  Future<void> _toggleAuto(bool enabled) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final effective = await ref
        .read(autoUploadEnabledProvider.notifier)
        .setEnabled(enabled);
    if (enabled && !effective) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.uploadAutoDenied)));
    }
  }

  Future<void> _toggleUnmeteredOnly(bool unmeteredOnly) {
    return ref
        .read(autoUploadUnmeteredOnlyProvider.notifier)
        .setUnmeteredOnly(unmeteredOnly);
  }

  /// Opens the backup-target chooser and persists what comes back.
  ///
  /// A dialog rather than a screen: narrowing the target is something you do
  /// once, from the switch it qualifies, and a pushed route would put a
  /// back-stack entry between the reader and their photos.
  Future<void> _chooseBackupAlbums() async {
    final current = ref.read(backupAlbumsProvider);
    // Re-read the device every time: an album created since the last visit
    // must be pickable without restarting the app.
    ref.invalidate(deviceAlbumsProvider);
    final chosen = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) =>
          _BackupAlbumsDialog(initialSelection: current),
    );
    if (chosen == null) return;
    await ref.read(backupAlbumsProvider.notifier).setAlbumIds(chosen);
  }

  Future<void> _uploadSelected(List<UploadCandidate> candidates) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final photos = candidates
        .where((candidate) => _selected.contains(candidate.photo.localId))
        .map((candidate) => candidate.photo)
        .toList();
    if (photos.isEmpty) return;

    final result = await ref.read(uploadRunProvider.notifier).start(photos);
    if (!mounted) return;
    setState(() {
      _selected.removeAll(result.uploaded.map((photo) => photo.localId));
    });
    final message = [
      if (result.cancelled) l10n.uploadCancelled,
      if (result.uploaded.isNotEmpty || !result.cancelled)
        l10n.uploadDone(result.uploaded.length),
      if (result.hasFailures) l10n.uploadFailed(result.failed.length),
    ].join(' ');
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showFailures(List<UploadFailure> failures) {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.uploadFailureListTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: failures.length,
            itemBuilder: (context, index) {
              final failure = failures[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.broken_image_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  failure.photo.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    describeRecordedFailure(failure.reason, l10n),
                    // A count that keeps climbing is what separates "the
                    // next pass will fix it" from "this will never work".
                    if (failure.attempts > 1)
                      l10n.uploadFailureAttempts(failure.attempts),
                    if (failure.automatic) l10n.uploadFailureAutomatic,
                  ].join(' · '),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidates = ref.watch(uploadCandidatesProvider);
    final autoEnabled = ref.watch(autoUploadEnabledProvider);
    final unmeteredOnly = ref.watch(autoUploadUnmeteredOnlyProvider);
    final backupAlbums = ref.watch(backupAlbumsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageMargin,
            AppSpacing.pageMargin,
            AppSpacing.pageMargin,
            0,
          ),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: autoEnabled,
                  onChanged: (enabled) => unawaited(_toggleAuto(enabled)),
                  secondary: Icon(
                    Icons.cloud_upload_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    l10n.uploadAutoTitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    l10n.uploadAutoSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.componentPadding,
                    vertical: AppSpacing.xs,
                  ),
                ),
                // Disabled rather than hidden while auto-upload is off: the
                // choice is still persisted, and hiding it would make the
                // switch appear to change meaning between visits.
                SwitchListTile(
                  value: unmeteredOnly,
                  onChanged: autoEnabled
                      ? (value) => unawaited(_toggleUnmeteredOnly(value))
                      : null,
                  secondary: Icon(
                    Icons.wifi_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    l10n.uploadAutoUnmeteredTitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    l10n.uploadAutoUnmeteredSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.componentPadding,
                    vertical: AppSpacing.xs,
                  ),
                ),
                // Disabled the same way the Wi-Fi switch is, and for the
                // same reason: the choice is persisted either way.
                ListTile(
                  enabled: autoEnabled,
                  onTap: autoEnabled
                      ? () => unawaited(_chooseBackupAlbums())
                      : null,
                  leading: Icon(
                    Icons.photo_album_outlined,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  title: Text(
                    l10n.uploadAutoAlbumsTitle,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  subtitle: Text(
                    backupAlbums.isEmpty
                        ? l10n.uploadAutoAlbumsAll
                        : l10n.uploadAutoAlbumsCount(backupAlbums.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.componentPadding,
                    vertical: AppSpacing.xs,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: switch (candidates) {
            AsyncLoading<UploadCandidates>() => const AppLoadingView(),
            AsyncError<UploadCandidates>(:final error) => AppErrorView(
              message: describeLoadError(error, l10n),
              onRetry: () => unawaited(
                ref.read(uploadCandidatesProvider.notifier).reload(),
              ),
            ),
            AsyncData<UploadCandidates>(value: final value)
                when !value.accessGranted =>
              AppEmptyView(
                message:
                    '${l10n.uploadPermissionTitle}\n'
                    '${l10n.uploadPermissionBody}',
                icon: Icons.no_photography_outlined,
                actionLabel: l10n.uploadPermissionRetry,
                action: () => unawaited(
                  ref.read(uploadCandidatesProvider.notifier).reload(),
                ),
              ),
            AsyncData<UploadCandidates>(value: final value)
                when value.photos.isEmpty =>
              AppEmptyView(
                message: l10n.uploadEmpty,
                icon: Icons.photo_outlined,
              ),
            AsyncData<UploadCandidates>(value: final value) => _buildGrid(
              value.photos,
            ),
          },
        ),
      ],
    );
  }

  Widget _buildGrid(List<UploadCandidate> candidates) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageMargin,
          ),
          child: AppSectionHeader(
            title: l10n.uploadRecentSection,
            subtitle: _selected.isEmpty
                ? null
                : l10n.uploadSelectedCount(_selected.length),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ref.read(uploadCandidatesProvider.notifier).reload,
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.pageMargin),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: AppSpacing.xs,
                crossAxisSpacing: AppSpacing.xs,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, index) =>
                  _buildTile(candidates[index], l10n),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pageMargin),
          child: _buildRunControls(candidates, l10n),
        ),
      ],
    );
  }

  /// The area under the grid: a progress bar with a cancel button while a
  /// batch runs, otherwise the failure summary of the last run (when there
  /// is one) above the upload button.
  Widget _buildRunControls(
    List<UploadCandidate> candidates,
    AppLocalizations l10n,
  ) {
    final run = ref.watch(uploadRunProvider);
    if (run.running) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Driven by bytes, not by settled photos: one long video would
          // otherwise hold the bar still for minutes and read as frozen.
          LinearProgressIndicator(value: run.fraction),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.uploadProgress(run.completed, run.total),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (run.fileName.isNotEmpty)
                      Text(
                        run.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: ref.read(uploadRunProvider.notifier).cancel,
                child: Text(l10n.uploadCancel),
              ),
            ],
          ),
        ],
      );
    }

    // Read from the store rather than from the last run: a failure that
    // happened in a background pass, or before the app was last closed, is
    // exactly the one the reader has no other way of seeing.
    final failures = switch (ref.watch(uploadFailuresProvider)) {
      AsyncData<List<UploadFailure>>(:final value) => value,
      _ => const <UploadFailure>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failures.isNotEmpty) ...[
          _FailureSummary(
            count: failures.length,
            onShowDetails: () => unawaited(_showFailures(failures)),
            onDismiss: () => unawaited(
              ref.read(uploadFailuresProvider.notifier).dismissAll(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppPrimaryButton(
          label: l10n.uploadSubmit,
          onPressed: _selected.isEmpty
              ? null
              : () => unawaited(_uploadSelected(candidates)),
        ),
      ],
    );
  }

  Widget _buildTile(UploadCandidate candidate, AppLocalizations l10n) {
    final localId = candidate.photo.localId;
    final selected = _selected.contains(localId);
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: candidate.alreadyUploaded
          ? null
          : () => setState(() {
              if (!_selected.remove(localId)) _selected.add(localId);
            }),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ThumbnailImage(bytes: ref.watch(localThumbnailProvider(localId))),
          if (candidate.photo.isVideo)
            Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Semantics(
                  label: l10n.mediaVideoLabel,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          if (candidate.alreadyUploaded)
            ColoredBox(
              color: colorScheme.surface.withValues(alpha: 0.6),
              child: Tooltip(
                message: l10n.uploadUploadedBadge,
                child: Icon(
                  Icons.cloud_done_outlined,
                  color: colorScheme.primary,
                ),
              ),
            )
          else if (selected)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.check_circle, color: colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Picks which device albums automatic upload reads.
///
/// Pops the chosen album ids, or null when dismissed. An empty set means
/// the whole library — the same shape the settings store keeps, so nothing
/// downstream has to translate "all".
class _BackupAlbumsDialog extends ConsumerStatefulWidget {
  const _BackupAlbumsDialog({required this.initialSelection});

  final Set<String> initialSelection;

  @override
  ConsumerState<_BackupAlbumsDialog> createState() =>
      _BackupAlbumsDialogState();
}

class _BackupAlbumsDialogState extends ConsumerState<_BackupAlbumsDialog> {
  late bool _wholeLibrary = widget.initialSelection.isEmpty;
  late final Set<String> _selected = {...widget.initialSelection};

  /// Nothing ticked while the whole-library option is off would silently
  /// mean "everything" once saved, which is the opposite of what the reader
  /// just did. Saving is blocked instead.
  bool get _canSave => _wholeLibrary || _selected.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final choices = ref.watch(deviceAlbumsProvider);

    return AlertDialog(
      title: Text(l10n.uploadAutoAlbumsDialogTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: switch (choices) {
          AsyncLoading<DeviceAlbumChoices>() => const AppLoadingView(),
          AsyncError<DeviceAlbumChoices>(:final error) => AppErrorView(
            message: describeLoadError(error, l10n),
            onRetry: () =>
                unawaited(ref.read(deviceAlbumsProvider.notifier).reload()),
          ),
          AsyncData<DeviceAlbumChoices>(value: final value)
              when !value.accessGranted =>
            AppEmptyView(
              message:
                  '${l10n.uploadPermissionTitle}\n'
                  '${l10n.uploadPermissionBody}',
              icon: Icons.no_photography_outlined,
              actionLabel: l10n.uploadPermissionRetry,
              action: () =>
                  unawaited(ref.read(deviceAlbumsProvider.notifier).reload()),
            ),
          AsyncData<DeviceAlbumChoices>(value: final value) => _buildChoices(
            value,
            l10n,
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.uploadCancel),
        ),
        TextButton(
          onPressed: _canSave
              ? () => Navigator.of(
                  context,
                ).pop(_wholeLibrary ? const <String>{} : _selected)
              : null,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }

  Widget _buildChoices(DeviceAlbumChoices choices, AppLocalizations l10n) {
    return ListView(
      shrinkWrap: true,
      children: [
        SwitchListTile(
          value: _wholeLibrary,
          onChanged: (value) => setState(() => _wholeLibrary = value),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.uploadAutoAlbumsAllOption),
          // Says out loud what "everything" costs: screen recordings and
          // received videos go up too, which is the surprise this whole
          // choice exists to remove.
          subtitle: Text(l10n.uploadAutoAlbumsAllOptionSubtitle),
        ),
        const Divider(),
        if (choices.albums.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(l10n.uploadAutoAlbumsEmpty),
          )
        else
          for (final album in choices.albums)
            CheckboxListTile(
              // Greyed out rather than hidden while the whole-library option
              // is on: the ticks are still there when it goes back off.
              enabled: !_wholeLibrary,
              value: _selected.contains(album.id),
              onChanged: _wholeLibrary
                  ? null
                  : (checked) => setState(() {
                      if (checked ?? false) {
                        _selected.add(album.id);
                      } else {
                        _selected.remove(album.id);
                      }
                    }),
              contentPadding: EdgeInsets.zero,
              title: Text(
                album.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(l10n.uploadAutoAlbumsItemCount(album.itemCount)),
            ),
        if (!_canSave)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l10n.uploadAutoAlbumsPickOne,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ),
      ],
    );
  }

  ColorScheme get colorScheme => Theme.of(context).colorScheme;
}

/// One-line recap of the last batch's failures, with the way into the
/// per-photo list and a dismiss control.
class _FailureSummary extends StatelessWidget {
  const _FailureSummary({
    required this.count,
    required this.onShowDetails,
    required this.onDismiss,
  });

  final int count;
  final VoidCallback onShowDetails;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.error_outline, color: colorScheme.error),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            l10n.uploadFailed(count),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        TextButton(
          onPressed: onShowDetails,
          child: Text(l10n.uploadShowFailures),
        ),
        IconButton(
          onPressed: onDismiss,
          tooltip: l10n.commonClose,
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
