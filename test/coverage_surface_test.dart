// Coverage surface.
//
// `flutter test --coverage` only instruments libraries that the test run
// actually loads, so a file nobody imports is absent from `lcov.info`
// entirely — not reported as 0%. That silently inflates the project total
// and lets whole screens ship untested while CI stays green.
//
// Importing every library here puts all of `lib/` into the report, so the
// "Total" floor in `tool/check_coverage.dart` means what it says. The test
// below keeps this list honest: add a file under `lib/` without importing it
// here and the test fails with the exact line to add.

// ignore_for_file: unused_import

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/app/background/background_sync_entrypoint.dart';
import 'package:photonest/app/bootstrap/app_router.dart';
import 'package:photonest/app/bootstrap/app_widget.dart';
import 'package:photonest/app/di/provider_overrides.dart';
import 'package:photonest/app/di/service_locator.dart';
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
import 'package:photonest/application/usecases/media/curate_media_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_original_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_playback_usecase.dart';
import 'package:photonest/application/usecases/media/get_media_thumbnail_usecase.dart';
import 'package:photonest/application/usecases/media/list_library_media_usecase.dart';
import 'package:photonest/application/usecases/media/list_trashed_media_usecase.dart';
import 'package:photonest/application/usecases/media/save_media_original_usecase.dart';
import 'package:photonest/application/usecases/media/thumbnail_url_batch.dart';
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
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/entities/app_info.dart';
import 'package:photonest/domain/entities/auth_session.dart';
import 'package:photonest/domain/entities/backup_notification.dart';
import 'package:photonest/domain/entities/local_photo.dart';
import 'package:photonest/domain/entities/log_entry.dart';
import 'package:photonest/domain/entities/media_item.dart';
import 'package:photonest/domain/entities/media_library_page.dart';
import 'package:photonest/domain/entities/signed_media_url.dart';
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
import 'package:photonest/infrastructure/api/photonest_api_client.dart';
import 'package:photonest/infrastructure/background/workmanager_background_sync_scheduler.dart';
import 'package:photonest/infrastructure/database/app_database.dart';
import 'package:photonest/infrastructure/device/connectivity_plus_network_connection_gateway.dart';
import 'package:photonest/infrastructure/device/photo_manager_photo_library_gateway.dart';
import 'package:photonest/infrastructure/infrastructure_module.dart';
import 'package:photonest/infrastructure/links/url_launcher_external_link_launcher.dart';
import 'package:photonest/infrastructure/logging/persistent_app_logger.dart';
import 'package:photonest/infrastructure/repositories/api_album_repository.dart';
import 'package:photonest/infrastructure/repositories/api_auth_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_curation_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_library_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_original_repository.dart';
import 'package:photonest/infrastructure/repositories/api_media_playback_repository.dart';
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
import 'package:photonest/main.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/l10n/app_localizations_ja.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/licenses/app_license_registry.dart';
import 'package:photonest/presentation/navigation/app_routes.dart';
import 'package:photonest/presentation/pages/albums/album_detail_page.dart';
import 'package:photonest/presentation/pages/albums/albums_tab.dart';
import 'package:photonest/presentation/pages/auth/login_page.dart';
import 'package:photonest/presentation/pages/main_page.dart';
import 'package:photonest/presentation/pages/media/media_search_bar.dart';
import 'package:photonest/presentation/pages/media/media_tab.dart';
import 'package:photonest/presentation/pages/media/trash_page.dart';
import 'package:photonest/presentation/pages/notifications/notifications_page.dart';
import 'package:photonest/presentation/pages/system/about_page.dart';
import 'package:photonest/presentation/pages/system/debug_page.dart';
import 'package:photonest/presentation/pages/system/deep_link_page.dart';
import 'package:photonest/presentation/pages/system/logs_page.dart';
import 'package:photonest/presentation/pages/system/not_found_page.dart';
import 'package:photonest/presentation/pages/upload/upload_tab.dart';
import 'package:photonest/presentation/providers/album_providers.dart';
import 'package:photonest/presentation/providers/app_info_providers.dart';
import 'package:photonest/presentation/providers/app_providers.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/providers/notification_providers.dart';
import 'package:photonest/presentation/providers/session_providers.dart';
import 'package:photonest/presentation/providers/settings_providers.dart';
import 'package:photonest/presentation/providers/upload_providers.dart';
import 'package:photonest/presentation/theme/app_colors.dart';
import 'package:photonest/presentation/theme/app_radius.dart';
import 'package:photonest/presentation/theme/app_spacing.dart';
import 'package:photonest/presentation/theme/app_text_styles.dart';
import 'package:photonest/presentation/theme/app_theme.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/app_card.dart';
import 'package:photonest/presentation/widgets/ui/app_drawer.dart';
import 'package:photonest/presentation/widgets/ui/app_footer.dart';
import 'package:photonest/presentation/widgets/ui/app_header.dart';
import 'package:photonest/presentation/widgets/ui/app_license_launcher.dart';
import 'package:photonest/presentation/widgets/ui/app_primary_button.dart';
import 'package:photonest/presentation/widgets/ui/app_state_views.dart';
import 'package:photonest/presentation/widgets/ui/app_text_field.dart';
import 'package:photonest/presentation/widgets/ui/media_tile.dart';
import 'package:photonest/presentation/widgets/ui/media_viewer.dart';
import 'package:photonest/presentation/widgets/ui/thumbnail_image.dart';
import 'package:photonest/presentation/widgets/ui/video_playback_view.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';
import 'package:photonest/shared/app_config.dart';
import 'package:photonest/shared/build_info.dart';

void main() {
  test('every library under lib/ is imported by this file', () {
    final onDisk = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart'))
        .map((p) => "import 'package:photonest/${p.substring('lib/'.length)}';")
        .toSet();

    final declared = File('test/coverage_surface_test.dart')
        .readAsLinesSync()
        .where((l) => l.startsWith("import 'package:photonest/"))
        .toSet();

    expect(
      onDisk.difference(declared),
      isEmpty,
      reason:
          'Add the missing import(s) to test/coverage_surface_test.dart so '
          'the new library is included in the coverage total.',
    );
    expect(
      declared.difference(onDisk),
      isEmpty,
      reason:
          'Remove the stale import(s) from test/coverage_surface_test.dart — '
          'those libraries no longer exist.',
    );
  });
}
