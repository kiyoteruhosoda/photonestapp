import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/media_permission.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/album_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/album_form.dart';
import 'package:photonest/presentation/widgets/ui/app_state_views.dart';

/// How much of the screen the album list may take before it scrolls.
const double _pickerMaxHeightFraction = 0.6;

/// Opens the "add to album" sheet for [mediaId].
///
/// Returns the album the photo was filed under, or null when the reader
/// closed the sheet without choosing one — so the caller knows whether to
/// say anything.
Future<Album?> showAlbumPicker(
  BuildContext context, {
  required MediaId mediaId,
}) {
  return showModalBottomSheet<Album>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => AlbumPicker(mediaId: mediaId),
  );
}

/// Lists the albums the photo can go into, and offers to make a new one.
///
/// Filing happens on tap rather than behind a Save button: there is exactly
/// one choice to make, and a confirmation step would only add a tap to the
/// path this whole feature exists to shorten.
class AlbumPicker extends ConsumerStatefulWidget {
  const AlbumPicker({required this.mediaId, super.key});

  final MediaId mediaId;

  @override
  ConsumerState<AlbumPicker> createState() => _AlbumPickerState();
}

class _AlbumPickerState extends ConsumerState<AlbumPicker> {
  /// Which album's row is waiting on the server, so only that row shows the
  /// spinner. The notifier's own busy flag says *something* is running; it
  /// does not say which row started it.
  Album? _pending;

  Future<void> _addTo(Album album) async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _pending = album);
    final added = await ref
        .read(albumEditingProvider.notifier)
        .addMedia(album.id, widget.mediaId);
    if (!mounted) return;
    setState(() => _pending = null);
    if (added == null) {
      ref.read(albumEditingProvider.notifier).acknowledgeFailure();
      messenger.showSnackBar(SnackBar(content: Text(l10n.albumAddFailed)));
      return;
    }
    // Reported either way, and worded differently: "already in there" is a
    // success too, and calling it "added" would make the reader wonder
    // whether they have filed it twice.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          added
              ? l10n.albumAddedTo(album.title)
              : l10n.albumAlreadyContains(album.title),
        ),
      ),
    );
    navigator.pop(album);
  }

  Future<void> _createAndAdd() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    // The new album is created *holding* the photo, so nothing else has to
    // run afterwards — one request, and no window where an album exists
    // empty because the second call failed.
    final album = await showAlbumCreateForm(
      context,
      holding: <MediaId>[widget.mediaId],
    );
    if (!mounted || album == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.albumAddedTo(album.title))),
    );
    navigator.pop(album);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final albums = ref.watch(albumListProvider);
    final permissions = ref.watch(grantedPermissionsProvider);
    final maxHeight =
        MediaQuery.sizeOf(context).height * _pickerMaxHeightFraction;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.albumPickerTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (permissions.allows(MediaPermission.createAlbum))
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(l10n.albumPickerNewAlbum),
                onTap: () => unawaited(_createAndAdd()),
              ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: switch (albums) {
                  AsyncLoading<List<Album>>() => const AppLoadingView(),
                  AsyncError<List<Album>>(:final error) => AppErrorView(
                    message: describeLoadError(error, l10n),
                    onRetry: () => unawaited(
                      ref.read(albumListProvider.notifier).reload(),
                    ),
                  ),
                  AsyncData<List<Album>>(value: final items)
                      when items.isEmpty =>
                    AppEmptyView(
                      message: l10n.albumPickerEmpty,
                      icon: Icons.photo_album_outlined,
                    ),
                  AsyncData<List<Album>>(value: final items) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final album in items)
                        ListTile(
                          leading: const Icon(Icons.photo_album_outlined),
                          title: Text(album.title),
                          subtitle: Text(
                            l10n.albumsMediaCount(album.mediaCount),
                          ),
                          // Every row disables while one is running: the
                          // sheet closes on success, so a second tap could
                          // only file the photo somewhere the reader is no
                          // longer looking at.
                          enabled: _pending == null,
                          trailing: _pending == album
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: () => unawaited(_addTo(album)),
                        ),
                    ],
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
