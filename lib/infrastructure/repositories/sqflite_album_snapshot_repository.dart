import 'dart:convert';

import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_snapshot_repository.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [AlbumSnapshotRepository] backed by SQLite, scoped to the signed-in
/// account.
///
/// Each remembered server answer is one row: the album list under a fixed
/// key, each detail page under a key naming its album, page, and page size
/// (a page read at another size is a different window and must not be
/// served for it). Rows are keyed by server + account exactly like the
/// thumbnail cache — album ids are only unique per server. Reads and writes
/// while signed out miss instead of failing: the snapshot is a fallback,
/// never a gatekeeper.
final class SqfliteAlbumSnapshotRepository implements AlbumSnapshotRepository {
  SqfliteAlbumSnapshotRepository(
    this._database,
    this._sessions,
    this._endpoints, {
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  final Database _database;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;

  /// Injectable so tests can pin the `stored_at` stamps.
  final DateTime Function() _now;

  /// Key of the one album-list row per account.
  static const String _albumListKey = 'albums';

  /// Every detail-page key starts with this; the trailing slash keeps the
  /// [_albumListKey] row out of prefix matches.
  static const String _detailKeyRoot = 'album/';

  static String _detailKeyPrefix(AlbumId id) =>
      '$_detailKeyRoot${id.value}/page/';

  static String _detailKey(AlbumId id, int mediaPage, int mediaPageSize) =>
      '${_detailKeyPrefix(id)}$mediaPage/size/$mediaPageSize';

  @override
  Future<void> saveAlbums(List<Album> albums) async {
    await _save(_albumListKey, albums.map(_albumToJson).toList());
    await _forgetDetailsAbsentFrom(albums);
  }

  @override
  Future<List<Album>?> findAlbums() async {
    final payload = await _find(_albumListKey);
    if (payload == null) return null;
    return _decode(() {
      final items = jsonDecode(payload) as List<dynamic>;
      return items.cast<Map<String, dynamic>>().map(_albumFromJson).toList();
    });
  }

  @override
  Future<void> saveDetail(
    AlbumDetail detail, {
    required int mediaPage,
    required int mediaPageSize,
  }) {
    return _save(_detailKey(detail.album.id, mediaPage, mediaPageSize), {
      'album': _albumToJson(detail.album),
      'media': detail.media.map(_mediaItemToJson).toList(),
      'mediaTotal': detail.mediaTotal,
    });
  }

  @override
  Future<AlbumDetail?> findDetail(
    AlbumId id, {
    required int mediaPage,
    required int mediaPageSize,
  }) async {
    final payload = await _find(_detailKey(id, mediaPage, mediaPageSize));
    if (payload == null) return null;
    return _decode(() {
      final json = jsonDecode(payload) as Map<String, dynamic>;
      final media = json['media'] as List<dynamic>;
      return AlbumDetail(
        album: _albumFromJson(json['album'] as Map<String, dynamic>),
        media: media
            .cast<Map<String, dynamic>>()
            .map(_mediaItemFromJson)
            .toList(),
        mediaTotal: json['mediaTotal'] as int?,
      );
    });
  }

  @override
  Future<void> removeDetail(AlbumId id) async {
    final account = _activeAccountKey();
    if (account == null) return;
    try {
      await _database.delete(
        AppDatabase.albumSnapshotsTable,
        where: 'account_key = ? AND snapshot_key LIKE ?',
        whereArgs: [account, '${_detailKeyPrefix(id)}%'],
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not remove an album snapshot.',
        cause: error,
      );
    }
  }

  /// Deletes the detail pages of every album absent from [albums] — the
  /// full list is authoritative, and a detail read never consults it, so a
  /// deleted or hidden album would otherwise resurrect offline through its
  /// stale pages.
  Future<void> _forgetDetailsAbsentFrom(List<Album> albums) async {
    final account = _activeAccountKey();
    if (account == null) return;
    final visible = albums.map((album) => album.id.value).toSet();
    try {
      final rows = await _database.query(
        AppDatabase.albumSnapshotsTable,
        columns: ['snapshot_key'],
        where: 'account_key = ? AND snapshot_key LIKE ?',
        whereArgs: [account, '$_detailKeyRoot%'],
      );
      final stale = rows.map((row) => row['snapshot_key']! as String).where((
        key,
      ) {
        final albumId = _albumIdOfDetailKey(key);
        return albumId == null || !visible.contains(albumId);
      }).toList();
      if (stale.isEmpty) return;
      final batch = _database.batch();
      for (final key in stale) {
        batch.delete(
          AppDatabase.albumSnapshotsTable,
          where: 'account_key = ? AND snapshot_key = ?',
          whereArgs: [account, key],
        );
      }
      await batch.commit(noResult: true);
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not prune stale album snapshots.',
        cause: error,
      );
    }
  }

  /// The album id a detail-page key names, or null for a key this build
  /// does not recognise (which [_forgetDetailsAbsentFrom] treats as stale).
  static int? _albumIdOfDetailKey(String key) {
    final parts = key.split('/');
    if (parts.length < 2 || '${parts.first}/' != _detailKeyRoot) return null;
    return int.tryParse(parts[1]);
  }

  Future<void> _save(String key, Object payload) async {
    final account = _activeAccountKey();
    if (account == null) return;
    try {
      await _database.insert(
        AppDatabase.albumSnapshotsTable,
        {
          'account_key': account,
          'snapshot_key': key,
          'payload': jsonEncode(payload),
          'stored_at': _now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not store an album snapshot.',
        cause: error,
      );
    }
  }

  Future<String?> _find(String key) async {
    final account = _activeAccountKey();
    if (account == null) return null;
    final List<Map<String, Object?>> rows;
    try {
      rows = await _database.query(
        AppDatabase.albumSnapshotsTable,
        columns: ['payload'],
        where: 'account_key = ? AND snapshot_key = ?',
        whereArgs: [account, key],
      );
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not read the album snapshot.',
        cause: error,
      );
    }
    if (rows.isEmpty) return null;
    return rows.first['payload']! as String;
  }

  /// Runs [decode], turning a corrupt payload — malformed JSON, a shape from
  /// some future build — into the same typed error a broken table produces,
  /// so callers handle one failure mode, not two.
  T _decode<T>(T Function() decode) {
    try {
      return decode();
    } on FormatException catch (error) {
      throw InfrastructureError(
        'Could not decode an album snapshot.',
        cause: error,
      );
    } on TypeError catch (error) {
      throw InfrastructureError(
        'Could not decode an album snapshot.',
        cause: error,
      );
    }
  }

  static Map<String, Object?> _albumToJson(Album album) {
    return {
      'id': album.id.value,
      'title': album.title,
      'description': album.description,
      'mediaCount': album.mediaCount,
      'coverMediaId': album.coverMediaId?.value,
      'createdAt': album.createdAt?.toIso8601String(),
    };
  }

  static Album _albumFromJson(Map<String, dynamic> json) {
    final cover = json['coverMediaId'] as int?;
    final createdAt = json['createdAt'] as String?;
    return Album(
      id: AlbumId(json['id'] as int),
      title: json['title'] as String,
      description: json['description'] as String?,
      mediaCount: json['mediaCount'] as int,
      coverMediaId: cover == null ? null : MediaId(cover),
      createdAt: createdAt == null ? null : DateTime.parse(createdAt).toUtc(),
    );
  }

  static Map<String, Object?> _mediaItemToJson(MediaItem item) {
    return {
      'id': item.id.value,
      'filename': item.filename,
      'shotAt': item.shotAt?.toIso8601String(),
      'isVideo': item.isVideo,
    };
  }

  static MediaItem _mediaItemFromJson(Map<String, dynamic> json) {
    final shotAt = json['shotAt'] as String?;
    return MediaItem(
      id: MediaId(json['id'] as int),
      filename: json['filename'] as String,
      shotAt: shotAt == null ? null : DateTime.parse(shotAt).toUtc(),
      isVideo: json['isVideo'] as bool,
    );
  }

  /// `server#email`, or null while signed out.
  String? _activeAccountKey() {
    final session = _sessions.load();
    if (session == null) return null;
    final endpoint = _endpoints.load();
    return '${endpoint ?? ''}#${session.email}';
  }
}
