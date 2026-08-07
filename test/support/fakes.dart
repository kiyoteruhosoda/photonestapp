import 'package:flutterbase/application/ports/external_link_launcher.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/repositories/app_info_repository.dart';
import 'package:flutterbase/domain/repositories/bookmark_repository.dart';
import 'package:flutterbase/domain/repositories/debug_settings_repository.dart';
import 'package:flutterbase/domain/repositories/language_preference_repository.dart';
import 'package:flutterbase/domain/repositories/theme_preference_repository.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/app_theme_mode.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

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
