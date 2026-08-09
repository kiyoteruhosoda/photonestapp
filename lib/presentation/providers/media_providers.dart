import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/application/usecases/media/curate_media_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_original_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_playback_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/media/list_library_media_usecase.dart';
import 'package:photonest/application/usecases/media/list_trashed_media_usecase.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';
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

final Provider<ListTrashedMediaUseCase> listTrashedMediaUseCaseProvider =
    Provider<ListTrashedMediaUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('listTrashedMediaUseCaseProvider'),
      );
    });

final Provider<CurateMediaUseCase> curateMediaUseCaseProvider =
    Provider<CurateMediaUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('curateMediaUseCaseProvider'),
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

/// How the reader has narrowed the timeline (free text / kind / favourites).
///
/// Separate from [libraryMediaProvider] so that typing in the search field
/// does not itself hold the loaded media: the notifier watches this and
/// rebuilds from the first window whenever it changes.
final NotifierProvider<LibraryMediaQueryNotifier, MediaLibraryQuery>
libraryMediaQueryProvider =
    NotifierProvider<LibraryMediaQueryNotifier, MediaLibraryQuery>(
      LibraryMediaQueryNotifier.new,
    );

/// Holds the narrowing the reader has asked for.
class LibraryMediaQueryNotifier extends Notifier<MediaLibraryQuery> {
  @override
  MediaLibraryQuery build() => const MediaLibraryQuery();

  /// Sets the free-text search. Blank clears it.
  void search(String text) {
    if (state.text == text) return;
    state = state.copyWith(text: text);
  }

  void filterByKind(MediaKindFilter kind) {
    if (state.kind == kind) return;
    state = state.copyWith(kind: kind);
  }

  void showFavoritesOnly(bool favoritesOnly) {
    if (state.favoritesOnly == favoritesOnly) return;
    state = state.copyWith(favoritesOnly: favoritesOnly);
  }

  /// Back to the plain chronological library.
  void clear() {
    if (state.isUnfiltered) return;
    state = const MediaLibraryQuery();
  }
}

/// Applies favourite / trash / restore and keeps the loaded timeline in step.
///
/// Separate from [LibraryMediaNotifier] so the timeline keeps its one job
/// (paging) and this keeps its own (changing one item). It reaches back into
/// the timeline's state rather than reloading it: a reload would lose the
/// reader's scroll position and re-fetch every window they had already read.
final NotifierProvider<MediaCurationNotifier, MediaCurationState>
mediaCurationProvider =
    NotifierProvider<MediaCurationNotifier, MediaCurationState>(
      MediaCurationNotifier.new,
    );

/// What the curation controls need to render: which item is mid-change, and
/// the last failure to report.
final class MediaCurationState {
  const MediaCurationState({this.busyId, this.lastFailure});

  /// The media a request is in flight for, or null when idle. The control
  /// for that item disables itself so a double tap cannot send twice.
  final MediaId? busyId;

  /// The most recent failure, for the caller to show and then clear.
  final Object? lastFailure;

  bool isBusy(MediaId id) => busyId == id;
}

/// Runs the curation calls and writes the result into the loaded timeline.
class MediaCurationNotifier extends Notifier<MediaCurationState> {
  @override
  MediaCurationState build() => const MediaCurationState();

  /// Flips the favourite mark. Returns the state the server settled on, or
  /// null when the call failed.
  Future<bool?> toggleFavorite(MediaItem item) async {
    return _run(item.id, () async {
      final settled = await ref
          .read(curateMediaUseCaseProvider)
          .setFavorite(item.id, favorite: !item.isFavorite);
      _replaceInTimeline(item.id, (current) => current.withFavorite(settled));
      return settled;
    });
  }

  /// Moves the media to the trash and drops it from the timeline.
  Future<bool> moveToTrash(MediaItem item) async {
    final result = await _run(item.id, () async {
      await ref.read(curateMediaUseCaseProvider).moveToTrash(item.id);
      _removeFromTimeline(item.id);
      return true;
    });
    return result ?? false;
  }

  /// Brings the media back out of the trash. The timeline is not touched —
  /// the trash view reloads, and the main timeline picks it up on its next
  /// read rather than guessing where the item belongs in capture order.
  Future<bool> restore(MediaItem item) async {
    final result = await _run(item.id, () async {
      await ref.read(curateMediaUseCaseProvider).restore(item.id);
      return true;
    });
    return result ?? false;
  }

  /// Clears the last failure once the screen has shown it.
  void acknowledgeFailure() {
    if (state.lastFailure == null) return;
    state = MediaCurationState(busyId: state.busyId);
  }

  Future<T?> _run<T>(MediaId id, Future<T> Function() action) async {
    if (state.busyId != null) return null;
    state = MediaCurationState(busyId: id);
    try {
      final result = await action();
      state = const MediaCurationState();
      return result;
    } on Object catch (error) {
      // The failure is state, not an exception to the caller: the screen
      // shows it and the item stays as it was.
      state = MediaCurationState(lastFailure: error);
      return null;
    }
  }

  void _replaceInTimeline(MediaId id, MediaItem Function(MediaItem) update) {
    _updateTimeline(
      (media) => [
        for (final item in media)
          if (item.id == id) update(item) else item,
      ],
    );
  }

  void _removeFromTimeline(MediaId id) {
    _updateTimeline(
      (media) => [
        for (final item in media)
          if (item.id != id) item,
      ],
    );
  }

  void _updateTimeline(List<MediaItem> Function(List<MediaItem>) update) {
    final timeline = ref.read(libraryMediaProvider);
    final loaded = timeline.value;
    // Nothing to keep in step while the timeline is loading or failed.
    if (loaded == null) return;
    ref.read(libraryMediaProvider.notifier).replaceMedia(update(loaded.media));
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
    // ...and when the reader narrows the library: a cursor taken under the
    // previous narrowing points into a different result set.
    final query = ref.watch(libraryMediaQueryProvider);
    _generation++;
    final page = await ref
        .read(listLibraryMediaUseCaseProvider)
        .execute(pageSize: libraryMediaPageSize, query: query);
    return LibraryMediaState(media: page.items, nextCursor: page.nextCursor);
  }

  /// Swaps the loaded media for [media], keeping the paging position.
  ///
  /// For changes to items already on screen (a favourite mark, a delete):
  /// re-reading would lose the reader's place and re-fetch every window.
  /// A no-op while the timeline is loading or failed — there is nothing on
  /// screen to keep in step with.
  void replaceMedia(List<MediaItem> media) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(media: media));
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
          .execute(
            cursor: current.nextCursor,
            pageSize: libraryMediaPageSize,
            query: ref.read(libraryMediaQueryProvider),
          );
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

// ─── Trash ─────────────────────────────────────────────────────────────────

/// Media in the trash, newest deletion first.
///
/// `autoDispose` on purpose, unlike the library timeline: the trash is opened
/// deliberately and rarely, and holding a list of media that is about to be
/// purged would only go stale. Leaving the screen forgets it, so reopening
/// asks the server again.
final AsyncNotifierProvider<TrashedMediaNotifier, List<MediaItem>>
trashedMediaProvider =
    AsyncNotifierProvider<TrashedMediaNotifier, List<MediaItem>>(
      TrashedMediaNotifier.new,
    );

/// Reads the trash and drops restored media from it.
class TrashedMediaNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    ref.watch(sessionIdentityProvider);
    final page = await ref
        .read(listTrashedMediaUseCaseProvider)
        .execute(pageSize: libraryMediaPageSize);
    return page.items;
  }

  /// Re-reads the trash from the first window.
  Future<void> reload() async {
    state = const AsyncValue<List<MediaItem>>.loading();
    state = await AsyncValue.guard(build);
  }

  /// Drops [id] from the loaded trash after a successful restore, so the
  /// list does not keep offering to restore something already restored.
  void forget(MediaId id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data([
      for (final item in current)
        if (item.id != id) item,
    ]);
  }
}
