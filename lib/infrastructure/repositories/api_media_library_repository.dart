import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_library_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [MediaLibraryRepository] backed by the PhotoNest `GET /api/media`
/// endpoint.
///
/// That endpoint answers in snake_case and spells booleans as 0/1 integers —
/// unlike `/api/albums`, which uses camelCase and real booleans. The two
/// shapes meet here rather than in the domain: [MediaItem] is the same
/// either way.
final class ApiMediaLibraryRepository implements MediaLibraryRepository {
  const ApiMediaLibraryRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<MediaLibraryPage> findPage({
    String? cursor,
    int pageSize = 100,
    MediaLibraryQuery query = const MediaLibraryQuery(),
  }) async {
    final payload = await _client.getJson(
      '/media',
      query: {
        'pageSize': '$pageSize',
        // Newest capture first — the order the timeline reads in. Sent
        // explicitly rather than relying on the server's default.
        'order': 'desc',
        // Omitted on the first window; the server then starts from the top.
        'cursor': ?cursor,
        // Absent filters are omitted rather than sent empty: the server
        // treats a present-but-blank q as a match against '' and would
        // return nothing.
        'q': ?query.searchText,
        'type': ?query.kind.queryValue,
        if (query.favoritesOnly) 'favorite': '1',
      },
    );
    final items = payload['items'];
    if (items is! List) {
      throw const InfrastructureError('Media list response had no items.');
    }
    return MediaLibraryPage(
      items: items
          .whereType<Map<String, dynamic>>()
          .map(_mediaItemFrom)
          .toList(growable: false),
      // The server sends a cursor only when more media follows, so anything
      // that is not a non-empty string reads as "no more". An optimistic
      // default would keep requesting the same window forever.
      nextCursor: _cursorFrom(payload['nextCursor']),
    );
  }

  static String? _cursorFrom(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return raw;
  }

  static MediaItem _mediaItemFrom(Map<String, dynamic> json) {
    return MediaItem(
      id: MediaId(json['id'] as int),
      filename: json['filename'] as String? ?? '',
      shotAt: _utcInstant(json['shot_at']),
      isVideo: _isTrue(json['is_video']),
    );
  }

  /// The endpoint returns `int(bool(...))`, so a flag arrives as 0 or 1;
  /// real booleans are accepted too, so a server that tightens its types
  /// later does not silently turn every video into a photo.
  static bool _isTrue(Object? raw) => raw == true || raw == 1;

  static DateTime? _utcInstant(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
