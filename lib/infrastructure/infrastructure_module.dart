import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/background_sync_scheduler.dart';
import 'package:flutterbase/application/ports/external_link_launcher.dart';
import 'package:flutterbase/application/ports/network_connection_gateway.dart';
import 'package:flutterbase/application/ports/photo_library_gateway.dart';
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
import 'package:flutterbase/infrastructure/api/photonest_api_client.dart';
import 'package:flutterbase/infrastructure/background/workmanager_background_sync_scheduler.dart';
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/device/connectivity_plus_network_connection_gateway.dart';
import 'package:flutterbase/infrastructure/device/photo_manager_photo_library_gateway.dart';
import 'package:flutterbase/infrastructure/links/url_launcher_external_link_launcher.dart';
import 'package:flutterbase/infrastructure/logging/persistent_app_logger.dart';
import 'package:flutterbase/infrastructure/repositories/api_album_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_auth_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_library_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_playback_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_media_thumbnail_repository.dart';
import 'package:flutterbase/infrastructure/repositories/api_photo_upload_repository.dart';
import 'package:flutterbase/infrastructure/repositories/package_info_app_info_repository.dart';
import 'package:flutterbase/infrastructure/repositories/secure_storage_session_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_api_endpoint_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_auto_upload_settings_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_debug_settings_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_language_preference_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_theme_preference_repository.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_album_snapshot_repository.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_backup_notification_repository.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_media_thumbnail_cache_repository.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_sync_lease_repository.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_upload_history_repository.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Everything Infrastructure offers the rest of the app, exposed only as
/// Domain interfaces and Application ports.
///
/// [create] owns the whole adapter set-up sequence — opening the key-value
/// store, restoring the saved log level, opening the first log file, opening
/// the SQLite database — so that the composition root never has to name a
/// storage technology. That is what keeps `SharedPreferences`, `Database`,
/// `dart:io`, and friends confined to this layer, which
/// `tool/check_architecture.dart` verifies.
final class InfrastructureModule {
  const InfrastructureModule._({
    required this.appLogger,
    required this.backupNotifications,
    required this.debugSettings,
    required this.themePreference,
    required this.languagePreference,
    required this.appInfo,
    required this.externalLinks,
    required this.auth,
    required this.sessions,
    required this.apiEndpoints,
    required this.albums,
    required this.albumSnapshots,
    required this.mediaThumbnails,
    required this.mediaThumbnailCache,
    required this.mediaLibrary,
    required this.mediaPlayback,
    required this.photoUploads,
    required this.uploadHistory,
    required this.syncLease,
    required this.autoUploadSettings,
    required this.photoLibrary,
    required this.networkConnection,
    required this.backgroundSync,
  });

  /// Opens every adapter and returns them wired and ready.
  ///
  /// Ordering matters: the debug-settings store has to be readable before the
  /// logger starts, so the very first log line is already filtered at the
  /// level the user chose. The database opens after the logger so that a
  /// migration failure is recorded rather than swallowed.
  /// [backgroundSyncDispatcher] is the composition root's background entry
  /// point, handed to WorkManager so the platform can run a sync pass in a
  /// headless engine while the app is closed.
  static Future<InfrastructureModule> create({
    required void Function() backgroundSyncDispatcher,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    final debugSettings = SharedPreferencesDebugSettingsRepository(preferences);

    final logger = PersistentAppLogger();
    await logger.init(savedLevel: debugSettings.getMinLogLevel());

    final database = await AppDatabase.open();
    logger.info(
      '[Infrastructure] SQLite ready — ${AppDatabase.fileName} '
      'v${AppDatabase.schemaVersion}',
    );

    // One HTTP client and one API client for every server-backed adapter,
    // so they share the token-refresh logic and its persistence. Tokens
    // live in the platform keystore; `preferences` is passed so tokens a
    // pre-keystore build left in plaintext are migrated and purged.
    final sessions = await SecureStorageSessionRepository.create(
      const FlutterSecureStorage(),
      preferences,
    );
    final apiEndpoints = SharedPreferencesApiEndpointRepository(preferences);
    final apiClient = PhotoNestApiClient(
      httpClient: http.Client(),
      sessionStore: sessions,
      endpointStore: apiEndpoints,
      appLogger: logger,
    );
    logger.info(
      '[Infrastructure] API client ready '
      '(endpoint: ${apiEndpoints.load() ?? 'not configured'}, '
      'session: ${sessions.load() == null ? 'none' : 'restored'})',
    );

    return InfrastructureModule._(
      appLogger: logger,
      debugSettings: debugSettings,
      themePreference: SharedPreferencesThemePreferenceRepository(preferences),
      languagePreference: SharedPreferencesLanguagePreferenceRepository(
        preferences,
      ),
      appInfo: const PackageInfoAppInfoRepository(),
      backupNotifications: SqfliteBackupNotificationRepository(database),
      externalLinks: const UrlLauncherExternalLinkLauncher(),
      auth: ApiAuthRepository(apiClient),
      sessions: sessions,
      apiEndpoints: apiEndpoints,
      albums: ApiAlbumRepository(apiClient),
      albumSnapshots: SqfliteAlbumSnapshotRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      mediaThumbnails: ApiMediaThumbnailRepository(apiClient),
      mediaThumbnailCache: SqfliteMediaThumbnailCacheRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      mediaLibrary: ApiMediaLibraryRepository(apiClient),
      mediaPlayback: ApiMediaPlaybackRepository(apiClient),
      photoUploads: ApiPhotoUploadRepository(apiClient),
      uploadHistory: SqfliteUploadHistoryRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      syncLease: SqfliteSyncLeaseRepository(database),
      autoUploadSettings: SharedPreferencesAutoUploadSettingsRepository(
        preferences,
      ),
      photoLibrary: PhotoManagerPhotoLibraryGateway(),
      networkConnection: const ConnectivityPlusNetworkConnectionGateway(),
      backgroundSync: WorkmanagerBackgroundSyncScheduler(
        backgroundSyncDispatcher,
      ),
    );
  }

  final AppLogger appLogger;
  final DebugSettingsRepository debugSettings;
  final ThemePreferenceRepository themePreference;
  final LanguagePreferenceRepository languagePreference;
  final AppInfoRepository appInfo;
  final BackupNotificationRepository backupNotifications;
  final ExternalLinkLauncher externalLinks;
  final AuthRepository auth;
  final SessionRepository sessions;
  final ApiEndpointRepository apiEndpoints;
  final AlbumRepository albums;
  final AlbumSnapshotRepository albumSnapshots;
  final MediaThumbnailRepository mediaThumbnails;
  final MediaThumbnailCacheRepository mediaThumbnailCache;
  final MediaLibraryRepository mediaLibrary;
  final MediaPlaybackRepository mediaPlayback;
  final PhotoUploadRepository photoUploads;
  final UploadHistoryRepository uploadHistory;
  final SyncLeaseRepository syncLease;
  final AutoUploadSettingsRepository autoUploadSettings;
  final PhotoLibraryGateway photoLibrary;
  final NetworkConnectionGateway networkConnection;
  final BackgroundSyncScheduler backgroundSync;
}
