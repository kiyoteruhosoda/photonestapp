import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/media_tag_repository.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// Reads and changes the tags on one media item.
///
/// One use case rather than four: an editor needs every one of these reads
/// and writes together — what the media carries, what it could carry, a name
/// the library does not hold yet, and the replacement — and they share the
/// logging that makes a change traceable.
final class EditMediaTagsUseCase {
  const EditMediaTagsUseCase(this._tags, this._logger);

  /// What a tag made from the app is filed under.
  ///
  /// The app does not ask the reader which kind of thing the tag names. A
  /// tag is made here mid-viewing, from the editor's search field, and a
  /// vocabulary question at that moment costs more than the answer is worth
  /// — the server takes the attribute as required, so *something* has to be
  /// sent. [TagAttribute.others] states only what is actually known: nobody
  /// has classified it. The web admin can narrow it afterwards.
  /// Reason: `docs/adr/0012-app-created-tags-are-unclassified.md`.
  static const TagAttribute newTagAttribute = TagAttribute.others;

  final MediaTagRepository _tags;
  final AppLogger _logger;

  /// The tags currently on [id].
  Future<List<Tag>> tagsOf(MediaId id) => _tags.findByMedia(id);

  /// Tags the reader could add, narrowed by what they have typed.
  Future<List<Tag>> suggest({String query = '', int limit = 20}) =>
      _tags.findAll(query: query, limit: limit);

  /// Puts [name] into the library and returns the tag to file media under.
  ///
  /// Surrounding whitespace is dropped before the name is sent, so " Kyoto "
  /// and "Kyoto" ask for the same tag rather than two that look alike in a
  /// list. A name that is nothing but whitespace is a caller's mistake, not
  /// a server round trip.
  Future<Tag> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const DomainError('A tag needs a name.');
    }
    final tag = await _tags.createTag(trimmed, newTagAttribute);
    // The id, not the name, for the same reason the replacement logs ids:
    // the log says what happened without carrying library content into it.
    _logger.info('[Media] tag available: ${tag.id.value}');
    return tag;
  }

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
