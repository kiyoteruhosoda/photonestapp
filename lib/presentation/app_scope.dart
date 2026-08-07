import 'package:flutter/widgets.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/presentation/viewmodels/about_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/debug_settings_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/debug_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/language_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/theme_viewmodel.dart';

/// Presentation-side dependency boundary.
///
/// Pages and widgets read their ViewModels from here instead of importing the
/// service locator, which lives in the composition root (`lib/app/di/`).
/// Keeping the arrow pointing this way means Presentation depends only on
/// Application and Domain — the composition root pushes the wired instances
/// down, rather than the UI pulling them up.
///
/// Long-lived ViewModels are supplied as instances; per-screen ViewModels are
/// supplied as factories so each route gets a fresh one.
class AppScope extends InheritedWidget {
  const AppScope({
    required this.logger,
    required this.themeViewModel,
    required this.languageViewModel,
    required this.debugSettingsViewModel,
    required this.createAboutViewModel,
    required this.createDebugViewModel,
    required super.child,
    super.key,
  });

  /// Logging port, for widgets that need to record user-visible failures.
  final AppLogger logger;

  final ThemeViewModel themeViewModel;
  final LanguageViewModel languageViewModel;
  final DebugSettingsViewModel debugSettingsViewModel;

  /// Builds a fresh [AboutViewModel] for a single About route.
  final AboutViewModel Function() createAboutViewModel;

  /// Builds a fresh [DebugViewModel] for a single Debug route.
  final DebugViewModel Function() createDebugViewModel;

  /// Returns the nearest [AppScope].
  ///
  /// Throws a [FlutterError] when no scope is installed, which almost always
  /// means a widget was pumped in a test without wrapping it in an [AppScope].
  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw FlutterError(
        'AppScope.of() called with a context that does not contain an '
        'AppScope.\nWrap the widget tree in an AppScope — the app does this '
        'in lib/app/bootstrap/app_widget.dart.',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      logger != oldWidget.logger ||
      themeViewModel != oldWidget.themeViewModel ||
      languageViewModel != oldWidget.languageViewModel ||
      debugSettingsViewModel != oldWidget.debugSettingsViewModel;
}
