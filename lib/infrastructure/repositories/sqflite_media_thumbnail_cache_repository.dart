import 'dart:typed_data';

import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:sqflite/sqflite.dart';

/// [MediaThumbnailCacheRepository] backed by SQLite, scoped to the signed-in
/// account and bounded by an LRU byte budget.
///
/// Entries are keyed by server + account exactly like the upload history —
/// media ids are only unique per server, so an unscoped cache would show one
/// account's photos to another. Reads while signed out miss instead of
/// failing: the cache is an optimisation, never a gatekeeper.
final class SqfliteMediaThumbnailCacheRepository
    implements MediaThumbnailCacheRepository {
  SqfliteMediaThumbnailCacheRepository(
    this._database,
    this._sessions,
    this._endpoints, {
    this._maxTotalBytes = defaultMaxTotalBytes,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Disk budget for all cached thumbnails together. 128 MiB holds several
  /// thousand grid tiles plus a few full-screen renditions — enough that
  /// eviction only touches what the user genuinely stopped looking at.
  static const int defaultMaxTotalBytes = 128 * 1024 * 1024;

  final Database _database;
  final SessionRepository _sessions;
  final ApiEndpointRepository _endpoints;
  final int _maxTotalBytes;

  /// Injectable so tests can pin the LRU touch stamps.
  final DateTime Function() _now;

  @override
  Future<Uint8List?> find(MediaId id, {required int size}) async {
    final account = _activeAccountKey();
    if (account == null) return null;
    try {
      final rows = await _database.query(
        AppDatabase.mediaThumbnailsTable,
        columns: ['bytes'],
        where: 'account_key = ? AND media_id = ? AND size = ?',
        whereArgs: [account, id.value, size],
      );
      if (rows.isEmpty) return null;
      // The hit becomes the freshest entry, so steady use never evicts what
      // the user actually looks at.
      await _database.update(
        AppDatabase.mediaThumbnailsTable,
        {'last_used_at': _now().toUtc().toIso8601String()},
        where: 'account_key = ? AND media_id = ? AND size = ?',
        whereArgs: [account, id.value, size],
      );
      return rows.first['bytes']! as Uint8List;
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not read the thumbnail cache.',
        cause: error,
      );
    }
  }

  @override
  Future<void> save(
    MediaId id, {
    required int size,
    required Uint8List bytes,
    required DateTime fetchedAt,
  }) async {
    final account = _activeAccountKey();
    if (account == null) return;
    final instant = fetchedAt.toUtc().toIso8601String();
    try {
      await _database.insert(
        AppDatabase.mediaThumbnailsTable,
        {
          'account_key': account,
          'media_id': id.value,
          'size': size,
          'bytes': bytes,
          'byte_count': bytes.length,
          'fetched_at': instant,
          'last_used_at': instant,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _evictOverBudget();
    } on DatabaseException catch (error) {
      throw InfrastructureError(
        'Could not store a thumbnail in the cache.',
        cause: error,
      );
    }
  }

  /// Deletes least-recently-used rows (across all accounts — the budget is
  /// per device, not per account) until the cache fits the byte budget.
  Future<void> _evictOverBudget() async {
    final total =
        Sqflite.firstIntValue(
          await _database.rawQuery(
            'SELECT SUM(byte_count) FROM ${AppDatabase.mediaThumbnailsTable}',
          ),
        ) ??
        0;
    var excess = total - _maxTotalBytes;
    if (excess <= 0) return;

    final candidates = await _database.query(
      AppDatabase.mediaThumbnailsTable,
      columns: ['account_key', 'media_id', 'size', 'byte_count'],
      orderBy: 'last_used_at ASC',
    );
    final batch = _database.batch();
    for (final row in candidates) {
      if (excess <= 0) break;
      excess -= row['byte_count']! as int;
      batch.delete(
        AppDatabase.mediaThumbnailsTable,
        where: 'account_key = ? AND media_id = ? AND size = ?',
        whereArgs: [row['account_key'], row['media_id'], row['size']],
      );
    }
    await batch.commit(noResult: true);
  }

  /// `server#email`, or null while signed out.
  String? _activeAccountKey() {
    final session = _sessions.load();
    if (session == null) return null;
    final endpoint = _endpoints.load();
    return '${endpoint ?? ''}#${session.email}';
  }
}
