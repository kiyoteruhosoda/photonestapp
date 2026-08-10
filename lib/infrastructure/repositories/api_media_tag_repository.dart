import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_tag_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/tag_id.dart';
import 'package:photonest/infrastructure/api/photonest_api_client.dart';

/// [MediaTagRepository] backed by the server's tag endpoints.
///
/// The library's tags are read from and added to `/api/tags`; a media item's
/// own tags are read from its detail (`/api/media/{id}`), which is the only
/// endpoint that reports them, and replaced through `/api/media/{id}/tags`.
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
    return _tagsFrom(payload['items'], 'Tag list response');
  }

  @override
  Future<List<Tag>> findByMedia(MediaId id) async {
    final payload = await _client.getJson('/media/${id.value}');
    return _tagsFrom(payload['tags'], 'Media detail response');
  }

  @override
  Future<List<Tag>> replaceMediaTags(MediaId id, List<TagId> tagIds) async {
    final payload = await _client.putJson('/media/${id.value}/tags', {
      'tag_ids': [for (final tagId in tagIds) tagId.value],
    });
    return _tagsFrom(payload['tags'], 'Tag update response');
  }

  @override
  Future<Tag> createTag(String name, TagAttribute attribute) async {
    final payload = await _client.postJson('/tags', {
      'name': name,
      'attr': attribute.wireValue,
    });
    // The endpoint answers with `created` alongside the tag, saying whether
    // the name was new. The editor has nothing to decide from it — either
    // way this is the tag to file the photo under — so it is not read.
    return _tagFrom(payload['tag'], 'Tag creation response');
  }

  /// Reads a whole tag array, rejecting anything it does not understand.
  ///
  /// An absent array is a failure rather than an empty list: "this media has
  /// no tags" and "the server answered with a shape we do not understand"
  /// look identical to the editor, and quietly reading the second as the
  /// first would let a save wipe the tags it never managed to read.
  ///
  /// One malformed *entry* fails the whole array for the same reason.
  /// Skipping it would hand the editor a subset dressed up as the complete
  /// current state, and the next save — which replaces the whole set — would
  /// delete the tag that was skipped.
  static List<Tag> _tagsFrom(Object? raw, String subject) {
    if (raw is! List) {
      throw InfrastructureError('$subject carried no tag array.');
    }
    return <Tag>[for (final entry in raw) _tagFrom(entry, subject)];
  }

  static Tag _tagFrom(Object? raw, String subject) {
    final id = raw is Map<String, dynamic> ? raw['id'] : null;
    if (id is! int) {
      throw InfrastructureError('$subject carried a tag without an id.');
    }
    final json = raw! as Map<String, dynamic>;
    return Tag(
      id: TagId(id),
      name: json['name'] as String? ?? '',
      attribute: TagAttribute.tryParse(json['attr'] as String?),
    );
  }
}
