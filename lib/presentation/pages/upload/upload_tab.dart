import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/providers/upload_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

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
  bool _uploading = false;

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

  Future<void> _uploadSelected(List<UploadCandidate> candidates) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final photos = candidates
        .where((candidate) => _selected.contains(candidate.photo.localId))
        .map((candidate) => candidate.photo)
        .toList();
    if (photos.isEmpty) return;

    setState(() => _uploading = true);
    try {
      final result = await ref
          .read(uploadCandidatesProvider.notifier)
          .upload(photos);
      if (!mounted) return;
      setState(() {
        _selected.removeAll(result.uploaded.map((photo) => photo.localId));
      });
      final message = result.hasFailures
          ? '${l10n.uploadDone(result.uploaded.length)} '
                '${l10n.uploadFailed(result.failed.length)}'
          : l10n.uploadDone(result.uploaded.length);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final candidates = ref.watch(uploadCandidatesProvider);
    final autoEnabled = ref.watch(autoUploadEnabledProvider);

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
            child: SwitchListTile(
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
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Expanded(
          child: switch (candidates) {
            AsyncLoading<UploadCandidates>() => const AppLoadingView(),
            AsyncError<UploadCandidates>(:final error) => AppErrorView(
              message: error is AppError ? error.message : l10n.commonError,
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
          child: _uploading
              ? const Center(child: CircularProgressIndicator())
              : AppPrimaryButton(
                  label: l10n.uploadSubmit,
                  onPressed: _selected.isEmpty
                      ? null
                      : () => unawaited(_uploadSelected(candidates)),
                ),
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
