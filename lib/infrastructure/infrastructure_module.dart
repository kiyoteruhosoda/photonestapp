import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/background_sync_scheduler.dart';
import 'package:photonest/application/ports/external_link_launcher.dart';
import 'package:photonest/application/ports/network_connection_gateway.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/domain/repositories/account_repository.dart';
import 'package:photonest/domain/repositories/album_editing_repository.dart';
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
import 'package:photonest/infrastructure/api/photonest_api_client.dart';
import 'package:photonest/infrastructure/background/workmanager_background_sync_scheduler.dart';
import 'package:photonest/infrastructure/database/app_database.dart';
import 'package:photonest/infrastructure/device/connectivity_plus_network_connection_gateway.dart';
import 'package:photonest/infrastructure/device/photo_manager_photo_library_gateway.dart';
import 'package:photonest/infrastructure/links/url_launcher_external_link_launcher.dart';
import 'package:photonest/infrastructure/logging/persistent_app_logger.dart';
import 'package:photonest/infrastructure/repositories/api_account_repository.dart';
import 'package:photonest/infrastructure/repositories/api_album_editing_repository.dart';
import 'package:photonest/infrastructure/repositories/api_album_repository.dart';
import 'package:photonest/infrastructure/repositories/api_auth_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_curation_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_library_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_original_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_playback_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_tag_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_thumbnail_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_thumbnail_url_repository.dart';
import 'package:photonest/infrastructure/repositories/api_photo_upload_repository.dart';
import 'package:photonest/infrastructure/repositories/package_info_app_info_repository.dart';
import 'package:photonest/infrastructure/repositories/secure_storage_session_repository.dart';
import 'package:photonest/infrastructure/repositories/shared_preferences_api_endpoint_repository.dart';
import 'package:photonest/infrastructure/repositories/shared_preferences_auto_upload_settings_repository.dart';
import 'package:photonest/infrastructure/repositories/shared_preferences_debug_settings_repository.dart';
import 'package:photonest/infrastructure/repositories/shared_preferences_language_preference_repository.dart';
import 'package:photonest/infrastructure/repositories/shared_preferences_theme_preference_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_album_snapshot_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_backup_notification_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_media_thumbnail_cache_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_sync_lease_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_upload_failure_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_upload_history_repository.dart';
import 'package:photonest/infrastructure/repositories/sqflite_upload_resumption_repository.dart';
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
    required this.account,
    required this.albums,
    required this.albumEditing,
    required this.albumSnapshots,
    required this.mediaThumbnails,
    required this.mediaThumbnailUrls,
    required this.mediaThumbnailCache,
    required this.mediaLibrary,
    required this.mediaCuration,
    required this.mediaTags,
    required this.mediaOriginals,
    required this.mediaPlayback,
    required this.photoUploads,
    required this.uploadHistory,
    required this.uploadFailures,
    required this.uploadResumptions,
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

    // Shared instance: the upload repository consults it, and the module
    // exposes the same one so a caller can clear a stale resume point.
    final uploadResumptions = SqfliteUploadResumptionRepository(
      database,
      sessions,
      apiEndpoints,
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
      account: ApiAccountRepository(apiClient),
      albums: ApiAlbumRepository(apiClient),
      albumEditing: ApiAlbumEditingRepository(apiClient),
      albumSnapshots: SqfliteAlbumSnapshotRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      mediaThumbnails: ApiMediaThumbnailRepository(apiClient),
      mediaThumbnailUrls: ApiMediaThumbnailUrlRepository(apiClient),
      mediaThumbnailCache: SqfliteMediaThumbnailCacheRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      mediaLibrary: ApiMediaLibraryRepository(apiClient),
      mediaCuration: ApiMediaCurationRepository(apiClient),
      mediaTags: ApiMediaTagRepository(apiClient),
      mediaOriginals: ApiMediaOriginalRepository(apiClient),
      mediaPlayback: ApiMediaPlaybackRepository(apiClient),
      photoUploads: ApiPhotoUploadRepository(
        apiClient,
        uploadResumptions,
        logger,
      ),
      uploadHistory: SqfliteUploadHistoryRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      uploadFailures: SqfliteUploadFailureRepository(
        database,
        sessions,
        apiEndpoints,
      ),
      uploadResumptions: uploadResumptions,
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
  final AccountRepository account;
  final AlbumRepository albums;
  final AlbumEditingRepository albumEditing;
  final AlbumSnapshotRepository albumSnapshots;
  final MediaThumbnailRepository mediaThumbnails;
  final MediaThumbnailUrlRepository mediaThumbnailUrls;
  final MediaThumbnailCacheRepository mediaThumbnailCache;
  final MediaLibraryRepository mediaLibrary;
  final MediaCurationRepository mediaCuration;
  final MediaTagRepository mediaTags;
  final MediaOriginalRepository mediaOriginals;
  final MediaPlaybackRepository mediaPlayback;
  final PhotoUploadRepository photoUploads;
  final UploadHistoryRepository uploadHistory;
  final UploadFailureRepository uploadFailures;
  final UploadResumptionRepository uploadResumptions;
  final SyncLeaseRepository syncLease;
  final AutoUploadSettingsRepository autoUploadSettings;
  final PhotoLibraryGateway photoLibrary;
  final NetworkConnectionGateway networkConnection;
  final BackgroundSyncScheduler backgroundSync;
}
