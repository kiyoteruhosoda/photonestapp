import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';

/// [AlbumRepository] backed by the PhotoNest `/api/albums` endpoints.
final class ApiAlbumRepository implements AlbumRepository {
  const ApiAlbumRepository(this._client);

  final PhotoNestApiClient _client;

  /// The server's maximum page size for the album list.
  static const int _pageSize = 200;

  @override
  Future<List<Album>> findAll() async {
    // Follows the server's paging to the end: 200 per request covers most
    // libraries in one round-trip, and larger ones keep going instead of
    // silently truncating at the first page.
    final albums = <Album>[];
    for (var page = 1; ; page++) {
      final payload = await _client.getJson(
        '/albums',
        query: {'page': '$page', 'pageSize': '$_pageSize'},
      );
      final items = payload['items'];
      if (items is! List) {
        throw const InfrastructureError('Album list response had no items.');
      }
      albums.addAll(items.whereType<Map<String, dynamic>>().map(_albumFrom));
      final total = payload['total'];
      final done =
          items.length < _pageSize || (total is int && albums.length >= total);
      if (done) break;
    }
    return albums;
  }

  @override
  Future<AlbumDetail?> findById(
    AlbumId id, {
    int mediaPage = 1,
    int mediaPageSize = 100,
  }) async {
    final Map<String, dynamic> payload;
    try {
      payload = await _client.getJson(
        '/albums/${id.value}',
        query: {'page': '$mediaPage', 'pageSize': '$mediaPageSize'},
      );
    } on InfrastructureError catch (error) {
      // The server names a missing album `not_found`. Absence is an answer
      // here, not a failure.
      if (error.code == 'not_found') return null;
      rethrow;
    }
    final album = payload['album'];
    if (album is! Map<String, dynamic>) {
      throw const InfrastructureError('Album detail response had no album.');
    }
    final rawMedia = album['media'];
    final media = (rawMedia is List ? rawMedia : const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(_mediaItemFrom)
        .toList();
    // A server that reports no `mediaTotal` leaves the total unknown; the
    // reader falls back to short-page detection to find the end.
    final total = album['mediaTotal'];
    return AlbumDetail(
      album: _albumFrom(album),
      media: media,
      mediaTotal: total is int ? total : null,
    );
  }

  static Album _albumFrom(Map<String, dynamic> json) {
    final cover = json['coverMediaId'];
    return Album(
      id: AlbumId(json['id'] as int),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      mediaCount: json['mediaCount'] as int? ?? 0,
      coverMediaId: cover is int && cover > 0 ? MediaId(cover) : null,
      createdAt: _utcInstant(json['createdAt']),
    );
  }

  static MediaItem _mediaItemFrom(Map<String, dynamic> json) {
    return MediaItem(
      id: MediaId(json['id'] as int),
      filename: json['filename'] as String? ?? '',
      shotAt: _utcInstant(json['shotAt']),
      isVideo: json['isVideo'] == true,
    );
  }

  static DateTime? _utcInstant(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
