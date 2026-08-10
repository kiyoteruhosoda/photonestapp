import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/album_editing_repository.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [AlbumEditingRepository] backed by the server's album endpoints.
///
/// Albums are made with `POST /api/albums` and changed with
/// `PUT /api/albums/{id}`. The update is partial — it changes the fields it
/// is given — which is what lets a rename be sent without the album's media
/// and a media replacement be sent without the name.
final class ApiAlbumEditingRepository implements AlbumEditingRepository {
  const ApiAlbumEditingRepository(this._client);

  final PhotoNestApiClient _client;

  /// How many media ids one read of [mediaIdsOf] asks for.
  ///
  /// The endpoint also answers with every item at once when no page is
  /// given, which would be one request instead of several. It is not used:
  /// that response carries the full record of every photo in the album, and
  /// a phone holding a ten-thousand-item album in memory to learn its ids
  /// is a worse trade than a handful of bounded requests. 500 is the
  /// server's maximum page size.
  static const int _mediaIdPageSize = 500;

  @override
  Future<Album> create({
    required String title,
    String? description,
    List<MediaId> mediaIds = const <MediaId>[],
  }) async {
    final payload = await _client.postJson('/albums', {
      'name': title,
      // Omitted when absent: creation has no old description to clear, so
      // there is nothing to say by sending a blank one.
      'description': ?description,
      'mediaIds': [for (final id in mediaIds) id.value],
    });
    return _albumFrom(payload['album'], 'Album creation response');
  }

  @override
  Future<Album> updateDetails(
    AlbumId id, {
    required String title,
    String? description,
  }) async {
    final payload = await _client.putJson('/albums/${id.value}', {
      'name': title,
      // Blank rather than null when the reader cleared the description.
      // The endpoint reads a null as "leave this field alone" — sending it
      // would keep the text the reader just deleted — while a blank string
      // is what it stores as "no description".
      'description': description ?? '',
    });
    return _albumFrom(payload['album'], 'Album update response');
  }

  @override
  Future<List<MediaId>> mediaIdsOf(AlbumId id) async {
    final ids = <MediaId>[];
    for (var page = 1; ; page++) {
      final payload = await _client.getJson(
        '/albums/${id.value}',
        query: {'page': '$page', 'pageSize': '$_mediaIdPageSize'},
      );
      final album = _albumJson(payload['album'], 'Album media response');
      final raw = album['mediaIds'];
      if (raw is! List) {
        throw const InfrastructureError(
          'Album media response carried no media ids.',
        );
      }
      // One unreadable id fails the whole read rather than being skipped:
      // these ids are about to be sent back as the album's complete
      // contents, so a silently shortened list would delete photos.
      for (final entry in raw) {
        if (entry is! int) {
          throw const InfrastructureError(
            'Album media response carried an unreadable media id.',
          );
        }
        ids.add(MediaId(entry));
      }
      final total = album['mediaTotal'];
      final done =
          raw.length < _mediaIdPageSize ||
          (total is int && ids.length >= total);
      if (done) break;
    }
    return ids;
  }

  /// Replaces the album's media.
  ///
  /// The name is deliberately absent from the body: the endpoint leaves out
  /// what it is not given, so filing a photo cannot rename the album by
  /// echoing a title that another device changed in the meantime.
  @override
  Future<Album> replaceMedia(AlbumId id, List<MediaId> mediaIds) async {
    final payload = await _client.putJson('/albums/${id.value}', {
      'mediaIds': [for (final mediaId in mediaIds) mediaId.value],
    });
    return _albumFrom(payload['album'], 'Album media update response');
  }

  static Album _albumFrom(Object? raw, String subject) {
    final json = _albumJson(raw, subject);
    final id = json['id'];
    if (id is! int) {
      throw InfrastructureError('$subject carried an album without an id.');
    }
    final cover = json['coverMediaId'];
    return Album(
      id: AlbumId(id),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      mediaCount: json['mediaCount'] as int? ?? 0,
      coverMediaId: cover is int && cover > 0 ? MediaId(cover) : null,
      createdAt: _utcInstant(json['createdAt']),
    );
  }

  static Map<String, dynamic> _albumJson(Object? raw, String subject) {
    if (raw is! Map<String, dynamic>) {
      throw InfrastructureError('$subject carried no album.');
    }
    return raw;
  }

  static DateTime? _utcInstant(Object? raw) {
    if (raw is! String) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }
}
