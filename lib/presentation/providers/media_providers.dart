import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/application/usecases/media/get_media_original_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_playback_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/media/list_library_media_usecase.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/providers/app_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';

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

final Provider<GetMediaOriginalUseCase> getMediaOriginalUseCaseProvider =
    Provider<GetMediaOriginalUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getMediaOriginalUseCaseProvider'),
      );
    });

final Provider<SaveMediaOriginalUseCase> saveMediaOriginalUseCaseProvider =
    Provider<SaveMediaOriginalUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('saveMediaOriginalUseCaseProvider'),
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
    .family<SignedMediaUrl, MediaId>((ref, id) {
      ref.watch(sessionIdentityProvider);
      return ref.read(getMediaPlaybackUseCaseProvider).execute(id);
    });

/// A fresh signed URL for one media item's original.
///
/// Like the playback source, deliberately not kept alive: the URL expires in
/// minutes, so the viewer asks again each time the reader opens the original
/// instead of caching a dead link.
final mediaOriginalSourceProvider = FutureProvider.autoDispose
    .family<SignedMediaUrl, MediaId>((ref, id) {
      ref.watch(sessionIdentityProvider);
      return ref.read(getMediaOriginalUseCaseProvider).execute(id);
    });

// ─── Library timeline ──────────────────────────────────────────────────────

/// How many media items each timeline page requests.
const int libraryMediaPageSize = 100;

/// What the library timeline renders: the media read so far, plus how far
/// along the paging is.
final class LibraryMediaState {
  const LibraryMediaState({
    required this.media,
    required this.nextCursor,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  /// Media accumulated across the pages read so far, newest capture first.
  ///
  /// May be shorter than the number of pages read × page size: the library
  /// is written to while it is being read, so overlapping pages are
  /// deduplicated on append.
  final List<MediaItem> media;

  /// Where the next window starts, or null once everything is loaded.
  ///
  /// Cursor (keyset) paging rather than an offset: media is written to the
  /// library while it is being read, and an offset would make the timeline
  /// skip or repeat items around every insert or delete.
  final String? nextCursor;

  /// Whether the server holds media beyond what [media] covers.
  bool get hasMore => nextCursor != null;

  /// True while the next page is being fetched.
  final bool loadingMore;

  /// True when the most recent load-more attempt failed; the tail tile
  /// offers the retry.
  final bool loadMoreFailed;

  /// [nextCursor] is passed through a wrapper so that clearing it (reaching
  /// the end) is expressible — a bare null would mean "keep the old value".
  LibraryMediaState copyWith({
    List<MediaItem>? media,
    ({String? value})? nextCursor,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return LibraryMediaState(
      media: media ?? this.media,
      nextCursor: nextCursor == null ? this.nextCursor : nextCursor.value,
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
  /// Bumped by every (re)build. A page request that was already in flight
  /// when the timeline restarted — a pull-to-refresh, or a sign-in to
  /// another account or server — carries the old number and is discarded,
  /// instead of overwriting the fresh state with media captured before the
  /// `await`. Getting this wrong leaves the previous identity's media on
  /// screen indefinitely.
  int _generation = 0;

  @override
  Future<LibraryMediaState> build() async {
    // Rebuilds when the signed-in identity changes, so a login to another
    // account or server never shows the previous identity's media.
    ref.watch(sessionIdentityProvider);
    _generation++;
    final page = await ref
        .read(listLibraryMediaUseCaseProvider)
        .execute(pageSize: libraryMediaPageSize);
    return LibraryMediaState(media: page.items, nextCursor: page.nextCursor);
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
    final generation = _generation;
    state = AsyncValue.data(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );

    final MediaLibraryPage page;
    try {
      page = await ref
          .read(listLibraryMediaUseCaseProvider)
          .execute(cursor: current.nextCursor, pageSize: libraryMediaPageSize);
    } on Object {
      if (generation != _generation) return;
      state = AsyncValue.data(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
      return;
    }
    if (generation != _generation) return;
    // Appending by id keeps the list stable when media was added or removed
    // between page reads — a duplicate would render the same tile twice.
    final known = current.media.map((MediaItem item) => item.id).toSet();
    state = AsyncValue.data(
      current.copyWith(
        media: [
          ...current.media,
          ...page.items.where((item) => !known.contains(item.id)),
        ],
        nextCursor: (value: page.nextCursor),
        loadingMore: false,
        // `current` was captured before the flag was cleared, so a retry
        // that succeeded would otherwise keep showing the retry tile.
        loadMoreFailed: false,
      ),
    );
  }
}
