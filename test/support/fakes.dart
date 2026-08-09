import 'dart:async';
import 'dart:typed_data';

import 'package:photonest/application/ports/background_sync_scheduler.dart';
import 'package:photonest/application/ports/network_connection_gateway.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/entities/app_info.dart';
import 'package:photonest/domain/entities/auth_session.dart';
import 'package:photonest/domain/entities/backup_notification.dart';
import 'package:photonest/domain/entities/device_album.dart';
import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/entities/signed_media_url.dart';
import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/entities/upload_failure.dart';
import 'package:photonest/domain/entities/upload_resumption.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/repositories/album_repository.dart';
import 'package:photonest/domain/repositories/album_snapshot_repository.dart';
import 'package:photonest/domain/repositories/api_endpoint_repository.dart';
import 'package:photonest/domain/repositories/app_info_repository.dart';
import 'package:photonest/domain/repositories/auth_repository.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';
import 'package:photonest/domain/repositories/backup_notification_repository.dart';
import 'package:photonest/domain/repositories/debug_settings_repository.dart';
import 'package:photonest/domain/repositories/language_preference_repository.dart';
import 'package:photonest/domain/repositories/media_curation_repository.dart';
import 'package:photonest/domain/repositories/media_library_repository.dart';
import 'package:photonest/domain/repositories/media_original_repository.dart';
import 'package:photonest/domain/repositories/media_playback_repository.dart';
import 'package:photonest/domain/repositories/media_tag_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_url_repository.dart';
import 'package:photonest/domain/repositories/photo_upload_repository.dart';
import 'package:photonest/domain/repositories/session_repository.dart';
import 'package:photonest/domain/repositories/sync_lease_repository.dart';
import 'package:photonest/domain/repositories/theme_preference_repository.dart';
import 'package:photonest/domain/repositories/upload_failure_repository.dart';
import 'package:photonest/domain/repositories/upload_history_repository.dart';
import 'package:photonest/domain/repositories/upload_resumption_repository.dart';
import 'package:photonest/domain/value_objects/album_id.dart';
import 'package:photonest/domain/value_objects/app_language.dart';
import 'package:photonest/domain/value_objects/app_theme_mode.dart';
import 'package:photonest/domain/value_objects/log_level.dart';
import 'package:photonest/domain/value_objects/login_credentials.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';
import 'package:photonest/domain/value_objects/tag_id.dart';

/// In-memory repository doubles.
///
/// Each one records what was written so a test can assert on the outbound
/// call, and each can be told to fail so error paths are reachable.

final class FakeThemePreferenceRepository implements ThemePreferenceRepository {
  FakeThemePreferenceRepository([this._mode = AppThemeMode.light]);

  AppThemeMode _mode;
  final List<AppThemeMode> saved = <AppThemeMode>[];

  /// When true, [save] throws instead of storing.
  bool failOnSave = false;

  @override
  AppThemeMode get() => _mode;

  @override
  Future<void> save(AppThemeMode mode) async {
    if (failOnSave) throw Exception('theme storage unavailable');
    saved.add(mode);
    _mode = mode;
  }
}

final class FakeLanguagePreferenceRepository
    implements LanguagePreferenceRepository {
  FakeLanguagePreferenceRepository([this._language = AppLanguage.system]);

  AppLanguage _language;
  final List<AppLanguage> saved = <AppLanguage>[];

  bool failOnSave = false;

  @override
  AppLanguage get() => _language;

  @override
  Future<void> save(AppLanguage language) async {
    if (failOnSave) throw Exception('language storage unavailable');
    saved.add(language);
    _language = language;
  }
}

final class FakeDebugSettingsRepository implements DebugSettingsRepository {
  FakeDebugSettingsRepository({
    this.debugMode = true,
    this.minLogLevel = LogLevel.debug,
  });

  // Public and mutable on purpose: a test can seed or inspect the stored
  // value directly, which is the whole job of a fake.
  bool debugMode;
  LogLevel minLogLevel;

  final List<bool> savedDebugModes = <bool>[];
  final List<LogLevel> savedLogLevels = <LogLevel>[];

  @override
  bool getDebugModeEnabled() => debugMode;

  @override
  LogLevel getMinLogLevel() => minLogLevel;

  @override
  Future<void> saveDebugModeEnabled(bool enabled) async {
    savedDebugModes.add(enabled);
    debugMode = enabled;
  }

  @override
  Future<void> saveMinLogLevel(LogLevel level) async {
    savedLogLevels.add(level);
    minLogLevel = level;
  }
}

/// Canonical app metadata for tests that only need *some* values.
const AppInfo testAppInfo = AppInfo(
  version: '1.2.3',
  buildNumber: '42',
  gitCommit: 'abc1234',
  gitCommitFull: 'abc1234def5678',
  flutterVersion: '3.44.8',
  dartVersion: '3.12.2',
  buildDate: '2026-08-03T00:00:00Z',
  isDebug: true,
);

final class FakeAppInfoRepository implements AppInfoRepository {
  FakeAppInfoRepository({this.info, this.failure});

  final AppInfo? info;

  /// When set, [getAppInfo] throws this instead of returning.
  final Object? failure;

  int callCount = 0;

  @override
  Future<AppInfo> getAppInfo() async {
    callCount++;
    if (failure != null) throw Exception('$failure');
    return info ?? testAppInfo;
  }
}

/// A fixed instant for notification fixtures, so tests never reason about
/// the wall clock.
final DateTime testNotificationOccurredAt = DateTime.utc(2026, 8, 8, 9, 30);

/// Builds a stored notification without going through a repository.
BackupNotification testBackupNotification({
  int id = 1,
  int uploadedCount = 3,
  int failedCount = 0,
  DateTime? occurredAt,
  bool isRead = false,
}) {
  return BackupNotification(
    id: id,
    uploadedCount: uploadedCount,
    failedCount: failedCount,
    occurredAt: occurredAt ?? testNotificationOccurredAt,
    isRead: isRead,
  );
}

/// In-memory [BackupNotificationRepository].
///
/// Assigns ids the way SQLite does — monotonically, never reusing one.
final class FakeBackupNotificationRepository
    implements BackupNotificationRepository {
  FakeBackupNotificationRepository([List<BackupNotification>? initial]) {
    for (final notification in initial ?? const <BackupNotification>[]) {
      _stored[notification.id] = notification;
      if (notification.id >= _nextId) _nextId = notification.id + 1;
    }
  }

  final Map<int, BackupNotification> _stored = <int, BackupNotification>{};
  int _nextId = 1;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// When set, every method throws this instead of answering.
  AppError? failure;

  /// The id batches [markRead] was asked to mark, in call order.
  final List<List<int>> markReadCalls = <List<int>>[];

  List<BackupNotification> get stored => _stored.values.toList();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<List<BackupNotification>> findAll() async {
    _failIfAsked();
    final all = _stored.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    return all;
  }

  @override
  Future<BackupNotification> add({
    required int uploadedCount,
    required int failedCount,
    required DateTime occurredAt,
  }) async {
    _failIfAsked();
    final notification = BackupNotification(
      id: _nextId++,
      uploadedCount: uploadedCount,
      failedCount: failedCount,
      occurredAt: occurredAt,
    );
    _stored[notification.id] = notification;
    _changes.add(null);
    return notification;
  }

  @override
  Future<int> unreadCount() async {
    _failIfAsked();
    return _stored.values.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markRead(List<int> ids) async {
    _failIfAsked();
    markReadCalls.add(List.of(ids));
    for (final id in ids) {
      final n = _stored[id];
      if (n == null) continue;
      _stored[id] = BackupNotification(
        id: n.id,
        uploadedCount: n.uploadedCount,
        failedCount: n.failedCount,
        occurredAt: n.occurredAt,
        isRead: true,
      );
    }
    _changes.add(null);
  }

  void _failIfAsked() {
    final error = failure;
    if (error != null) throw error;
  }
}

// ─── PhotoNest fakes ───────────────────────────────────────────────────────

/// A ready-made session for tests that just need to be "signed in".
///
/// Carries what the server's ordinary member role grants, because screens now
/// drop the controls a session has no permission for: a thinner scope list
/// here would silently stop testing the tag, favourite, trash and upload
/// paths. Use [restrictedTestAuthSession] to test what a reader without them
/// sees.
final AuthSession testAuthSession = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  email: 'user@example.com',
  scopes: const [
    'gui:view',
    'album:view',
    'media:view',
    'media:upload',
    'media:tag-manage',
    'media:metadata-manage',
    'media:delete',
  ],
);

/// A session that may look at the library and nothing else — the read-only
/// role the server hands out.
final AuthSession restrictedTestAuthSession = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  email: 'reader@example.com',
  scopes: const ['gui:view', 'album:view', 'media:view'],
);

/// A fixed capture instant, so tests never reason about the wall clock.
final DateTime testPhotoTakenAt = DateTime.utc(2026, 8, 3, 12, 30);

/// A real, decodable 1×1 transparent PNG.
///
/// Thumbnail fakes must return this rather than arbitrary bytes: the widgets
/// hand the payload to `Image.memory`, and an undecodable buffer turns every
/// screen test into an image-codec exception.
final Uint8List testPngBytes = Uint8List.fromList(const [
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00, //
  0x0b, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x60, 0x00, 0x02, 0x00, //
  0x00, 0x05, 0x00, 0x01, 0x7a, 0x5e, 0xab, 0x3f, 0x00, 0x00, 0x00, 0x00, //
  0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);

/// Builds a device photo without going through the platform gateway.
LocalPhoto testLocalPhoto({
  String localId = 'asset-1',
  String fileName = 'IMG_0001.jpg',
  DateTime? takenAt,
  bool isVideo = false,
}) {
  return LocalPhoto(
    localId: localId,
    fileName: fileName,
    takenAt: takenAt ?? testPhotoTakenAt,
    isVideo: isVideo,
  );
}

/// Builds a server album without going through a repository.
Album testAlbum({
  int id = 1,
  String title = 'Trip',
  int mediaCount = 2,
  int? coverMediaId = 10,
}) {
  return Album(
    id: AlbumId(id),
    title: title,
    mediaCount: mediaCount,
    coverMediaId: coverMediaId == null ? null : MediaId(coverMediaId),
    createdAt: DateTime.utc(2026),
  );
}

/// Builds one server media item.
MediaItem testMediaItem({
  int id = 10,
  String filename = 'a.jpg',
  bool isVideo = false,
  DateTime? shotAt,
}) {
  return MediaItem(
    id: MediaId(id),
    filename: filename,
    shotAt: shotAt ?? testPhotoTakenAt,
    isVideo: isVideo,
  );
}

/// Builds one server media item the server has no capture instant for.
MediaItem testMediaItemWithoutShotAt({int id = 10, String filename = 'a.jpg'}) {
  return MediaItem(id: MediaId(id), filename: filename);
}

/// In-memory [UploadFailureRepository].
final class FakeUploadFailureRepository implements UploadFailureRepository {
  final Map<String, UploadFailure> failures = <String, UploadFailure>{};

  // ignore: close_sinks
  final StreamController<void> changed = StreamController<void>.broadcast();

  /// When set, [record] throws this instead of storing.
  AppError? recordFailure;

  /// When set, [clear] throws this instead of forgetting.
  AppError? clearFailure;

  @override
  Stream<void> get changes => changed.stream;

  @override
  Future<List<UploadFailure>> list() async {
    final all = failures.values.toList()
      ..sort((a, b) => b.failedAt.compareTo(a.failedAt));
    return all;
  }

  @override
  Future<void> record({
    required LocalPhoto photo,
    required UploadFailureReason reason,
    required String message,
    required bool automatic,
    required DateTime failedAt,
  }) async {
    final error = recordFailure;
    if (error != null) throw error;
    failures[photo.localId] = UploadFailure(
      photo: photo,
      reason: reason,
      message: message,
      failedAt: failedAt,
      attempts: (failures[photo.localId]?.attempts ?? 0) + 1,
      automatic: automatic,
    );
    changed.add(null);
  }

  @override
  Future<void> clear(String localId) async {
    final error = clearFailure;
    if (error != null) throw error;
    if (failures.remove(localId) != null) changed.add(null);
  }

  @override
  Future<void> clearAll() async {
    if (failures.isEmpty) return;
    failures.clear();
    changed.add(null);
  }
}

/// In-memory [MediaOriginalRepository].
final class FakeMediaOriginalRepository implements MediaOriginalRepository {
  /// URL handed back by [originalOf].
  Uri url = Uri.parse('https://photos.example.com/api/dl/original-token');

  /// Bytes handed back by [downloadOriginal].
  Uint8List bytes = Uint8List.fromList(const [1, 2, 3]);

  /// Media ids [originalOf] was asked for, in order.
  final List<MediaId> requested = <MediaId>[];

  /// Media ids [downloadOriginal] was asked for, in order.
  final List<MediaId> downloaded = <MediaId>[];

  /// When set, every method throws this instead of answering.
  AppError? failure;

  @override
  Future<SignedMediaUrl> originalOf(MediaId id) async {
    requested.add(id);
    final error = failure;
    if (error != null) throw error;
    return SignedMediaUrl(url: url);
  }

  @override
  Future<Uint8List> downloadOriginal(MediaId id) async {
    downloaded.add(id);
    final error = failure;
    if (error != null) throw error;
    return bytes;
  }
}

/// In-memory [MediaLibraryRepository].
///
/// Answers from [media] by slicing it the way the server would, so a test
/// sets up one list and the paging falls out of it.
final class FakeMediaLibraryRepository implements MediaLibraryRepository {
  FakeMediaLibraryRepository({List<MediaItem>? media})
    : media = media ?? <MediaItem>[];

  List<MediaItem> media;

  /// Pages requested, in order, as (cursor, pageSize). The first window's
  /// cursor is null.
  final List<(String?, int)> requestedPages = <(String?, int)>[];

  /// Narrowings requested, in order. Lets a test assert that the timeline
  /// re-read the library when the reader changed the search.
  final List<MediaLibraryQuery> requestedQueries = <MediaLibraryQuery>[];

  /// When set, only media whose filename contains this fake's idea of a
  /// match is answered — enough to tell "the search reached the server"
  /// from "the list was filtered on the device".
  bool Function(MediaItem item, MediaLibraryQuery query)? matches;

  /// When set, every request throws this instead of answering.
  AppError? failure;

  /// When set, awaited before each request is answered — lets a test hold a
  /// page mid-flight and restart the timeline underneath it.
  Future<void> Function()? gate;

  /// Media in the trash, answered by [findTrashPage].
  List<MediaItem> trashed = <MediaItem>[];

  /// Trash windows requested, in order, as (cursor, pageSize).
  final List<(String?, int)> requestedTrashPages = <(String?, int)>[];

  /// The cursor is the offset of the next item, spelled the way the server
  /// spells it: opaque to the caller, meaningful only here.
  static const String _cursorPrefix = 'after:';

  @override
  Future<MediaLibraryPage> findPage({
    String? cursor,
    int pageSize = 100,
    MediaLibraryQuery query = const MediaLibraryQuery(),
  }) async {
    requestedPages.add((cursor, pageSize));
    requestedQueries.add(query);
    await gate?.call();
    final error = failure;
    if (error != null) throw error;
    final predicate = matches;
    final source = predicate == null
        ? media
        : media.where((item) => predicate(item, query)).toList(growable: false);
    final start = cursor == null
        ? 0
        : int.parse(cursor.substring(_cursorPrefix.length));
    if (start >= source.length) {
      return const MediaLibraryPage(items: <MediaItem>[], nextCursor: null);
    }
    final end = start + pageSize;
    final hasNext = end < source.length;
    return MediaLibraryPage(
      items: source.sublist(start, hasNext ? end : source.length),
      nextCursor: hasNext ? '$_cursorPrefix$end' : null,
    );
  }

  @override
  Future<MediaLibraryPage> findTrashPage({
    String? cursor,
    int pageSize = 100,
  }) async {
    requestedTrashPages.add((cursor, pageSize));
    await gate?.call();
    final error = failure;
    if (error != null) throw error;
    final start = cursor == null
        ? 0
        : int.parse(cursor.substring(_cursorPrefix.length));
    if (start >= trashed.length) {
      return const MediaLibraryPage(items: <MediaItem>[], nextCursor: null);
    }
    final end = start + pageSize;
    final hasNext = end < trashed.length;
    return MediaLibraryPage(
      items: trashed.sublist(start, hasNext ? end : trashed.length),
      nextCursor: hasNext ? '$_cursorPrefix$end' : null,
    );
  }
}

/// In-memory [AuthRepository].
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthSession? session}) : sessionToReturn = session;

  /// Session handed back by [login]; defaults to a session built from the
  /// submitted credentials.
  AuthSession? sessionToReturn;

  /// When set, every method throws this instead of answering.
  AppError? failure;

  /// When set, every method throws this raw (non-[AppError]) object —
  /// models a platform/plugin blowing up outside the typed error contract.
  Object? unexpectedFailure;

  final List<LoginCredentials> logins = <LoginCredentials>[];
  final List<AuthSession> loggedOut = <AuthSession>[];

  @override
  Future<AuthSession> login(LoginCredentials credentials) async {
    _failIfAsked();
    logins.add(credentials);
    return sessionToReturn ??
        AuthSession(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          email: credentials.email,
          scopes: const ['gui:view'],
        );
  }

  @override
  Future<void> logout(AuthSession session) async {
    _failIfAsked();
    loggedOut.add(session);
  }

  void _failIfAsked() {
    final unexpected = unexpectedFailure;
    if (unexpected != null) throw unexpected; // ignore: only_throw_errors
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory [SessionRepository].
final class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository([this._session]);

  AuthSession? _session;
  final List<AuthSession> saved = <AuthSession>[];
  int cleared = 0;

  /// Left open for the fake's lifetime, like the platform broadcast fakes.
  // ignore: close_sinks
  final StreamController<AuthSession?> _changes =
      StreamController<AuthSession?>.broadcast();

  @override
  AuthSession? load() => _session;

  @override
  Future<void> save(AuthSession session) async {
    saved.add(session);
    _session = session;
    _changes.add(session);
  }

  @override
  Future<void> clear() async {
    cleared++;
    _session = null;
    _changes.add(null);
  }

  @override
  Stream<AuthSession?> get changes => _changes.stream;
}

/// In-memory [ApiEndpointRepository].
final class FakeApiEndpointRepository implements ApiEndpointRepository {
  FakeApiEndpointRepository([this._baseUrl]);

  Uri? _baseUrl;
  final List<Uri> saved = <Uri>[];

  @override
  Uri? load() => _baseUrl;

  @override
  Future<void> save(Uri baseUrl) async {
    saved.add(baseUrl);
    _baseUrl = baseUrl;
  }
}

/// In-memory [AlbumRepository].
final class FakeAlbumRepository implements AlbumRepository {
  FakeAlbumRepository({List<Album>? albums, Map<AlbumId, AlbumDetail>? details})
    : albums = albums ?? <Album>[],
      details = details ?? <AlbumId, AlbumDetail>{};

  List<Album> albums;
  Map<AlbumId, AlbumDetail> details;

  /// When false, [findById] omits `mediaTotal` — models a server that does
  /// not report the album's total media count.
  bool reportsMediaTotal = true;

  /// When set, every method throws this instead of answering.
  AppError? failure;

  /// When set, awaited before each request is answered (or fails) — lets a
  /// test change the signed-in identity while the request is in flight.
  Future<void> Function()? gate;

  @override
  Future<List<Album>> findAll() async {
    await gate?.call();
    _failIfAsked();
    return albums;
  }

  /// Every (id, mediaPage, mediaPageSize) triple [findById] was asked for.
  final List<(AlbumId, int, int)> mediaPageRequests = <(AlbumId, int, int)>[];

  @override
  Future<AlbumDetail?> findById(
    AlbumId id, {
    int mediaPage = 1,
    int mediaPageSize = 100,
  }) async {
    await gate?.call();
    _failIfAsked();
    mediaPageRequests.add((id, mediaPage, mediaPageSize));
    final detail = details[id];
    if (detail == null) return null;
    // Pages the seeded media the way the server would, so notifier tests
    // exercise real accumulation.
    final page = detail.media
        .skip((mediaPage - 1) * mediaPageSize)
        .take(mediaPageSize)
        .toList();
    return AlbumDetail(
      album: detail.album,
      media: page,
      mediaTotal: reportsMediaTotal ? detail.media.length : null,
    );
  }

  void _failIfAsked() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory [AlbumSnapshotRepository].
final class FakeAlbumSnapshotRepository implements AlbumSnapshotRepository {
  /// The saved album list, or null when nothing was ever saved.
  List<Album>? savedAlbums;

  /// Saved detail pages by (album id, media page, media page size).
  final Map<(int, int, int), AlbumDetail> savedDetails =
      <(int, int, int), AlbumDetail>{};

  /// How many times [saveAlbums] was called.
  int albumSaveCount = 0;

  /// Album ids [removeDetail] was asked to forget, in call order.
  final List<AlbumId> removedDetails = <AlbumId>[];

  /// When set, every method throws this instead of answering.
  AppError? failure;

  @override
  Future<void> saveAlbums(List<Album> albums) async {
    _failIfAsked();
    albumSaveCount++;
    savedAlbums = List.of(albums);
    // The interface contract: a full list is authoritative, so detail pages
    // of albums it no longer holds are forgotten in the same save.
    final visible = albums.map((album) => album.id.value).toSet();
    savedDetails.removeWhere((key, _) => !visible.contains(key.$1));
  }

  @override
  Future<List<Album>?> findAlbums() async {
    _failIfAsked();
    return savedAlbums;
  }

  @override
  Future<void> saveDetail(
    AlbumDetail detail, {
    required int mediaPage,
    required int mediaPageSize,
  }) async {
    _failIfAsked();
    savedDetails[(detail.album.id.value, mediaPage, mediaPageSize)] = detail;
  }

  @override
  Future<AlbumDetail?> findDetail(
    AlbumId id, {
    required int mediaPage,
    required int mediaPageSize,
  }) async {
    _failIfAsked();
    return savedDetails[(id.value, mediaPage, mediaPageSize)];
  }

  @override
  Future<void> removeDetail(AlbumId id) async {
    _failIfAsked();
    removedDetails.add(id);
    savedDetails.removeWhere((key, _) => key.$1 == id.value);
  }

  void _failIfAsked() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory [MediaCurationRepository].
final class FakeMediaCurationRepository implements MediaCurationRepository {
  /// Favourite state as this fake holds it, by media id.
  final Map<int, bool> favorites = <int, bool>{};

  /// Media moved to the trash, in order.
  final List<MediaId> trashed = <MediaId>[];

  /// Media restored, in order.
  final List<MediaId> restored = <MediaId>[];

  /// When set, every call throws this instead of answering.
  AppError? failure;

  /// When set, the server settles on this instead of what was asked for —
  /// stands in for another device having changed it in between.
  bool? settleFavoriteAt;

  /// When set, awaited before each call is answered — lets a test hold one
  /// request in flight and start another for a different media item.
  Future<void> Function()? gate;

  @override
  Future<bool> setFavorite(MediaId id, {required bool favorite}) async {
    await gate?.call();
    _failIfAsked();
    final settled = settleFavoriteAt ?? favorite;
    favorites[id.value] = settled;
    return settled;
  }

  @override
  Future<void> moveToTrash(MediaId id) async {
    await gate?.call();
    _failIfAsked();
    trashed.add(id);
  }

  @override
  Future<void> restore(MediaId id) async {
    await gate?.call();
    _failIfAsked();
    restored.add(id);
  }

  void _failIfAsked() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// Builds one library tag.
Tag testTag({int id = 1, String name = 'Kyoto', TagAttribute? attribute}) {
  return Tag(id: TagId(id), name: name, attribute: attribute);
}

/// In-memory [MediaTagRepository].
final class FakeMediaTagRepository implements MediaTagRepository {
  /// Every tag the library holds, in the order the server would answer.
  List<Tag> library = <Tag>[];

  /// Which tags each media item carries, by media id.
  final Map<int, List<Tag>> byMedia = <int, List<Tag>>{};

  /// The (query, limit) pairs [findAll] was asked for, in order.
  final List<(String, int)> suggestQueries = <(String, int)>[];

  /// The replacements applied, in order.
  final List<(MediaId, List<TagId>)> replacements = <(MediaId, List<TagId>)>[];

  /// When set, the server settles on this instead of what was asked for —
  /// stands in for another device having changed the tags in between.
  List<Tag>? settleTagsAt;

  /// When set, every call throws this instead of answering.
  AppError? failure;

  @override
  Future<List<Tag>> findAll({String query = '', int limit = 20}) async {
    _failIfAsked();
    suggestQueries.add((query, limit));
    return [
      for (final tag in library)
        if (query.isEmpty ||
            tag.name.toLowerCase().contains(query.toLowerCase()))
          tag,
    ].take(limit).toList(growable: false);
  }

  @override
  Future<List<Tag>> findByMedia(MediaId id) async {
    _failIfAsked();
    return List<Tag>.unmodifiable(byMedia[id.value] ?? const <Tag>[]);
  }

  @override
  Future<List<Tag>> replaceMediaTags(MediaId id, List<TagId> tagIds) async {
    _failIfAsked();
    replacements.add((id, tagIds));
    final settled =
        settleTagsAt ??
        [
          for (final tagId in tagIds)
            library.firstWhere(
              (Tag tag) => tag.id == tagId,
              orElse: () => Tag(id: tagId, name: 'tag-${tagId.value}'),
            ),
        ];
    byMedia[id.value] = settled;
    return List<Tag>.unmodifiable(settled);
  }

  void _failIfAsked() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory [MediaThumbnailRepository] returning a fixed byte pattern.
final class FakeMediaThumbnailRepository implements MediaThumbnailRepository {
  /// Reads that went through the app server, one round trip each.
  final List<(MediaId, int)> fetched = <(MediaId, int)>[];

  /// Reads that went through a signed URL (proxy or CDN edge).
  final List<SignedMediaUrl> fetchedFrom = <SignedMediaUrl>[];

  AppError? failure;

  /// When set, only signed-URL reads throw it — lets a test check the
  /// fallback to the app server.
  AppError? signedFailure;

  @override
  Future<Uint8List> fetch(MediaId id, {required int size}) async {
    final error = failure;
    if (error != null) throw error;
    fetched.add((id, size));
    return testPngBytes;
  }

  @override
  Future<Uint8List> fetchFrom(SignedMediaUrl url) async {
    final error = signedFailure ?? failure;
    if (error != null) throw error;
    fetchedFrom.add(url);
    return testPngBytes;
  }
}

/// In-memory [MediaThumbnailUrlRepository] that issues a URL per media item.
final class FakeMediaThumbnailUrlRepository
    implements MediaThumbnailUrlRepository {
  /// Batches asked for, in order — the point of the batching is that this
  /// stays short while the grid is long.
  final List<(List<MediaId>, int)> issued = <(List<MediaId>, int)>[];

  /// Media the server refuses to issue for (deleted, purged).
  final Set<int> unissuable = <int>{};

  /// Every thumbnail asked for, flattened to (media, size) — what a test
  /// means by "the grid requested this rendition", whichever batch it
  /// travelled in.
  List<(MediaId, int)> get requested => [
    for (final (ids, size) in issued)
      for (final id in ids) (id, size),
  ];

  AppError? failure;

  @override
  Future<Map<MediaId, SignedMediaUrl>> issue(
    List<MediaId> ids, {
    required int size,
  }) async {
    issued.add((List<MediaId>.of(ids), size));
    final error = failure;
    if (error != null) throw error;
    return {
      for (final id in ids)
        if (!unissuable.contains(id.value))
          id: SignedMediaUrl(
            url: Uri.parse('https://cdn.example.com/thumb/${id.value}/$size'),
          ),
    };
  }
}

/// In-memory [MediaThumbnailCacheRepository].
final class FakeMediaThumbnailCacheRepository
    implements MediaThumbnailCacheRepository {
  /// Stored bytes by (media id, size).
  final Map<(int, int), Uint8List> entries = <(int, int), Uint8List>{};
  final List<(MediaId, int)> saved = <(MediaId, int)>[];

  /// When set, every method throws this instead of answering.
  AppError? failure;

  @override
  Future<Uint8List?> find(MediaId id, {required int size}) async {
    _failIfAsked();
    return entries[(id.value, size)];
  }

  @override
  Future<void> save(
    MediaId id, {
    required int size,
    required Uint8List bytes,
    required DateTime fetchedAt,
  }) async {
    _failIfAsked();
    entries[(id.value, size)] = bytes;
    saved.add((id, size));
  }

  void _failIfAsked() {
    final error = failure;
    if (error != null) throw error;
  }
}

/// In-memory [MediaPlaybackRepository] issuing a fixed source per media id.
final class FakeMediaPlaybackRepository implements MediaPlaybackRepository {
  final Map<int, SignedMediaUrl> sources = <int, SignedMediaUrl>{};
  final List<MediaId> requested = <MediaId>[];

  /// When set, [sourceOf] throws this instead of answering.
  AppError? failure;

  @override
  Future<SignedMediaUrl> sourceOf(MediaId id) async {
    requested.add(id);
    final error = failure;
    if (error != null) throw error;
    final source = sources[id.value];
    if (source == null) {
      throw const InfrastructureError('No playback.', code: 'not_found');
    }
    return source;
  }
}

/// In-memory [SyncLeaseRepository].
final class FakeSyncLeaseRepository implements SyncLeaseRepository {
  /// When set, [tryAcquire] refuses as though this holder had the lease.
  String? heldBy;

  final List<String> acquiredBy = <String>[];
  final List<String> releasedBy = <String>[];

  @override
  Future<bool> tryAcquire(
    String holder, {
    required DateTime until,
    required DateTime now,
  }) async {
    if (heldBy != null && heldBy != holder) return false;
    heldBy = holder;
    acquiredBy.add(holder);
    return true;
  }

  @override
  Future<void> release(String holder) async {
    releasedBy.add(holder);
    if (heldBy == holder) heldBy = null;
  }
}

/// Records scheduling calls instead of talking to WorkManager.
final class FakeBackgroundSyncScheduler implements BackgroundSyncScheduler {
  int scheduleRequests = 0;
  int cancelRequests = 0;

  /// The `unmeteredOnly` flag of every registration, in order.
  final List<bool> scheduledUnmeteredOnly = <bool>[];

  @override
  Future<void> ensureScheduled({required bool unmeteredOnly}) async {
    scheduleRequests++;
    scheduledUnmeteredOnly.add(unmeteredOnly);
  }

  @override
  Future<void> cancel() async {
    cancelRequests++;
  }
}

/// Records uploads instead of sending them.
final class FakePhotoUploadRepository implements PhotoUploadRepository {
  final List<(LocalPhoto, Uint8List)> uploaded = <(LocalPhoto, Uint8List)>[];

  /// When set, [upload] throws for photos whose id is in [failFor] (or for
  /// every photo when [failFor] is empty).
  AppError? failure;
  Set<String> failFor = <String>{};

  /// When set, awaited before each upload — lets a test hold a batch
  /// mid-flight to observe its progress or cancel it.
  Future<void> Function(LocalPhoto photo)? gate;

  /// Uploads that came in as file paths, in order.
  final List<(LocalPhoto, String)> uploadedFromPath = <(LocalPhoto, String)>[];

  /// Byte-progress steps every upload reports, as (sent, total). A test
  /// sets this to drive a progress bar without a real transfer.
  List<(int, int)> byteProgress = const <(int, int)>[];

  @override
  Future<void> upload(
    LocalPhoto photo,
    Uint8List bytes, {
    UploadBytesProgress? onBytes,
  }) async {
    await _admit(photo);
    for (final (sent, total) in byteProgress) {
      onBytes?.call(sent, total);
    }
    uploaded.add((photo, bytes));
  }

  @override
  Future<void> uploadFromPath(
    LocalPhoto photo,
    String path, {
    UploadBytesProgress? onBytes,
  }) async {
    await _admit(photo);
    for (final (sent, total) in byteProgress) {
      onBytes?.call(sent, total);
    }
    uploadedFromPath.add((photo, path));
  }

  Future<void> _admit(LocalPhoto photo) async {
    await gate?.call(photo);
    final error = failure;
    if (error != null && (failFor.isEmpty || failFor.contains(photo.localId))) {
      throw error;
    }
  }
}

/// In-memory [UploadHistoryRepository].
final class FakeUploadHistoryRepository implements UploadHistoryRepository {
  FakeUploadHistoryRepository([Set<String>? uploaded])
    : _uploaded = uploaded ?? <String>{};

  final Set<String> _uploaded;
  final List<LocalPhoto> marked = <LocalPhoto>[];

  /// When true, [uploadedLocalIds] throws instead of answering.
  bool failOnRead = false;

  @override
  Future<Set<String>> uploadedLocalIds() async {
    if (failOnRead) {
      throw const InfrastructureError('history unavailable');
    }
    return Set.of(_uploaded);
  }

  @override
  Future<void> markUploaded(LocalPhoto photo, DateTime uploadedAt) async {
    marked.add(photo);
    _uploaded.add(photo.localId);
  }
}

/// In-memory [UploadResumptionRepository].
final class FakeUploadResumptionRepository
    implements UploadResumptionRepository {
  final Map<String, UploadResumption> stored = <String, UploadResumption>{};

  /// Ids passed to [clear], in order.
  final List<String> cleared = <String>[];

  /// When set, every method throws this instead of answering.
  AppError? failure;

  @override
  Future<UploadResumption?> find(String localId) async {
    final error = failure;
    if (error != null) throw error;
    return stored[localId];
  }

  @override
  Future<void> save(UploadResumption resumption) async {
    final error = failure;
    if (error != null) throw error;
    stored[resumption.localId] = resumption;
  }

  @override
  Future<void> clear(String localId, {required String tempFileId}) async {
    final error = failure;
    if (error != null) throw error;
    cleared.add(localId);
    // Scoped like the real store: a row that now belongs to another upload
    // of the same photo is not this caller's to delete.
    if (stored[localId]?.tempFileId == tempFileId) stored.remove(localId);
  }
}

/// In-memory [AutoUploadSettingsRepository].
final class FakeAutoUploadSettingsRepository
    implements AutoUploadSettingsRepository {
  FakeAutoUploadSettingsRepository({
    this.enabled = false,
    this.since,
    this.unmeteredOnly = true,
    Set<String>? albumIds,
  }) : albumIds = albumIds ?? <String>{};

  bool enabled;
  DateTime? since;

  /// Mirrors the production default: restricted to unmetered connections
  /// until the user says otherwise.
  bool unmeteredOnly;

  /// Mirrors the production default: empty means the whole library.
  Set<String> albumIds;
  final List<bool> savedStates = <bool>[];
  final List<bool> savedUnmeteredOnly = <bool>[];
  final List<Set<String>> savedAlbumIds = <Set<String>>[];

  @override
  bool isEnabled() => enabled;

  @override
  DateTime? enabledSince() => since;

  @override
  bool isUnmeteredOnly() => unmeteredOnly;

  @override
  Future<void> setEnabled(bool value) async {
    savedStates.add(value);
    enabled = value;
    if (value) since ??= testPhotoTakenAt;
  }

  @override
  Future<void> setUnmeteredOnly(bool value) async {
    savedUnmeteredOnly.add(value);
    unmeteredOnly = value;
  }

  @override
  Set<String> backupAlbumIds() => albumIds;

  @override
  Future<void> setBackupAlbumIds(Set<String> value) async {
    savedAlbumIds.add(value);
    albumIds = value;
  }
}

/// In-memory [NetworkConnectionGateway].
final class FakeNetworkConnectionGateway implements NetworkConnectionGateway {
  FakeNetworkConnectionGateway({this.unmetered = true});

  bool unmetered;
  int checks = 0;

  /// Scripted answers, one per call, for tests that need the connection to
  /// change part-way through a batch. Falls back to [unmetered] once
  /// exhausted.
  List<bool> scriptedAnswers = <bool>[];

  @override
  Future<bool> isUnmetered() async {
    final index = checks++;
    if (index < scriptedAnswers.length) return scriptedAnswers[index];
    return unmetered;
  }
}

/// In-memory [PhotoLibraryGateway].
///
/// [changes] is a broadcast controller a test can push events into to
/// simulate the platform's library-change broadcast.
final class FakePhotoLibraryGateway implements PhotoLibraryGateway {
  FakePhotoLibraryGateway({
    this.accessGranted = true,
    List<LocalPhoto>? photos,
    List<DeviceAlbum>? deviceAlbums,
    Map<String, List<LocalPhoto>>? photosByAlbum,
  }) : photos = photos ?? <LocalPhoto>[],
       deviceAlbums = deviceAlbums ?? <DeviceAlbum>[],
       photosByAlbum = photosByAlbum ?? <String, List<LocalPhoto>>{};

  bool accessGranted;
  List<LocalPhoto> photos;

  /// What [albums] answers.
  List<DeviceAlbum> deviceAlbums;

  /// Photos per album id. An album missing here holds nothing — which is
  /// also how a deleted album reads.
  final Map<String, List<LocalPhoto>> photosByAlbum;

  /// Bytes per local id; a photo missing here reads back as null.
  final Map<String, Uint8List> bytesById = <String, Uint8List>{};

  /// File path per local id; a photo missing here has no platform file and
  /// uploads fall back to [bytesById].
  final Map<String, String> filePathById = <String, String>{};
  final Map<String, Uint8List> thumbnailsById = <String, Uint8List>{};

  // Deliberately left open for the fake's lifetime: tests push events into
  // it to simulate the platform broadcast, and the test process ends before
  // "leaking" matters. The lint has a point for production code only.
  // ignore: close_sinks
  final StreamController<void> changes = StreamController<void>.broadcast();

  int accessRequests = 0;
  final List<DateTime?> queriedSince = <DateTime?>[];

  /// Album ids the gateway was queried with, in order. Null is the whole
  /// library.
  final List<String?> queriedAlbumIds = <String?>[];

  @override
  Future<bool> ensureAccess() async {
    accessRequests++;
    return accessGranted;
  }

  @override
  Future<List<DeviceAlbum>> albums() async => deviceAlbums;

  @override
  Future<List<LocalPhoto>> photosTakenAfter(
    DateTime? since, {
    int limit = 100,
    int page = 0,
    String? albumId,
  }) async {
    queriedSince.add(since);
    queriedAlbumIds.add(albumId);
    final source = albumId == null
        ? photos
        : photosByAlbum[albumId] ?? const <LocalPhoto>[];
    return source
        .where((photo) => since == null || photo.takenAt.isAfter(since))
        .skip(page * limit)
        .take(limit)
        .toList();
  }

  @override
  Future<Uint8List?> readOriginalBytes(String localId) async =>
      bytesById[localId];

  @override
  Future<String?> originalFilePath(String localId) async =>
      filePathById[localId];

  @override
  Future<Uint8List?> readThumbnail(String localId, {required int size}) async =>
      thumbnailsById[localId];

  /// Assets handed to [saveToLibrary], in order.
  final List<(String, Uint8List, bool)> savedToLibrary =
      <(String, Uint8List, bool)>[];

  /// When false, [saveToLibrary] refuses — models a denied media-store
  /// grant.
  bool saveGranted = true;

  @override
  Future<bool> saveToLibrary({
    required String fileName,
    required Uint8List bytes,
    required bool isVideo,
  }) async {
    if (!saveGranted || !accessGranted) return false;
    savedToLibrary.add((fileName, bytes, isVideo));
    return true;
  }

  @override
  Stream<void> get libraryChanges => changes.stream;
}
