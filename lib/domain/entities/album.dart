import 'package:flutterbase/domain/entities/album_media_item.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

/// An album as listed by the PhotoNest server.
///
/// Two albums are the same when their [id] is the same — a renamed album is
/// still the same album.
final class Album {
  const Album({
    required this.id,
    required this.title,
    required this.mediaCount,
    this.description,
    this.coverMediaId,
    this.createdAt,
  });

  final AlbumId id;
  final String title;
  final String? description;

  /// Number of media items the album holds, as reported by the server.
  final int mediaCount;

  /// Media item whose thumbnail represents the album, when one is set.
  final MediaId? coverMediaId;

  /// Creation instant in UTC, when the server reported one.
  final DateTime? createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Album && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Album(${id.value}, $title)';
}

/// An album together with the media it contains, as returned by the album
/// detail endpoint.
final class AlbumDetail {
  const AlbumDetail({required this.album, required this.media});

  final Album album;

  /// Media in the album's display order.
  final List<AlbumMediaItem> media;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AlbumDetail && other.album == album);

  @override
  int get hashCode => album.hashCode;

  @override
  String toString() => 'AlbumDetail(${album.id.value}, ${media.length} media)';
}
