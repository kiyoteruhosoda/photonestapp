import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_tag_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/tag_id.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [MediaTagRepository] backed by the server's tag endpoints.
///
/// The library's tags come from `/api/tags`; a media item's own tags are read
/// from its detail (`/api/media/{id}`), which is the only endpoint that
/// reports them, and replaced through `/api/media/{id}/tags`.
final class ApiMediaTagRepository implements MediaTagRepository {
  const ApiMediaTagRepository(this._client);

  final PhotoNestApiClient _client;

  @override
  Future<List<Tag>> findAll({String query = '', int limit = 20}) async {
    final payload = await _client.getJson(
      '/tags',
      query: {
        // Omitted while blank: the server reads a present-but-empty `q` as a
        // filter and would answer with nothing, which is the opposite of
        // "show me what the library has".
        if (query.isNotEmpty) 'q': query,
        'limit': '$limit',
      },
    );
    return _tagsFrom(payload['items'], 'Tag list response had no items.');
  }

  @override
  Future<List<Tag>> findByMedia(MediaId id) async {
    final payload = await _client.getJson('/media/${id.value}');
    return _tagsFrom(
      payload['tags'],
      'Media detail response had no tags field.',
    );
  }

  @override
  Future<List<Tag>> replaceMediaTags(MediaId id, List<TagId> tagIds) async {
    final payload = await _client.putJson('/media/${id.value}/tags', {
      'tag_ids': [for (final tagId in tagIds) tagId.value],
    });
    return _tagsFrom(payload['tags'], 'Tag update response carried no tags.');
  }

  /// Reads a tag array, rejecting anything else.
  ///
  /// An absent array is a failure rather than an empty list: "this media has
  /// no tags" and "the server answered with a shape we do not understand"
  /// look identical to the editor, and quietly reading the second as the
  /// first would let a save wipe the tags it never managed to read.
  static List<Tag> _tagsFrom(Object? raw, String failure) {
    if (raw is! List) throw InfrastructureError(failure);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_tagFrom)
        .toList(growable: false);
  }

  static Tag _tagFrom(Map<String, dynamic> json) {
    return Tag(
      id: TagId(json['id'] as int),
      name: json['name'] as String? ?? '',
      attribute: TagAttribute.tryParse(json['attr'] as String?),
    );
  }
}
