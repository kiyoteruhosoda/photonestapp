import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_library_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
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
  Future<MediaLibraryPage> findPage({int page = 1, int pageSize = 100}) async {
    final payload = await _client.getJson(
      '/media',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        // Newest capture first — the order the timeline reads in. Sent
        // explicitly rather than relying on the server's default.
        'order': 'desc',
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
      // The server always reports this. A missing or unexpected value reads
      // as "no more": an optimistic default would keep requesting empty
      // pages forever, and the caller's short-page check is the second guard
      // against stopping one page early.
      hasNext: _isTrue(payload['hasNext']),
    );
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
