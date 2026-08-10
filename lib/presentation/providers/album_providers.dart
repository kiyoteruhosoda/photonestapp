import 'package:flutter_riverpod/flutter_riverpod.dart';
// `AsyncNotifierProviderFamily` — the type the family expression above
// evaluates to — lives in Riverpod's `misc.dart`.
import 'package:flutter_riverpod/misc.dart';
import 'package:photonest/application/usecases/album/edit_album_usecase.dart';
import 'package:photonest/application/usecases/album/get_album_usecase.dart';
import 'package:photonest/application/usecases/album/list_albums_usecase.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/providers/app_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────
//
// One provider per use case, overridden by the composition root.

final Provider<ListAlbumsUseCase> listAlbumsUseCaseProvider =
    Provider<ListAlbumsUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('listAlbumsUseCaseProvider'),
      );
    });

final Provider<GetAlbumUseCase> getAlbumUseCaseProvider =
    Provider<GetAlbumUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getAlbumUseCaseProvider'),
      );
    });

final Provider<EditAlbumUseCase> editAlbumUseCaseProvider =
    Provider<EditAlbumUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('editAlbumUseCaseProvider'),
      );
    });

// ─── Screen state ──────────────────────────────────────────────────────────

/// The album list shown on the home tab.
final AsyncNotifierProvider<AlbumListNotifier, List<Album>> albumListProvider =
    AsyncNotifierProvider<AlbumListNotifier, List<Album>>(
      AlbumListNotifier.new,
    );

/// Loads the albums from the server.
class AlbumListNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() {
    // Rebuilds when the signed-in identity changes, so a login to another
    // account or server never shows the previous identity's albums.
    ref.watch(sessionIdentityProvider);
    return ref.read(listAlbumsUseCaseProvider).execute();
  }

  /// Re-reads the list, e.g. after a pull-to-refresh.
  Future<void> reload() async {
    state = const AsyncValue<List<Album>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(listAlbumsUseCaseProvider).execute(),
    );
  }
}

/// How many media items each album-detail page requests.
const int albumMediaPageSize = 100;

/// What the album detail screen renders: the media loaded so far, plus how
/// far along the paging is. Null (as the provider's value) means the album
/// does not exist.
final class AlbumDetailState {
  const AlbumDetailState({
    required this.album,
    required this.media,
    required this.mediaTotal,
    this.pagesLoaded = 1,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final Album album;

  /// Media accumulated across the pages read so far, in display order.
  ///
  /// May be shorter than `pagesLoaded × page size`: overlapping pages (the
  /// album grew or was reordered mid-paging) are deduplicated on append.
  final List<MediaItem> media;

  /// The album's total media count, across all pages, or null while it is
  /// unknown — a server that omits the total. Unknown means "assume more":
  /// paging then continues until a short page proves the end.
  final int? mediaTotal;

  /// How many pages have been fetched. The next request is always
  /// `pagesLoaded + 1` — deriving the page from [media]'s length would
  /// re-request the same page forever once deduplication shortened it.
  final int pagesLoaded;

  /// True while the next page is being fetched.
  final bool loadingMore;

  /// True when the most recent load-more attempt failed; the tail tile
  /// offers the retry.
  final bool loadMoreFailed;

  /// Whether the server holds media beyond what [media] already covers.
  ///
  /// An unknown total counts as "more": stopping on a guess would silently
  /// truncate the album, while one extra request merely comes back short.
  bool get hasMore {
    final total = mediaTotal;
    return total == null || media.length < total;
  }

  AlbumDetailState copyWith({
    Album? album,
    List<MediaItem>? media,
    int? mediaTotal,
    int? pagesLoaded,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return AlbumDetailState(
      album: album ?? this.album,
      media: media ?? this.media,
      mediaTotal: mediaTotal ?? this.mediaTotal,
      pagesLoaded: pagesLoaded ?? this.pagesLoaded,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

/// One album with its media, keyed by id, loaded page by page.
///
/// Read by the detail screen directly, so a deep link can open an album
/// before the list has ever loaded. Null means the album does not exist.
final AsyncNotifierProviderFamily<
  AlbumDetailNotifier,
  AlbumDetailState?,
  AlbumId
>
albumDetailProvider =
    AsyncNotifierProvider.family<
      AlbumDetailNotifier,
      AlbumDetailState?,
      AlbumId
    >(AlbumDetailNotifier.new);

/// Pages one album's media in from the server as the grid scrolls.
class AlbumDetailNotifier extends AsyncNotifier<AlbumDetailState?> {
  AlbumDetailNotifier(this.albumId);

  /// The family argument: which album this notifier pages.
  final AlbumId albumId;

  /// Bumped by every (re)build, so a page request that was already in
  /// flight when the album restarted — a sign-in to another account or
  /// server — is discarded instead of overwriting the fresh state with
  /// media captured before the `await`.
  int _generation = 0;

  @override
  Future<AlbumDetailState?> build() async {
    ref.watch(sessionIdentityProvider);
    _generation++;
    final detail = await ref
        .read(getAlbumUseCaseProvider)
        .execute(albumId, mediaPage: 1, mediaPageSize: albumMediaPageSize);
    if (detail == null) return null;
    // Without an advertised total, a short first page is the server saying
    // the album is complete; a full one leaves the total unknown so paging
    // continues.
    final exhausted = detail.media.length < albumMediaPageSize;
    return AlbumDetailState(
      album: detail.album,
      media: detail.media,
      mediaTotal: detail.mediaTotal ?? (exhausted ? detail.media.length : null),
    );
  }

  /// Swaps in the album the server settled on after a rename, keeping the
  /// media pages already read.
  ///
  /// A no-op while the album is loading, failed, or not found — there is no
  /// loaded state to patch, and the next read will carry the new name
  /// anyway.
  void replaceAlbum(Album album) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(album: album));
  }

  /// Fetches the next page and appends it. A no-op while a fetch is already
  /// running, when everything is loaded, and when the album was not found.
  ///
  /// A failed fetch flags the state instead of throwing: the loaded grid
  /// stays on screen, and the tail tile offers the retry.
  Future<void> loadMore() async {
    // `value` is null while loading, on error, and for a not-found album —
    // all states where there is nothing to append to.
    final current = state.value;
    if (current == null || current.loadingMore || !current.hasMore) return;
    final generation = _generation;
    state = AsyncValue.data(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );

    final nextPage = current.pagesLoaded + 1;
    final AlbumDetail? detail;
    try {
      detail = await ref
          .read(getAlbumUseCaseProvider)
          .execute(
            albumId,
            mediaPage: nextPage,
            mediaPageSize: albumMediaPageSize,
          );
    } on Object {
      if (generation != _generation) return;
      state = AsyncValue.data(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
      return;
    }
    if (generation != _generation) return;
    if (detail == null) {
      // The album vanished between pages; the screen shows not-found.
      state = const AsyncValue<AlbumDetailState?>.data(null);
      return;
    }
    // Appending by id keeps the list stable when the album was reordered or
    // grew between page reads — a duplicate would render the same tile
    // twice.
    final known = current.media.map((MediaItem item) => item.id).toSet();
    final media = [
      ...current.media,
      ...detail.media.where((item) => !known.contains(item.id)),
    ];
    // A short page is the server saying "no more", whatever the advertised
    // total claims — totals drift while media is deleted mid-paging, and
    // trusting a stale one would request empty pages forever.
    final exhausted = detail.media.length < albumMediaPageSize;
    state = AsyncValue.data(
      current.copyWith(
        media: media,
        mediaTotal: exhausted ? media.length : detail.mediaTotal,
        pagesLoaded: nextPage,
        loadingMore: false,
        // `current` was captured before the flag was cleared, so a retry
        // that succeeded would otherwise keep showing the retry tile.
        loadMoreFailed: false,
      ),
    );
  }
}

// ─── Editing ───────────────────────────────────────────────────────────────

/// Runs the album write calls and keeps the loaded screens in step.
final NotifierProvider<AlbumEditingNotifier, AlbumEditingState>
albumEditingProvider =
    NotifierProvider<AlbumEditingNotifier, AlbumEditingState>(
      AlbumEditingNotifier.new,
    );

/// What the album form and the picker need to render.
final class AlbumEditingState {
  const AlbumEditingState({this.busy = false, this.lastFailure});

  /// True while a create/update request is in flight, so the control that
  /// started it can disable itself.
  ///
  /// One flag rather than one per album — unlike the trash's per-item marks.
  /// These calls are started from a dialog or a sheet the reader has to
  /// close before starting another, so there is never a second one to track.
  final bool busy;

  /// The most recent failure, for the caller to show and then clear.
  final Object? lastFailure;
}

/// Creates albums, renames them, and files media under them, writing the
/// result into whatever is already on screen.
///
/// A failure is state rather than an exception to the caller: the sheet
/// shows it and the album stays as it was.
class AlbumEditingNotifier extends Notifier<AlbumEditingState> {
  @override
  AlbumEditingState build() => const AlbumEditingState();

  /// Makes an album, optionally holding [mediaIds] from the start. Returns
  /// the album the server stored, or null when the call failed.
  Future<Album?> create(
    String title, {
    String? description,
    List<MediaId> mediaIds = const <MediaId>[],
  }) {
    return _run(() async {
      final album = await ref
          .read(editAlbumUseCaseProvider)
          .create(title, description: description, mediaIds: mediaIds);
      await ref.read(albumListProvider.notifier).reload();
      return album;
    });
  }

  /// Renames [id] and replaces its description. Returns the album the
  /// server settled on, or null when the call failed.
  Future<Album?> updateDetails(
    AlbumId id, {
    required String title,
    String? description,
  }) {
    return _run(() async {
      final album = await ref
          .read(editAlbumUseCaseProvider)
          .updateDetails(id, title: title, description: description);
      // The open detail screen carries the old title in its header. Patched
      // rather than invalidated: re-reading would throw away the media
      // pages the reader has already scrolled through, to change a string.
      //
      // Guarded by `exists`, because reading a family instance is what
      // *creates* it: renaming from a screen that never opened this album
      // would otherwise start a detail fetch nobody is waiting for.
      if (ref.exists(albumDetailProvider(id))) {
        ref.read(albumDetailProvider(id).notifier).replaceAlbum(album);
      }
      await ref.read(albumListProvider.notifier).reload();
      return album;
    });
  }

  /// Puts [mediaId] into [albumId]. Returns whether the album gained it —
  /// false when it already held it — or null when the call failed.
  Future<bool?> addMedia(AlbumId albumId, MediaId mediaId) {
    return _run(() async {
      final result = await ref
          .read(editAlbumUseCaseProvider)
          .addMedia(albumId, mediaId);
      if (result.added) {
        // The album's grid has to show the photo, and its tile has to show
        // the new count. Invalidated rather than patched: the server places
        // the media and may have picked a cover, and this notifier holds no
        // MediaItem to append — only an id. Invalidating an instance that
        // was never created is a no-op, so this needs no `exists` guard.
        ref.invalidate(albumDetailProvider(albumId));
        await ref.read(albumListProvider.notifier).reload();
      }
      return result.added;
    });
  }

  /// Clears the last failure once the screen has shown it.
  void acknowledgeFailure() {
    if (state.lastFailure == null) return;
    state = AlbumEditingState(busy: state.busy);
  }

  /// Runs one write, holding [AlbumEditingState.busy] for its duration.
  ///
  /// A second call while one is running is refused, which is what the
  /// disabled control already prevents in the UI.
  Future<T?> _run<T>(Future<T> Function() action) async {
    if (state.busy) return null;
    state = AlbumEditingState(busy: true, lastFailure: state.lastFailure);
    try {
      final result = await action();
      state = AlbumEditingState(lastFailure: state.lastFailure);
      return result;
    } on Object catch (error) {
      state = AlbumEditingState(lastFailure: error);
      return null;
    }
  }
}
