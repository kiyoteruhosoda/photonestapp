import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/repositories/media_tag_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Reads and changes the tags on one media item.
///
/// One use case rather than three: an editor needs all three reads and
/// writes together — what the media carries, what it could carry, and the
/// replacement — and they share the logging that makes a change traceable.
final class EditMediaTagsUseCase {
  const EditMediaTagsUseCase(this._tags, this._logger);

  final MediaTagRepository _tags;
  final AppLogger _logger;

  /// The tags currently on [id].
  Future<List<Tag>> tagsOf(MediaId id) => _tags.findByMedia(id);

  /// Tags the reader could add, narrowed by what they have typed.
  Future<List<Tag>> suggest({String query = '', int limit = 20}) =>
      _tags.findAll(query: query, limit: limit);

  /// Files [id] under exactly [tags], and returns what the server settled
  /// on.
  ///
  /// The server's answer wins over the requested set: it drops tags that
  /// stopped existing and orders them its own way, and the editor should
  /// show what is stored rather than what was asked for.
  Future<List<Tag>> replace(MediaId id, List<Tag> tags) async {
    final settled = await _tags.replaceMediaTags(id, [
      for (final tag in tags) tag.id,
    ]);
    _logger.info('[Media] ${id.value} tags: ${_describe(settled)}');
    return settled;
  }

  /// Tag ids rather than names — the log records what changed without
  /// carrying library content into it.
  static String _describe(List<Tag> tags) {
    if (tags.isEmpty) return 'none';
    return tags.map((Tag tag) => tag.id.value).join(',');
  }
}
