import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// `AsyncNotifierProviderFamily` — the type the family expression above
// evaluates to — lives in Riverpod's `misc.dart`.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutterbase/application/usecases/album/get_album_usecase.dart';
import 'package:flutterbase/application/usecases/album/list_albums_usecase.dart';
import 'package:flutterbase/application/usecases/media/get_media_playback_usecase.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/album_media_item.dart';
import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/session_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────
//
// One provider per use case, overridden by the composition root — the same
// pattern as the bookmarks feature.

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
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final Album album;

  /// Media accumulated across the pages read so far, in display order.
  final List<AlbumMediaItem> media;

  /// The album's total media count, across all pages.
  final int mediaTotal;

  /// True while the next page is being fetched.
  final bool loadingMore;

  /// True when the most recent load-more attempt failed; the tail tile
  /// offers the retry.
  final bool loadMoreFailed;

  /// Whether the server holds media beyond what [media] already covers.
  bool get hasMore => media.length < mediaTotal;

  AlbumDetailState copyWith({
    List<AlbumMediaItem>? media,
    int? mediaTotal,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return AlbumDetailState(
      album: album,
      media: media ?? this.media,
      mediaTotal: mediaTotal ?? this.mediaTotal,
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

  @override
  Future<AlbumDetailState?> build() async {
    ref.watch(sessionIdentityProvider);
    final detail = await ref
        .read(getAlbumUseCaseProvider)
        .execute(albumId, mediaPage: 1, mediaPageSize: albumMediaPageSize);
    if (detail == null) return null;
    return AlbumDetailState(
      album: detail.album,
      media: detail.media,
      mediaTotal: detail.mediaTotal,
    );
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
    state = AsyncValue.data(
      current.copyWith(loadingMore: true, loadMoreFailed: false),
    );

    final nextPage = (current.media.length ~/ albumMediaPageSize) + 1;
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
      state = AsyncValue.data(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
      return;
    }
    if (detail == null) {
      // The album vanished between pages; the screen shows not-found.
      state = const AsyncValue<AlbumDetailState?>.data(null);
      return;
    }
    // Appending by id keeps the list stable when the album was reordered or
    // grew between page reads — a duplicate would render the same tile
    // twice.
    final known = current.media.map((AlbumMediaItem item) => item.id).toSet();
    state = AsyncValue.data(
      current.copyWith(
        media: [
          ...current.media,
          ...detail.media.where((item) => !known.contains(item.id)),
        ],
        mediaTotal: detail.mediaTotal,
        loadingMore: false,
      ),
    );
  }
}

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
