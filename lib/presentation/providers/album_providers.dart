import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/album/get_album_usecase.dart';
import 'package:flutterbase/application/usecases/album/list_albums_usecase.dart';
import 'package:flutterbase/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

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

/// One album with its media, keyed by id.
///
/// Read by the detail screen directly, so a deep link can open an album
/// before the list has ever loaded. Null means the album does not exist.
final albumDetailProvider = FutureProvider.family<AlbumDetail?, AlbumId>((
  ref,
  id,
) {
  return ref.read(getAlbumUseCaseProvider).execute(id);
});

/// Cache key for one server-side thumbnail.
typedef MediaThumbnailRequest = ({MediaId id, int size});

/// Server thumbnail bytes, cached per (media, size).
///
/// A family provider is the cache: every grid tile watching the same media
/// id shares one fetch, and navigating back to a screen reuses the bytes
/// instead of re-downloading them.
final mediaThumbnailProvider =
    FutureProvider.family<Uint8List, MediaThumbnailRequest>((ref, request) {
      return ref
          .read(getMediaThumbnailUseCaseProvider)
          .execute(request.id, size: request.size);
    });
