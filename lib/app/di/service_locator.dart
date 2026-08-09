import 'package:get_it/get_it.dart';
import 'package:photonest/app/background/background_sync_entrypoint.dart';
import 'package:photonest/application/ports/app_logger.dart';
import 'package:photonest/application/ports/background_sync_scheduler.dart';
import 'package:photonest/application/ports/external_link_launcher.dart';
import 'package:photonest/application/ports/network_connection_gateway.dart';
import 'package:photonest/application/ports/photo_library_gateway.dart';
import 'package:photonest/application/services/auto_upload_coordinator.dart';
import 'package:photonest/application/usecases/album/get_album_usecase.dart';
import 'package:photonest/application/usecases/album/list_albums_usecase.dart';
import 'package:photonest/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:photonest/application/usecases/auth/get_api_endpoint_usecase.dart';
import 'package:photonest/application/usecases/auth/login_usecase.dart';
import 'package:photonest/application/usecases/auth/logout_usecase.dart';
import 'package:photonest/application/usecases/auth/restore_session_usecase.dart';
import 'package:photonest/application/usecases/auth/watch_session_usecase.dart';
import 'package:photonest/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:photonest/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:photonest/application/usecases/debug/set_log_level_usecase.dart';
import 'package:photonest/application/usecases/language/get_language_preference_usecase.dart';
import 'package:photonest/application/usecases/language/set_language_preference_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_original_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_playback_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/media/list_library_media_usecase.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/application/usecases/notification/get_unread_notification_count_usecase.dart';
import 'package:photonest/application/usecases/notification/list_backup_notifications_usecase.dart';
import 'package:photonest/application/usecases/notification/mark_notifications_read_usecase.dart';
import 'package:photonest/application/usecases/notification/record_backup_result_usecase.dart';
import 'package:photonest/application/usecases/notification/watch_backup_notifications_usecase.dart';
import 'package:photonest/application/usecases/theme/get_theme_preference_usecase.dart';
import 'package:photonest/application/usecases/theme/set_theme_preference_usecase.dart';
import 'package:photonest/application/usecases/upload/dismiss_upload_failures_usecase.dart';
import 'package:photonest/application/usecases/upload/get_auto_upload_enabled_usecase.dart';
import 'package:photonest/application/usecases/upload/get_auto_upload_unmetered_only_usecase.dart';
import 'package:photonest/application/usecases/upload/get_local_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/upload/list_upload_candidates_usecase.dart';
import 'package:photonest/application/usecases/upload/list_upload_failures_usecase.dart';
import 'package:photonest/application/usecases/upload/set_auto_upload_enabled_usecase.dart';
import 'package:photonest/application/usecases/upload/set_auto_upload_unmetered_only_usecase.dart';
import 'package:photonest/application/usecases/upload/sync_new_photos_usecase.dart';
import 'package:photonest/application/usecases/upload/upload_photos_usecase.dart';
import 'package:photonest/application/usecases/upload/watch_upload_failures_usecase.dart';
import 'package:photonest/domain/repositories/album_repository.dart';
import 'package:photonest/domain/repositories/album_snapshot_repository.dart';
import 'package:photonest/domain/repositories/api_endpoint_repository.dart';
import 'package:photonest/domain/repositories/app_info_repository.dart';
import 'package:photonest/domain/repositories/auth_repository.dart';
import 'package:photonest/domain/repositories/auto_upload_settings_repository.dart';
import 'package:photonest/domain/repositories/backup_notification_repository.dart';
import 'package:photonest/domain/repositories/debug_settings_repository.dart';
import 'package:photonest/domain/repositories/language_preference_repository.dart';
import 'package:photonest/domain/repositories/media_library_repository.dart';
import 'package:photonest/domain/repositories/media_original_repository.dart';
import 'package:photonest/domain/repositories/media_playback_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_cache_repository.dart';
import 'package:photonest/domain/repositories/media_thumbnail_repository.dart';
import 'package:photonest/domain/repositories/photo_upload_repository.dart';
import 'package:photonest/domain/repositories/session_repository.dart';
import 'package:photonest/domain/repositories/sync_lease_repository.dart';
import 'package:photonest/domain/repositories/theme_preference_repository.dart';
import 'package:photonest/domain/repositories/upload_failure_repository.dart';
import 'package:photonest/domain/repositories/upload_history_repository.dart';
import 'package:photonest/infrastructure/infrastructure_module.dart';

/// Composition root.
///
/// This is the only place allowed to see every layer at once: it binds Domain
/// interfaces to Infrastructure adapters and hands the wired objects down to
/// Presentation through `AppScope`. Nothing outside `lib/app/` may import
/// this file — `tool/check_architecture.dart` enforces that.
final GetIt sl = GetIt.instance;

/// Wires up all dependencies. Call once at app startup before `runApp`.
Future<void> setupServiceLocator() async {
  // ─── Infrastructure adapters ─────────────────────────────────────────
  // The module hands back Domain interfaces and Application ports only, so
  // no storage technology is named here.

  final infrastructure = await InfrastructureModule.create(
    backgroundSyncDispatcher: backgroundSyncDispatcher,
  );

  sl
    ..registerSingleton<AppLogger>(infrastructure.appLogger)
    ..registerSingleton<DebugSettingsRepository>(infrastructure.debugSettings)
    ..registerSingleton<ThemePreferenceRepository>(
      infrastructure.themePreference,
    )
    ..registerSingleton<LanguagePreferenceRepository>(
      infrastructure.languagePreference,
    )
    ..registerSingleton<AppInfoRepository>(infrastructure.appInfo)
    ..registerSingleton<BackupNotificationRepository>(
      infrastructure.backupNotifications,
    )
    ..registerSingleton<ExternalLinkLauncher>(infrastructure.externalLinks)
    ..registerSingleton<AuthRepository>(infrastructure.auth)
    ..registerSingleton<SessionRepository>(infrastructure.sessions)
    ..registerSingleton<ApiEndpointRepository>(infrastructure.apiEndpoints)
    ..registerSingleton<AlbumRepository>(infrastructure.albums)
    ..registerSingleton<AlbumSnapshotRepository>(infrastructure.albumSnapshots)
    ..registerSingleton<MediaThumbnailRepository>(
      infrastructure.mediaThumbnails,
    )
    ..registerSingleton<MediaThumbnailCacheRepository>(
      infrastructure.mediaThumbnailCache,
    )
    ..registerSingleton<MediaLibraryRepository>(infrastructure.mediaLibrary)
    ..registerSingleton<MediaOriginalRepository>(infrastructure.mediaOriginals)
    ..registerSingleton<MediaPlaybackRepository>(infrastructure.mediaPlayback)
    ..registerSingleton<PhotoUploadRepository>(infrastructure.photoUploads)
    ..registerSingleton<UploadHistoryRepository>(infrastructure.uploadHistory)
    ..registerSingleton<UploadFailureRepository>(infrastructure.uploadFailures)
    ..registerSingleton<SyncLeaseRepository>(infrastructure.syncLease)
    ..registerSingleton<AutoUploadSettingsRepository>(
      infrastructure.autoUploadSettings,
    )
    ..registerSingleton<PhotoLibraryGateway>(infrastructure.photoLibrary)
    ..registerSingleton<NetworkConnectionGateway>(
      infrastructure.networkConnection,
    )
    ..registerSingleton<BackgroundSyncScheduler>(infrastructure.backgroundSync);

  sl<AppLogger>().info(
    '[DI] Infrastructure ready '
    '(minLogLevel: ${infrastructure.appLogger.minLevel.name})',
  );

  // ─── Use cases ───────────────────────────────────────────────────────

  sl.registerFactory<GetThemePreferenceUseCase>(
    () => GetThemePreferenceUseCase(sl<ThemePreferenceRepository>()),
  );
  sl.registerFactory<SetThemePreferenceUseCase>(
    () => SetThemePreferenceUseCase(sl<ThemePreferenceRepository>()),
  );
  sl.registerFactory<GetLanguagePreferenceUseCase>(
    () => GetLanguagePreferenceUseCase(sl<LanguagePreferenceRepository>()),
  );
  sl.registerFactory<SetLanguagePreferenceUseCase>(
    () => SetLanguagePreferenceUseCase(sl<LanguagePreferenceRepository>()),
  );
  sl.registerFactory<GetAppInfoUseCase>(
    () => GetAppInfoUseCase(sl<AppInfoRepository>()),
  );
  sl.registerFactory<GetDebugSettingsUseCase>(
    () => GetDebugSettingsUseCase(sl<DebugSettingsRepository>()),
  );
  sl.registerFactory<SetDebugModeUseCase>(
    () => SetDebugModeUseCase(sl<DebugSettingsRepository>()),
  );
  sl.registerFactory<SetLogLevelUseCase>(
    () => SetLogLevelUseCase(sl<DebugSettingsRepository>(), sl<AppLogger>()),
  );
  sl.registerFactory<LoginUseCase>(
    () => LoginUseCase(
      sl<AuthRepository>(),
      sl<SessionRepository>(),
      sl<ApiEndpointRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<LogoutUseCase>(
    () => LogoutUseCase(
      sl<AuthRepository>(),
      sl<SessionRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<RestoreSessionUseCase>(
    () => RestoreSessionUseCase(sl<SessionRepository>()),
  );
  sl.registerFactory<WatchSessionUseCase>(
    () => WatchSessionUseCase(sl<SessionRepository>()),
  );
  sl.registerFactory<GetApiEndpointUseCase>(
    () => GetApiEndpointUseCase(sl<ApiEndpointRepository>()),
  );
  sl.registerFactory<ListAlbumsUseCase>(
    () => ListAlbumsUseCase(
      sl<AlbumRepository>(),
      sl<AlbumSnapshotRepository>(),
      sl<SessionRepository>(),
      sl<ApiEndpointRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<GetAlbumUseCase>(
    () => GetAlbumUseCase(
      sl<AlbumRepository>(),
      sl<AlbumSnapshotRepository>(),
      sl<SessionRepository>(),
      sl<ApiEndpointRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<GetMediaThumbnailUseCase>(
    () => GetMediaThumbnailUseCase(
      sl<MediaThumbnailRepository>(),
      sl<MediaThumbnailCacheRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<GetMediaPlaybackUseCase>(
    () => GetMediaPlaybackUseCase(sl<MediaPlaybackRepository>()),
  );
  sl.registerFactory<GetMediaOriginalUseCase>(
    () => GetMediaOriginalUseCase(sl<MediaOriginalRepository>()),
  );
  sl.registerFactory<SaveMediaOriginalUseCase>(
    () => SaveMediaOriginalUseCase(
      sl<MediaOriginalRepository>(),
      sl<PhotoLibraryGateway>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<ListLibraryMediaUseCase>(
    () =>
        ListLibraryMediaUseCase(sl<MediaLibraryRepository>(), sl<AppLogger>()),
  );
  sl.registerFactory<ListUploadCandidatesUseCase>(
    () => ListUploadCandidatesUseCase(
      sl<PhotoLibraryGateway>(),
      sl<UploadHistoryRepository>(),
    ),
  );
  sl.registerFactory<GetLocalThumbnailUseCase>(
    () => GetLocalThumbnailUseCase(sl<PhotoLibraryGateway>()),
  );
  sl.registerFactory<UploadPhotosUseCase>(
    () => UploadPhotosUseCase(
      sl<PhotoLibraryGateway>(),
      sl<PhotoUploadRepository>(),
      sl<UploadHistoryRepository>(),
      sl<UploadFailureRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<ListUploadFailuresUseCase>(
    () => ListUploadFailuresUseCase(sl<UploadFailureRepository>()),
  );
  sl.registerFactory<WatchUploadFailuresUseCase>(
    () => WatchUploadFailuresUseCase(sl<UploadFailureRepository>()),
  );
  sl.registerFactory<DismissUploadFailuresUseCase>(
    () => DismissUploadFailuresUseCase(sl<UploadFailureRepository>()),
  );
  sl.registerFactory<SyncNewPhotosUseCase>(
    () => SyncNewPhotosUseCase(
      sl<AutoUploadSettingsRepository>(),
      sl<SessionRepository>(),
      sl<NetworkConnectionGateway>(),
      sl<PhotoLibraryGateway>(),
      sl<UploadHistoryRepository>(),
      sl<SyncLeaseRepository>(),
      sl<UploadPhotosUseCase>(),
      sl<RecordBackupResultUseCase>(),
      sl<AppLogger>(),
      leaseHolder: 'foreground',
    ),
  );
  sl.registerFactory<RecordBackupResultUseCase>(
    () => RecordBackupResultUseCase(
      sl<BackupNotificationRepository>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<ListBackupNotificationsUseCase>(
    () => ListBackupNotificationsUseCase(sl<BackupNotificationRepository>()),
  );
  sl.registerFactory<GetUnreadNotificationCountUseCase>(
    () => GetUnreadNotificationCountUseCase(sl<BackupNotificationRepository>()),
  );
  sl.registerFactory<MarkNotificationsReadUseCase>(
    () => MarkNotificationsReadUseCase(sl<BackupNotificationRepository>()),
  );
  sl.registerFactory<WatchBackupNotificationsUseCase>(
    () => WatchBackupNotificationsUseCase(sl<BackupNotificationRepository>()),
  );
  sl.registerFactory<GetAutoUploadEnabledUseCase>(
    () => GetAutoUploadEnabledUseCase(sl<AutoUploadSettingsRepository>()),
  );
  sl.registerFactory<SetAutoUploadEnabledUseCase>(
    () => SetAutoUploadEnabledUseCase(
      sl<AutoUploadSettingsRepository>(),
      sl<PhotoLibraryGateway>(),
      sl<BackgroundSyncScheduler>(),
      sl<AppLogger>(),
    ),
  );
  sl.registerFactory<GetAutoUploadUnmeteredOnlyUseCase>(
    () => GetAutoUploadUnmeteredOnlyUseCase(sl<AutoUploadSettingsRepository>()),
  );
  sl.registerFactory<SetAutoUploadUnmeteredOnlyUseCase>(
    () => SetAutoUploadUnmeteredOnlyUseCase(
      sl<AutoUploadSettingsRepository>(),
      sl<BackgroundSyncScheduler>(),
      sl<AppLogger>(),
    ),
  );

  // ─── Long-lived services ─────────────────────────────────────────────

  // One coordinator for the whole app run; AppWidget starts it after the
  // first frame and it keeps watching the photo library until shutdown.
  sl.registerSingleton<AutoUploadCoordinator>(
    AutoUploadCoordinator(
      sl<PhotoLibraryGateway>(),
      sl<SyncNewPhotosUseCase>(),
      sl<AutoUploadSettingsRepository>(),
      sl<BackgroundSyncScheduler>(),
      sl<AppLogger>(),
    ),
  );

  // Screen state lives in Riverpod. The bridge from these use cases to the
  // providers the screens read is `lib/app/di/provider_overrides.dart`.

  sl<AppLogger>().info('[DI] Service locator setup complete');
}
