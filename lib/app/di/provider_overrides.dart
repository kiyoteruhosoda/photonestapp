// `Override` — the type `ProviderScope.overrides` takes — lives in Riverpod's
// `misc.dart` rather than its main entry point.
import 'package:flutter_riverpod/misc.dart';
import 'package:photonest/app/di/service_locator.dart';
import 'package:photonest/application/ports/app_logger.dart';
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
import 'package:photonest/application/usecases/media/curate_media_usecase.dart';
import 'package:photonest/application/usecases/media/edit_media_tags_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_original_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_playback_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/media/list_library_media_usecase.dart';
import 'package:photonest/application/usecases/media/list_trashed_media_usecase.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/application/usecases/notification/get_unread_notification_count_usecase.dart';
import 'package:photonest/application/usecases/notification/list_backup_notifications_usecase.dart';
import 'package:photonest/application/usecases/notification/mark_notifications_read_usecase.dart';
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
import 'package:photonest/application/usecases/upload/upload_photos_usecase.dart';
import 'package:photonest/application/usecases/upload/watch_upload_failures_usecase.dart';
import 'package:photonest/presentation/providers/album_providers.dart';
import 'package:photonest/presentation/providers/app_info_providers.dart';
import 'package:photonest/presentation/providers/app_providers.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/providers/notification_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';
import 'package:photonest/presentation/providers/settings_providers.dart';
import 'package:photonest/presentation/providers/upload_providers.dart';

/// Bridges the service locator to Riverpod.
///
/// The providers in `presentation/providers/` declare *what* a screen needs
/// and throw if read un-overridden; this list is the only place that says
/// *which* instance satisfies each one. Keeping the bridge in the composition
/// root is what lets Presentation stay unaware of `get_it`, and what makes a
/// widget test able to swap any single use case for a fake by overriding the
/// same provider.
List<Override> buildProviderOverrides() {
  return <Override>[
    appLoggerProvider.overrideWithValue(sl<AppLogger>()),
    listAlbumsUseCaseProvider.overrideWithValue(sl<ListAlbumsUseCase>()),
    getAlbumUseCaseProvider.overrideWithValue(sl<GetAlbumUseCase>()),
    getMediaThumbnailUseCaseProvider.overrideWithValue(
      sl<GetMediaThumbnailUseCase>(),
    ),
    getMediaPlaybackUseCaseProvider.overrideWithValue(
      sl<GetMediaPlaybackUseCase>(),
    ),
    listLibraryMediaUseCaseProvider.overrideWithValue(
      sl<ListLibraryMediaUseCase>(),
    ),
    curateMediaUseCaseProvider.overrideWithValue(sl<CurateMediaUseCase>()),
    editMediaTagsUseCaseProvider.overrideWithValue(sl<EditMediaTagsUseCase>()),
    listTrashedMediaUseCaseProvider.overrideWithValue(
      sl<ListTrashedMediaUseCase>(),
    ),
    getMediaOriginalUseCaseProvider.overrideWithValue(
      sl<GetMediaOriginalUseCase>(),
    ),
    saveMediaOriginalUseCaseProvider.overrideWithValue(
      sl<SaveMediaOriginalUseCase>(),
    ),
    listBackupNotificationsUseCaseProvider.overrideWithValue(
      sl<ListBackupNotificationsUseCase>(),
    ),
    getUnreadNotificationCountUseCaseProvider.overrideWithValue(
      sl<GetUnreadNotificationCountUseCase>(),
    ),
    markNotificationsReadUseCaseProvider.overrideWithValue(
      sl<MarkNotificationsReadUseCase>(),
    ),
    watchBackupNotificationsUseCaseProvider.overrideWithValue(
      sl<WatchBackupNotificationsUseCase>(),
    ),
    listUploadCandidatesUseCaseProvider.overrideWithValue(
      sl<ListUploadCandidatesUseCase>(),
    ),
    uploadPhotosUseCaseProvider.overrideWithValue(sl<UploadPhotosUseCase>()),
    listUploadFailuresUseCaseProvider.overrideWithValue(
      sl<ListUploadFailuresUseCase>(),
    ),
    watchUploadFailuresUseCaseProvider.overrideWithValue(
      sl<WatchUploadFailuresUseCase>(),
    ),
    dismissUploadFailuresUseCaseProvider.overrideWithValue(
      sl<DismissUploadFailuresUseCase>(),
    ),
    getLocalThumbnailUseCaseProvider.overrideWithValue(
      sl<GetLocalThumbnailUseCase>(),
    ),
    getAutoUploadEnabledUseCaseProvider.overrideWithValue(
      sl<GetAutoUploadEnabledUseCase>(),
    ),
    setAutoUploadEnabledUseCaseProvider.overrideWithValue(
      sl<SetAutoUploadEnabledUseCase>(),
    ),
    getAutoUploadUnmeteredOnlyUseCaseProvider.overrideWithValue(
      sl<GetAutoUploadUnmeteredOnlyUseCase>(),
    ),
    setAutoUploadUnmeteredOnlyUseCaseProvider.overrideWithValue(
      sl<SetAutoUploadUnmeteredOnlyUseCase>(),
    ),
    autoUploadCoordinatorProvider.overrideWithValue(
      sl<AutoUploadCoordinator>(),
    ),
    getThemePreferenceUseCaseProvider.overrideWithValue(
      sl<GetThemePreferenceUseCase>(),
    ),
    setThemePreferenceUseCaseProvider.overrideWithValue(
      sl<SetThemePreferenceUseCase>(),
    ),
    getLanguagePreferenceUseCaseProvider.overrideWithValue(
      sl<GetLanguagePreferenceUseCase>(),
    ),
    setLanguagePreferenceUseCaseProvider.overrideWithValue(
      sl<SetLanguagePreferenceUseCase>(),
    ),
    getDebugSettingsUseCaseProvider.overrideWithValue(
      sl<GetDebugSettingsUseCase>(),
    ),
    setDebugModeUseCaseProvider.overrideWithValue(sl<SetDebugModeUseCase>()),
    setLogLevelUseCaseProvider.overrideWithValue(sl<SetLogLevelUseCase>()),
    getAppInfoUseCaseProvider.overrideWithValue(sl<GetAppInfoUseCase>()),
    loginUseCaseProvider.overrideWithValue(sl<LoginUseCase>()),
    logoutUseCaseProvider.overrideWithValue(sl<LogoutUseCase>()),
    restoreSessionUseCaseProvider.overrideWithValue(
      sl<RestoreSessionUseCase>(),
    ),
    getApiEndpointUseCaseProvider.overrideWithValue(
      sl<GetApiEndpointUseCase>(),
    ),
    watchSessionUseCaseProvider.overrideWithValue(sl<WatchSessionUseCase>()),
  ];
}
