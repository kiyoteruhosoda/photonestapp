import 'dart:async';
import 'dart:typed_data';

import 'package:flutterbase/application/ports/background_sync_scheduler.dart';
import 'package:flutterbase/application/ports/network_connection_gateway.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/entities/backup_notification.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/entities/media_item.dart';
import 'package:flutterbase/domain/entities/media_library_page.dart';
import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/repositories/album_snapshot_repository.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/app_info_repository.dart';
import 'package:flutterbase/domain/repositories/auth_repository.dart';
import 'package:flutterbase/domain/repositories/auto_upload_settings_repository.dart';
import 'package:flutterbase/domain/repositories/backup_notification_repository.dart';
import 'package:flutterbase/domain/repositories/debug_settings_repository.dart';
import 'package:flutterbase/domain/repositories/language_preference_repository.dart';
import 'package:flutterbase/domain/repositories/media_library_repository.dart';
import 'package:flutterbase/domain/repositories/media_playback_repository.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_repository.dart';
import 'package:flutterbase/domain/repositories/photo_upload_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/repositories/sync_lease_repository.dart';
import 'package:flutterbase/domain/repositories/theme_preference_repository.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/app_theme_mode.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';
import 'package:flutterbase/domain/value_objects/media_id.dart';

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
final AuthSession testAuthSession = AuthSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  email: 'user@example.com',
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

/// In-memory [MediaLibraryRepository].
///
/// Answers from [media] by slicing it the way the server would, so a test
/// sets up one list and the paging falls out of it.
final class FakeMediaLibraryRepository implements MediaLibraryRepository {
  FakeMediaLibraryRepository({List<MediaItem>? media})
    : media = media ?? <MediaItem>[];

  List<MediaItem> media;

  /// Pages requested, in order, as (page, pageSize).
  final List<(int, int)> requestedPages = <(int, int)>[];

  /// When set, every request throws this instead of answering.
  AppError? failure;

  @override
  Future<MediaLibraryPage> findPage({int page = 1, int pageSize = 100}) async {
    requestedPages.add((page, pageSize));
    final error = failure;
    if (error != null) throw error;
    final start = (page - 1) * pageSize;
    if (start >= media.length) {
      return const MediaLibraryPage(items: <MediaItem>[], hasNext: false);
    }
    final end = start + pageSize;
    return MediaLibraryPage(
      items: media.sublist(start, end < media.length ? end : media.length),
      hasNext: end < media.length,
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

/// In-memory [MediaThumbnailRepository] returning a fixed byte pattern.
final class FakeMediaThumbnailRepository implements MediaThumbnailRepository {
  final List<(MediaId, int)> fetched = <(MediaId, int)>[];

  AppError? failure;

  @override
  Future<Uint8List> fetch(MediaId id, {required int size}) async {
    final error = failure;
    if (error != null) throw error;
    fetched.add((id, size));
    return testPngBytes;
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
  final Map<int, MediaPlaybackSource> sources = <int, MediaPlaybackSource>{};
  final List<MediaId> requested = <MediaId>[];

  /// When set, [sourceOf] throws this instead of answering.
  AppError? failure;

  @override
  Future<MediaPlaybackSource> sourceOf(MediaId id) async {
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

  @override
  Future<void> upload(LocalPhoto photo, Uint8List bytes) async {
    await _admit(photo);
    uploaded.add((photo, bytes));
  }

  @override
  Future<void> uploadFromPath(LocalPhoto photo, String path) async {
    await _admit(photo);
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

/// In-memory [AutoUploadSettingsRepository].
final class FakeAutoUploadSettingsRepository
    implements AutoUploadSettingsRepository {
  FakeAutoUploadSettingsRepository({
    this.enabled = false,
    this.since,
    this.unmeteredOnly = true,
  });

  bool enabled;
  DateTime? since;

  /// Mirrors the production default: restricted to unmetered connections
  /// until the user says otherwise.
  bool unmeteredOnly;
  final List<bool> savedStates = <bool>[];
  final List<bool> savedUnmeteredOnly = <bool>[];

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
  FakePhotoLibraryGateway({this.accessGranted = true, List<LocalPhoto>? photos})
    : photos = photos ?? <LocalPhoto>[];

  bool accessGranted;
  List<LocalPhoto> photos;

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

  @override
  Future<bool> ensureAccess() async {
    accessRequests++;
    return accessGranted;
  }

  @override
  Future<List<LocalPhoto>> photosTakenAfter(
    DateTime? since, {
    int limit = 100,
    int page = 0,
  }) async {
    queriedSince.add(since);
    return photos
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

  @override
  Stream<void> get libraryChanges => changes.stream;
}
