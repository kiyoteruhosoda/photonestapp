import 'dart:async';
import 'dart:typed_data';

import 'package:flutterbase/application/ports/background_sync_scheduler.dart';
import 'package:flutterbase/application/ports/external_link_launcher.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
import 'package:flutterbase/domain/entities/album.dart';
import 'package:flutterbase/domain/entities/album_media_item.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/entities/auth_session.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/entities/local_photo.dart';
import 'package:flutterbase/domain/entities/media_playback_source.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/album_repository.dart';
import 'package:flutterbase/domain/repositories/api_endpoint_repository.dart';
import 'package:flutterbase/domain/repositories/app_info_repository.dart';
import 'package:flutterbase/domain/repositories/auth_repository.dart';
import 'package:flutterbase/domain/repositories/auto_upload_settings_repository.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';
import 'package:flutterbase/domain/repositories/debug_settings_repository.dart';
import 'package:flutterbase/domain/repositories/language_preference_repository.dart';
import 'package:flutterbase/domain/repositories/media_playback_repository.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:flutterbase/domain/repositories/media_thumbnail_repository.dart';
import 'package:flutterbase/domain/repositories/photo_upload_repository.dart';
import 'package:flutterbase/domain/repositories/session_repository.dart';
import 'package:flutterbase/domain/repositories/theme_preference_repository.dart';
import 'package:flutterbase/domain/repositories/upload_history_repository.dart';
import 'package:flutterbase/domain/value_objects/album_id.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/app_theme_mode.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
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

/// A fixed instant, so a test never has to reason about the wall clock.
final DateTime testBookmarkCreatedAt = DateTime.utc(2026, 8, 3, 12, 30);

/// Builds a stored bookmark without going through a repository.
Bookmark testBookmark({
  int id = 1,
  String title = 'Flutter',
  String url = 'https://docs.flutter.dev',
  DateTime? createdAt,
}) {
  return Bookmark(
    id: BookmarkId(id),
    title: title,
    url: Uri.parse(url),
    createdAt: createdAt ?? testBookmarkCreatedAt,
  );
}

/// In-memory [BookmarkRepository].
///
/// Assigns ids the way SQLite does — monotonically, never reusing one — so a
/// test that deletes and re-adds sees the same id behaviour as production.
final class FakeBookmarkRepository implements BookmarkRepository {
  FakeBookmarkRepository([List<Bookmark>? initial]) {
    for (final bookmark in initial ?? const <Bookmark>[]) {
      _stored[bookmark.id] = bookmark;
      if (bookmark.id.value >= _nextId) _nextId = bookmark.id.value + 1;
    }
  }

  final Map<BookmarkId, Bookmark> _stored = <BookmarkId, Bookmark>{};
  int _nextId = 1;

  /// Ids passed to [remove], in call order.
  final List<BookmarkId> removed = <BookmarkId>[];

  /// Drafts passed to [add], in call order.
  final List<BookmarkDraft> added = <BookmarkDraft>[];

  /// When set, every method throws this instead of answering.
  AppError? failure;

  /// Creation timestamp handed to the next [add].
  DateTime createdAt = testBookmarkCreatedAt;

  List<Bookmark> get stored => _stored.values.toList();

  @override
  Future<List<Bookmark>> findAll() async {
    _failIfAsked();
    final all = _stored.values.toList()
      ..sort((a, b) => b.id.value.compareTo(a.id.value));
    return all;
  }

  @override
  Future<Bookmark?> findById(BookmarkId id) async {
    _failIfAsked();
    return _stored[id];
  }

  @override
  Future<Bookmark> add(BookmarkDraft draft) async {
    _failIfAsked();
    added.add(draft);
    final bookmark = Bookmark.fromDraft(
      id: BookmarkId(_nextId++),
      draft: draft,
      createdAt: createdAt,
    );
    _stored[bookmark.id] = bookmark;
    return bookmark;
  }

  @override
  Future<void> remove(BookmarkId id) async {
    _failIfAsked();
    removed.add(id);
    _stored.remove(id);
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

/// Builds one album media item.
AlbumMediaItem testAlbumMediaItem({
  int id = 10,
  String filename = 'a.jpg',
  bool isVideo = false,
}) {
  return AlbumMediaItem(
    id: MediaId(id),
    filename: filename,
    shotAt: testPhotoTakenAt,
    isVideo: isVideo,
  );
}

/// In-memory [AuthRepository].
final class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({AuthSession? session}) : sessionToReturn = session;

  /// Session handed back by [login] / [refresh]; defaults to a session built
  /// from the submitted credentials.
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
  Future<AuthSession> refresh(AuthSession session) async {
    _failIfAsked();
    return sessionToReturn ?? session;
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

  /// When set, every method throws this instead of answering.
  AppError? failure;

  @override
  Future<List<Album>> findAll() async {
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
      mediaTotal: detail.media.length,
    );
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

/// Records scheduling calls instead of talking to WorkManager.
final class FakeBackgroundSyncScheduler implements BackgroundSyncScheduler {
  int scheduleRequests = 0;
  int cancelRequests = 0;

  @override
  Future<void> ensureScheduled() async {
    scheduleRequests++;
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

  @override
  Future<void> upload(LocalPhoto photo, Uint8List bytes) async {
    await gate?.call(photo);
    final error = failure;
    if (error != null && (failFor.isEmpty || failFor.contains(photo.localId))) {
      throw error;
    }
    uploaded.add((photo, bytes));
  }
}

/// In-memory [UploadHistoryRepository].
final class FakeUploadHistoryRepository implements UploadHistoryRepository {
  FakeUploadHistoryRepository([Set<String>? uploaded])
    : _uploaded = uploaded ?? <String>{};

  final Set<String> _uploaded;
  final List<LocalPhoto> marked = <LocalPhoto>[];

  @override
  Future<Set<String>> uploadedLocalIds() async => Set.of(_uploaded);

  @override
  Future<void> markUploaded(LocalPhoto photo, DateTime uploadedAt) async {
    marked.add(photo);
    _uploaded.add(photo.localId);
  }
}

/// In-memory [AutoUploadSettingsRepository].
final class FakeAutoUploadSettingsRepository
    implements AutoUploadSettingsRepository {
  FakeAutoUploadSettingsRepository({this.enabled = false, this.since});

  bool enabled;
  DateTime? since;
  final List<bool> savedStates = <bool>[];

  @override
  bool isEnabled() => enabled;

  @override
  DateTime? enabledSince() => since;

  @override
  Future<void> setEnabled(bool value) async {
    savedStates.add(value);
    enabled = value;
    if (value) since ??= testPhotoTakenAt;
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
  Future<Uint8List?> readThumbnail(String localId, {required int size}) async =>
      thumbnailsById[localId];

  @override
  Stream<void> get libraryChanges => changes.stream;
}

/// Records the URLs handed to the platform instead of launching them.
final class RecordingExternalLinkLauncher implements ExternalLinkLauncher {
  RecordingExternalLinkLauncher({this.result = true});

  /// What [open] reports back — false models "no app can handle this".
  bool result;

  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return result;
  }
}
