import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/media/save_media_original_usecase.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/entities/signed_media_url.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';
import 'package:flutterbase/presentation/providers/media_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/thumbnail_image.dart';
import 'package:flutterbase/presentation/widgets/ui/video_playback_view.dart';

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

  MediaItem get _current => widget.items[_index];

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
    final item = _current;
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _pages,
              itemCount: widget.items.length,
              onPageChanged: (page) => setState(() => _index = page),
              itemBuilder: (context, page) {
                final pageItem = widget.items[page];
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
              position: l10n.mediaViewerPosition(
                _index + 1,
                widget.items.length,
              ),
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
    required this.onShowOriginal,
    required this.onSave,
    required this.saving,
  });

  final String position;
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
