import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/album_editing_repository.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

/// The outcome of putting one photo into an album.
///
/// [added] is false when the album already held it. The caller needs the
/// difference to word the confirmation: "added" and "already in there" are
/// both successes, and reporting the second as the first makes the reader
/// wonder whether they filed it twice.
typedef AlbumMediaAddition = ({Album album, bool added});

/// Makes albums, renames them, and files media under them.
///
/// One use case rather than three: the album form and the picker need these
/// together — a reader who cannot find the album they want makes one from
/// the same sheet — and they share the logging that makes a change
/// traceable.
final class EditAlbumUseCase {
  const EditAlbumUseCase(this._albums, this._logger);

  final AlbumEditingRepository _albums;
  final AppLogger _logger;

  /// Creates an album named [title], optionally holding [mediaIds] from the
  /// start.
  ///
  /// Surrounding whitespace is dropped before the name is sent, so " Kyoto "
  /// and "Kyoto" ask for the same album rather than two that look alike in
  /// a grid. A name that is nothing but whitespace is a caller's mistake,
  /// not a server round trip.
  ///
  /// [mediaIds] is what makes creating an album from the viewer one
  /// request: the album and its first photo arrive together, instead of a
  /// create followed by the read-and-replace that [addMedia] needs.
  Future<Album> create(
    String title, {
    String? description,
    List<MediaId> mediaIds = const <MediaId>[],
  }) async {
    final album = await _albums.create(
      title: _requireTitle(title),
      description: _normalizeDescription(description),
      mediaIds: mediaIds,
    );
    // The id, not the name, for the same reason the tag log records ids:
    // the log says what happened without carrying library content into it.
    _logger.info(
      '[Album] created ${album.id.value} with ${mediaIds.length} media',
    );
    return album;
  }

  /// Renames [id] and replaces its description with [description].
  ///
  /// A blank description is stored as "no description" rather than an empty
  /// line, which is how the reader clears one they no longer want.
  Future<Album> updateDetails(
    AlbumId id, {
    required String title,
    String? description,
  }) async {
    final album = await _albums.updateDetails(
      id,
      title: _requireTitle(title),
      description: _normalizeDescription(description),
    );
    _logger.info('[Album] details updated: ${album.id.value}');
    return album;
  }

  /// Puts [mediaId] into [albumId], leaving what the album already held.
  ///
  /// Two requests, not one: the endpoint takes the album's whole media set,
  /// so the current ids are read and the new one appended. Reading them
  /// costs one request regardless of how many photos the album holds — the
  /// server reports the ids page by page and this follows the paging — so
  /// the cost is in the payload, not in a round trip per photo.
  ///
  /// Appended at the end rather than inserted by date: the album's order is
  /// the reader's, set on the server, and a photo added from the app is the
  /// most recent thing they filed.
  ///
  /// A photo the album already holds is left alone. Sending the same set
  /// back would rewrite every row's sort index to say nothing.
  Future<AlbumMediaAddition> addMedia(AlbumId albumId, MediaId mediaId) async {
    final current = await _albums.mediaIdsOf(albumId);
    if (current.contains(mediaId)) {
      _logger.info('[Album] ${albumId.value} already holds ${mediaId.value}');
      // Re-read rather than returned from the caller's stale copy: the
      // album's count and cover may have moved since the grid drew it.
      final album = await _albums.replaceMedia(albumId, current);
      return (album: album, added: false);
    }
    final album = await _albums.replaceMedia(albumId, [...current, mediaId]);
    _logger.info('[Album] ${albumId.value} now holds ${mediaId.value}');
    return (album: album, added: true);
  }

  static String _requireTitle(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const DomainError('An album needs a name.');
    }
    return trimmed;
  }

  static String? _normalizeDescription(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
