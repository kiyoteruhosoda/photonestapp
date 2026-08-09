import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/media_id.dart';

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

/// An album together with one page of the media it contains, as returned by
/// the album detail endpoint.
///
/// Large albums are read page by page; [mediaTotal] is what tells a reader
/// how much remains beyond [media]. A server that does not report a total
/// leaves it null — the total is then *unknown*, not "whatever this page
/// held". Falling back to the page length here would silently end paging
/// whenever a page happened to be exactly full.
final class AlbumDetail {
  const AlbumDetail({
    required this.album,
    required this.media,
    this.mediaTotal,
  });

  final Album album;

  /// One page of media in the album's display order.
  final List<MediaItem> media;

  /// How many media items the album holds in total, across all pages, or
  /// null when the server did not say. Readers who need an end-of-paging
  /// signal without a total must rely on a short page instead.
  final int? mediaTotal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is AlbumDetail && other.album == album);

  @override
  int get hashCode => album.hashCode;

  @override
  String toString() =>
      'AlbumDetail(${album.id.value}, ${media.length} of '
      '${mediaTotal ?? '?'} media)';
}
