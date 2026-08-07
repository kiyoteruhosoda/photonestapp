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
import 'package:flutterbase/app/bootstrap/app_router.dart';
import 'package:flutterbase/app/bootstrap/app_widget.dart';
import 'package:flutterbase/app/di/provider_overrides.dart';
import 'package:flutterbase/app/di/service_locator.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/ports/external_link_launcher.dart';
import 'package:flutterbase/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/add_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/get_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/list_bookmarks_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/open_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/remove_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_log_level_usecase.dart';
import 'package:flutterbase/application/usecases/language/get_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/language/set_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/theme/get_theme_preference_usecase.dart';
import 'package:flutterbase/application/usecases/theme/set_theme_preference_usecase.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/entities/log_entry.dart';
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
import 'package:flutterbase/infrastructure/database/app_database.dart';
import 'package:flutterbase/infrastructure/infrastructure_module.dart';
import 'package:flutterbase/infrastructure/links/url_launcher_external_link_launcher.dart';
import 'package:flutterbase/infrastructure/logging/persistent_app_logger.dart';
import 'package:flutterbase/infrastructure/repositories/package_info_app_info_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_debug_settings_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_language_preference_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_theme_preference_repository.dart';
import 'package:flutterbase/infrastructure/repositories/sqflite_bookmark_repository.dart';
import 'package:flutterbase/main.dart';
import 'package:flutterbase/presentation/app_scope.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_ja.dart';
import 'package:flutterbase/presentation/licenses/app_license_registry.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmark_detail_page.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmark_form_dialog.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmarks_page.dart';
import 'package:flutterbase/presentation/pages/main_page.dart';
import 'package:flutterbase/presentation/pages/system/about_page.dart';
import 'package:flutterbase/presentation/pages/system/debug_page.dart';
import 'package:flutterbase/presentation/pages/system/deep_link_page.dart';
import 'package:flutterbase/presentation/pages/system/logs_page.dart';
import 'package:flutterbase/presentation/pages/system/not_found_page.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';
import 'package:flutterbase/presentation/providers/bookmark_providers.dart';
import 'package:flutterbase/presentation/theme/app_colors.dart';
import 'package:flutterbase/presentation/theme/app_radius.dart';
import 'package:flutterbase/presentation/theme/app_spacing.dart';
import 'package:flutterbase/presentation/theme/app_text_styles.dart';
import 'package:flutterbase/presentation/theme/app_theme.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/viewmodels/about_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/debug_settings_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/debug_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/language_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/theme_viewmodel.dart';
import 'package:flutterbase/presentation/widgets/ui/app_card.dart';
import 'package:flutterbase/presentation/widgets/ui/app_drawer.dart';
import 'package:flutterbase/presentation/widgets/ui/app_footer.dart';
import 'package:flutterbase/presentation/widgets/ui/app_header.dart';
import 'package:flutterbase/presentation/widgets/ui/app_license_launcher.dart';
import 'package:flutterbase/presentation/widgets/ui/app_primary_button.dart';
import 'package:flutterbase/presentation/widgets/ui/app_state_views.dart';
import 'package:flutterbase/presentation/widgets/ui/app_text_field.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';
import 'package:flutterbase/shared/build_info.dart';

void main() {
  test('every library under lib/ is imported by this file', () {
    final onDisk = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.path.replaceAll(r'\', '/'))
        .where((p) => p.endsWith('.dart'))
        .map(
          (p) => "import 'package:flutterbase/${p.substring('lib/'.length)}';",
        )
        .toSet();

    final declared = File('test/coverage_surface_test.dart')
        .readAsLinesSync()
        .where((l) => l.startsWith("import 'package:flutterbase/"))
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
