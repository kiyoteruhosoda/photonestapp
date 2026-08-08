import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/media/get_media_playback_usecase.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/application/usecases/media/list_library_media_usecase.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/entities/media_library_page.dart';
import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/session_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────
//
// One provider per use case, overridden by the composition root.

final Provider<GetMediaThumbnailUseCase> getMediaThumbnailUseCaseProvider =
    Provider<GetMediaThumbnailUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getMediaThumbnailUseCaseProvider'),
      );
    });

final Provider<GetMediaPlaybackUseCase> getMediaPlaybackUseCaseProvider =
    Provider<GetMediaPlaybackUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getMediaPlaybackUseCaseProvider'),
      );
    });

final Provider<ListLibraryMediaUseCase> listLibraryMediaUseCaseProvider =
    Provider<ListLibraryMediaUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('listLibraryMediaUseCaseProvider'),
      );
    });

// ─── Thumbnails and playback ───────────────────────────────────────────────

/// Cache key for one server-side thumbnail.
typedef MediaThumbnailRequest = ({MediaId id, int size});

/// Server thumbnail bytes, cached per (media, size).
///
/// A family provider is the in-memory cache: every grid tile watching the
/// same media id shares one fetch, and navigating back to a screen reuses
/// the bytes instead of re-downloading them. The use case behind it feeds
/// the persistent cache, which is what survives a restart and serves
/// offline reads.
final mediaThumbnailProvider =
    FutureProvider.family<Uint8List, MediaThumbnailRequest>((ref, request) {
      // Media ids are only unique per server, so cached bytes must not
      // survive an identity change.
      ref.watch(sessionIdentityProvider);
      return ref
          .read(getMediaThumbnailUseCaseProvider)
          .execute(request.id, size: request.size);
    });

/// A fresh streaming source for one video.
///
/// Deliberately not kept alive: signed URLs expire in minutes, so the
/// player asks again each time it opens instead of caching a dead link.
final mediaPlaybackSourceProvider = FutureProvider.autoDispose
    .family<MediaPlaybackSource, MediaId>((ref, id) {
      ref.watch(sessionIdentityProvider);
      return ref.read(getMediaPlaybackUseCaseProvider).execute(id);
    });

// ─── Library timeline ──────────────────────────────────────────────────────

/// How many media items each timeline page requests.
const int libraryMediaPageSize = 100;

/// What the library timeline renders: the media read so far, plus how far
/// along the paging is.
final class LibraryMediaState {
  const LibraryMediaState({
    required this.media,
    required this.hasMore,
    this.pagesLoaded = 1,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  /// Media accumulated across the pages read so far, newest capture first.
  ///
  /// May be shorter than `pagesLoaded × page size`: the library is written
  /// to while it is being read, so overlapping pages are deduplicated on
  /// append.
  final List<MediaItem> media;

  /// Whether the server said it holds media beyond what [media] covers.
  final bool hasMore;

  /// How many pages have been fetched. The next request is always
  /// `pagesLoaded + 1` — deriving the page from [media]'s length would
  /// re-request the same page forever once deduplication shortened it.
  final int pagesLoaded;

  /// True while the next page is being fetched.
  final bool loadingMore;

  /// True when the most recent load-more attempt failed; the tail tile
  /// offers the retry.
  final bool loadMoreFailed;

  LibraryMediaState copyWith({
    List<MediaItem>? media,
    bool? hasMore,
    int? pagesLoaded,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return LibraryMediaState(
      media: media ?? this.media,
      hasMore: hasMore ?? this.hasMore,
      pagesLoaded: pagesLoaded ?? this.pagesLoaded,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// The whole library in capture order, paged in as the timeline scrolls.
final AsyncNotifierProvider<LibraryMediaNotifier, LibraryMediaState>
libraryMediaProvider =
    AsyncNotifierProvider<LibraryMediaNotifier, LibraryMediaState>(
      LibraryMediaNotifier.new,
    );

/// Pages the library in from the server.
class LibraryMediaNotifier extends AsyncNotifier<LibraryMediaState> {
  @override
  Future<LibraryMediaState> build() async {
    // Rebuilds when the signed-in identity changes, so a login to another
    // account or server never shows the previous identity's media.
    ref.watch(sessionIdentityProvider);
    final page = await ref
        .read(listLibraryMediaUseCaseProvider)
        .execute(page: 1, pageSize: libraryMediaPageSize);
    return LibraryMediaState(media: page.items, hasMore: _holdsMore(page));
  }

  /// Re-reads the library from the first page, e.g. after a pull-to-refresh.
  Future<void> reload() async {
    state = const AsyncValue<LibraryMediaState>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Fetches the next page and appends it. A no-op while a fetch is already
  /// running and once everything is loaded.
  ///
  /// A failed fetch flags the state instead of throwing: the loaded grid
  /// stays on screen, and the tail tile offers the retry.
  Future<void> loadMore() async {
    // `value` is null while loading and on error — both states where there
    // is nothing to append to.
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncValue.data(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );

    final nextPage = current.pagesLoaded + 1;
    final MediaLibraryPage page;
    try {
      page = await ref
          .read(listLibraryMediaUseCaseProvider)
          .execute(page: nextPage, pageSize: libraryMediaPageSize);
    } on Object {
      state = AsyncValue.data(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
      return;
    }
    // Appending by id keeps the list stable when media was added or removed
    // between page reads — a duplicate would render the same tile twice.
    final known = current.media.map((MediaItem item) => item.id).toSet();
    state = AsyncValue.data(
      current.copyWith(
        media: [
          ...current.media,
          ...page.items.where((item) => !known.contains(item.id)),
        ],
        hasMore: _holdsMore(page),
        pagesLoaded: nextPage,
        loadingMore: false,
        // `current` was captured before the flag was cleared, so a retry
        // that succeeded would otherwise keep showing the retry tile.
        loadMoreFailed: false,
      ),
    );
  }

  /// A short page is the server saying "no more", whatever `hasNext` claims —
  /// the flag is computed per request and drifts while media is deleted
  /// mid-paging, and trusting a stale one would request empty pages forever.
  static bool _holdsMore(MediaLibraryPage page) =>
      page.hasNext && page.items.length >= libraryMediaPageSize;
}
