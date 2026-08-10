import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/value_objects/media_permission.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/album_picker.dart';
import 'package:photonest/presentation/widgets/ui/media_tag_editor.dart';
import 'package:photonest/presentation/widgets/ui/thumbnail_image.dart';
import 'package:photonest/presentation/widgets/ui/video_playback_view.dart';

/// Opens [items] full screen at [initialIndex], swipeable to the neighbours.
///
/// Shared by every grid that lists server media, so the album detail grid
/// and the library timeline browse media the same way. The list handed in is
/// the one the reader was just looking at, which is what makes "the next
/// photo" mean the next tile rather than the next id on the server.
Future<void> showMediaViewer(
  BuildContext context, {
  required List<MediaItem> items,
  required int initialIndex,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        _MediaViewer(items: items, initialIndex: initialIndex),
  );
}

class _MediaViewer extends ConsumerStatefulWidget {
  const _MediaViewer({required this.items, required this.initialIndex});

  final List<MediaItem> items;
  final int initialIndex;

  @override
  ConsumerState<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends ConsumerState<_MediaViewer> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// The list as this viewer shows it.
  ///
  /// A copy of what was handed in, because curation changes it in place: a
  /// favourite mark has to repaint the icon, and a delete has to drop the
  /// page. The caller's list belongs to the grid that opened the viewer.
  late List<MediaItem> _items = List.of(widget.items);

  /// Media the reader asked to see at full resolution.
  ///
  /// Tracked per item rather than as one flag for the viewer: swiping on
  /// should go back to the cheap rendition, and swiping back to a photo
  /// already opened at full size should not silently downgrade it.
  final Set<MediaItem> _showingOriginal = <MediaItem>{};

  /// True while a save is running — the action disables itself so a double
  /// tap does not download the same original twice.
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  MediaItem get _current => _items[_index];

  /// Flips the favourite mark, showing the server's answer.
  Future<void> _toggleFavorite() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final item = _current;
    final settled = await ref
        .read(mediaCurationProvider.notifier)
        .toggleFavorite(item);
    if (!mounted) return;
    if (settled == null) {
      ref.read(mediaCurationProvider.notifier).acknowledgeFailure();
      messenger.showSnackBar(SnackBar(content: Text(l10n.mediaFavoriteFailed)));
      return;
    }
    setState(() {
      _items = [
        for (final each in _items)
          if (each.id == item.id) each.withFavorite(settled) else each,
      ];
    });
  }

  /// Moves the media to the trash after the reader confirms.
  Future<void> _moveToTrash() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final item = _current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.mediaMoveToTrashConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.mediaMoveToTrash),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final moved = await ref
        .read(mediaCurationProvider.notifier)
        .moveToTrash(item);
    if (!mounted) return;
    if (!moved) {
      ref.read(mediaCurationProvider.notifier).acknowledgeFailure();
      messenger.showSnackBar(SnackBar(content: Text(l10n.mediaTrashFailed)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.mediaMovedToTrash)));
    final remaining = [
      for (final each in _items)
        if (each.id != item.id) each,
    ];
    // Nothing left to look at — the viewer has no subject any more.
    if (remaining.isEmpty) {
      navigator.pop();
      return;
    }
    setState(() {
      _items = remaining;
      // Deleting the last page steps back rather than off the end.
      if (_index >= remaining.length) _index = remaining.length - 1;
      _pages.jumpToPage(_index);
    });
  }

  /// Opens the tag editor for the media on screen.
  ///
  /// Nothing on this page depends on the result: tags are not drawn on the
  /// image or in the bar, and the editor has already shown the reader the set
  /// the server settled on. Awaited only so a second tap cannot stack two
  /// sheets.
  Future<void> _editTags() async {
    await showMediaTagEditor(context, id: _current.id);
  }

  /// Opens the album picker for the media on screen.
  ///
  /// Nothing here depends on the result: the sheet has already told the
  /// reader which album the photo went into, and the viewer draws nothing
  /// about album membership. Awaited only so a second tap cannot stack two
  /// sheets.
  Future<void> _addToAlbum() async {
    await showAlbumPicker(context, mediaId: _current.id);
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final item = _current;
    setState(() => _saving = true);
    final SaveMediaFailure? failure;
    try {
      failure = await ref
          .read(saveMediaOriginalUseCaseProvider)
          .execute(item.id, fileName: item.filename, isVideo: item.isVideo);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? l10n.mediaSaveDone
              : describeSaveFailure(failure, l10n),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final curating = ref.watch(mediaCurationProvider);
    final permissions = ref.watch(grantedPermissionsProvider);
    final item = _current;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              itemCount: _items.length,
              onPageChanged: (page) => setState(() => _index = page),
              itemBuilder: (context, page) {
                final pageItem = _items[page];
                return pageItem.isVideo
                    ? _VideoPage(item: pageItem)
                    : _ImagePage(
                        item: pageItem,
                        original: _showingOriginal.contains(pageItem),
                      );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ViewerBar(
              position: l10n.mediaViewerPosition(_index + 1, _items.length),
              isFavorite: item.isFavorite,
              busy: curating.isBusy(item.id),
              // Null where the session holds no permission for the call
              // behind the button, which drops the button from the bar.
              // Dropped rather than disabled: the bar is a row of icons over
              // the photo, and a greyed-out icon there reads as "not yet"
              // instead of "not yours" — the permission does not come back
              // by waiting.
              onToggleFavorite: permissions.allows(MediaPermission.markFavorite)
                  ? () => unawaited(_toggleFavorite())
                  : null,
              onEditTags: permissions.allows(MediaPermission.tagMedia)
                  ? () => unawaited(_editTags())
                  : null,
              // Either permission is enough to be worth opening: the picker
              // hides the "new album" row without `album:create`, and
              // filing into an album that exists needs only `album:edit`.
              onAddToAlbum:
                  permissions.allows(MediaPermission.editAlbum) ||
                      permissions.allows(MediaPermission.createAlbum)
                  ? () => unawaited(_addToAlbum())
                  : null,
              onMoveToTrash: permissions.allows(MediaPermission.trashMedia)
                  ? () => unawaited(_moveToTrash())
                  : null,
              // Videos stream a rendition the player owns, so there is
              // nothing to swap in place; saving is how their untouched file
              // is reached.
              onShowOriginal: item.isVideo || _showingOriginal.contains(item)
                  ? null
                  : () => setState(() => _showingOriginal.add(item)),
              onSave: _saving ? null : () => unawaited(_save()),
              saving: _saving,
            ),
          ),
        ],
      ),
    );
  }
}

/// The translucent strip over the top of the viewer.
class _ViewerBar extends StatelessWidget {
  const _ViewerBar({
    required this.position,
    required this.isFavorite,
    required this.busy,
    required this.onToggleFavorite,
    required this.onEditTags,
    required this.onAddToAlbum,
    required this.onMoveToTrash,
    required this.onShowOriginal,
    required this.onSave,
    required this.saving,
  });

  final String position;
  final bool isFavorite;

  /// True while this item's favourite or trash request is in flight — the
  /// controls disable so a double tap cannot send twice.
  final bool busy;

  /// Null when the session may not mark favourites, which hides the button.
  final VoidCallback? onToggleFavorite;

  /// Opens the tag editor; null when the session may not manage tags. Not
  /// gated on [busy]: tagging is a separate request from the favourite and
  /// trash calls, and the editor sends nothing until the reader saves.
  final VoidCallback? onEditTags;

  /// Opens the album picker; null when the session may neither create
  /// albums nor change the ones that exist. Not gated on [busy] for the
  /// same reason as [onEditTags]: the sheet sends nothing until the reader
  /// picks an album.
  final VoidCallback? onAddToAlbum;

  /// Null when the session may not delete, which hides the button.
  final VoidCallback? onMoveToTrash;
  final VoidCallback? onShowOriginal;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ColoredBox(
      color: Colors.black45,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              tooltip: l10n.commonClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
            Expanded(
              child: Text(
                position,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (onToggleFavorite != null)
              IconButton(
                onPressed: busy ? null : onToggleFavorite,
                tooltip: isFavorite
                    ? l10n.mediaRemoveFavorite
                    : l10n.mediaAddFavorite,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                color: isFavorite ? Colors.redAccent : Colors.white,
                disabledColor: Colors.white38,
              ),
            if (onEditTags != null)
              IconButton(
                onPressed: onEditTags,
                tooltip: l10n.mediaTagsTitle,
                icon: const Icon(Icons.label_outline),
                color: Colors.white,
              ),
            if (onAddToAlbum != null)
              IconButton(
                onPressed: onAddToAlbum,
                tooltip: l10n.albumAddToAlbum,
                icon: const Icon(Icons.playlist_add),
                color: Colors.white,
              ),
            if (onMoveToTrash != null)
              IconButton(
                onPressed: busy ? null : onMoveToTrash,
                tooltip: l10n.mediaMoveToTrash,
                icon: const Icon(Icons.delete_outline),
                color: Colors.white,
                disabledColor: Colors.white38,
              ),
            IconButton(
              onPressed: onShowOriginal,
              tooltip: l10n.mediaShowOriginal,
              icon: const Icon(Icons.hd_outlined),
              color: Colors.white,
              disabledColor: Colors.white38,
            ),
            if (saving)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              IconButton(
                onPressed: onSave,
                tooltip: l10n.mediaSaveToDevice,
                icon: const Icon(Icons.download_outlined),
                color: Colors.white,
                disabledColor: Colors.white38,
              ),
          ],
        ),
      ),
    );
  }
}

/// One still page: the 2048px rendition, or the untouched original once the
/// reader asks for it.
class _ImagePage extends ConsumerWidget {
  const _ImagePage({required this.item, required this.original});

  final MediaItem item;
  final bool original;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!original) {
      return InteractiveViewer(
        child: Center(
          child: ThumbnailImage(
            bytes: ref.watch(mediaThumbnailProvider((id: item.id, size: 2048))),
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    final l10n = AppLocalizations.of(context);
    final source = ref.watch(mediaOriginalSourceProvider(item.id));
    return switch (source) {
      AsyncData<SignedMediaUrl>(value: final value) => InteractiveViewer(
        // Handed to Flutter's own image loader rather than downloaded
        // through the API client first: the URL is signed, so it carries no
        // session, and Image.network streams and caches it — buffering a
        // 50 MB original in Dart would only add a pause before the decode.
        child: Center(
          child: Image.network(
            value.url.toString(),
            fit: BoxFit.contain,
            // Originals are large and arrive over the network, so both the
            // wait and the failure are states the viewer has to draw — the
            // default would show a blank screen and then throw.
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes == null
                          ? null
                          : progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!,
                    ),
                  ),
            errorBuilder: (context, error, stackTrace) =>
                _ViewerMessage(text: l10n.mediaOriginalUnavailable),
          ),
        ),
      ),
      AsyncError<SignedMediaUrl>(:final error) => _ViewerMessage(
        text: describeLoadError(error, l10n),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// One video page. The signed streaming URL is requested on open — it
/// expires in minutes, so caching one would only serve dead links.
class _VideoPage extends ConsumerWidget {
  const _VideoPage({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final source = ref.watch(mediaPlaybackSourceProvider(item.id));
    return switch (source) {
      AsyncData<SignedMediaUrl>(value: final value) => VideoPlaybackView(
        url: value.url,
      ),
      AsyncError<SignedMediaUrl>(:final error) => _ViewerMessage(
        text: describePlaybackError(error, l10n),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// A failure message over the viewer's black backdrop.
class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
