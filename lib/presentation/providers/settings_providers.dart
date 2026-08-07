import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_log_level_usecase.dart';
import 'package:flutterbase/application/usecases/language/get_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/language/set_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/theme/get_theme_preference_usecase.dart';
import 'package:flutterbase/application/usecases/theme/set_theme_preference_usecase.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/app_theme_mode.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────
//
// One provider per use case, overridden by the composition root — the same
// pattern as every other feature.

final Provider<GetThemePreferenceUseCase> getThemePreferenceUseCaseProvider =
    Provider<GetThemePreferenceUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getThemePreferenceUseCaseProvider'),
      );
    });

final Provider<SetThemePreferenceUseCase> setThemePreferenceUseCaseProvider =
    Provider<SetThemePreferenceUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('setThemePreferenceUseCaseProvider'),
      );
    });

final Provider<GetLanguagePreferenceUseCase>
getLanguagePreferenceUseCaseProvider = Provider<GetLanguagePreferenceUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('getLanguagePreferenceUseCaseProvider'),
  );
});

final Provider<SetLanguagePreferenceUseCase>
setLanguagePreferenceUseCaseProvider = Provider<SetLanguagePreferenceUseCase>((
  ref,
) {
  throw UnimplementedError(
    missingOverrideMessage('setLanguagePreferenceUseCaseProvider'),
  );
});

final Provider<GetDebugSettingsUseCase> getDebugSettingsUseCaseProvider =
    Provider<GetDebugSettingsUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getDebugSettingsUseCaseProvider'),
      );
    });

final Provider<SetDebugModeUseCase> setDebugModeUseCaseProvider =
    Provider<SetDebugModeUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('setDebugModeUseCaseProvider'),
      );
    });

final Provider<SetLogLevelUseCase> setLogLevelUseCaseProvider =
    Provider<SetLogLevelUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('setLogLevelUseCaseProvider'),
      );
    });

// ─── Theme ─────────────────────────────────────────────────────────────────

/// The app-wide [ThemeMode], restored synchronously at first read and
/// persisted on every change.
final NotifierProvider<ThemeModeNotifier, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Holds the theme choice and persists it via the theme use cases.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final restored = _toFlutterMode(
      ref.read(getThemePreferenceUseCaseProvider).execute(),
    );
    ref
        .read(appLoggerProvider)
        .debug('[Theme] init — themeMode: ${restored.name}');
    return restored;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    ref.read(appLoggerProvider).debug('[Theme] setThemeMode: ${mode.name}');
    state = mode;
    await ref.read(setThemePreferenceUseCaseProvider).execute(_toAppMode(mode));
  }

  static ThemeMode _toFlutterMode(AppThemeMode mode) => switch (mode) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };

  static AppThemeMode _toAppMode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => AppThemeMode.light,
    ThemeMode.dark => AppThemeMode.dark,
    ThemeMode.system => AppThemeMode.system,
  };
}

// ─── Language ──────────────────────────────────────────────────────────────

/// The app-wide language preference.
final NotifierProvider<AppLanguageNotifier, AppLanguage> appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, AppLanguage>(AppLanguageNotifier.new);

/// Holds the language choice and persists it via the language use cases.
class AppLanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    final restored = ref.read(getLanguagePreferenceUseCaseProvider).execute();
    ref
        .read(appLoggerProvider)
        .debug('[Language] init — language: ${restored.name}');
    return restored;
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (state == language) return;
    ref
        .read(appLoggerProvider)
        .debug('[Language] setLanguage: ${language.name}');
    state = language;
    await ref.read(setLanguagePreferenceUseCaseProvider).execute(language);
  }
}

/// The [Locale] to pass to `MaterialApp.locale`, or null when the user
/// follows the OS language.
Locale? localeOf(AppLanguage language) => switch (language) {
  AppLanguage.english => const Locale('en'),
  AppLanguage.japanese => const Locale('ja'),
  AppLanguage.system => null,
};

// ─── Debug settings ────────────────────────────────────────────────────────

/// Debug mode and minimum log level, as one value.
typedef DebugSettings = ({bool debugEnabled, LogLevel logLevel});

/// Developer settings: debug-menu visibility and the log level.
final NotifierProvider<DebugSettingsNotifier, DebugSettings>
debugSettingsProvider = NotifierProvider<DebugSettingsNotifier, DebugSettings>(
  DebugSettingsNotifier.new,
);

/// Holds the developer settings and persists them via the debug use cases.
class DebugSettingsNotifier extends Notifier<DebugSettings> {
  @override
  DebugSettings build() {
    final settings = ref.read(getDebugSettingsUseCaseProvider);
    final restored = (
      debugEnabled: settings.executeDebugMode(),
      logLevel: settings.executeLogLevel(),
    );
    ref
        .read(appLoggerProvider)
        .debug(
          '[DebugSettings] init — debugEnabled: ${restored.debugEnabled}, '
          'logLevel: ${restored.logLevel.name}',
        );
    return restored;
  }

  Future<void> setDebugEnabled(bool enabled) async {
    ref.read(appLoggerProvider).info('[DebugSettings] debugEnabled: $enabled');
    await ref.read(setDebugModeUseCaseProvider).execute(enabled);
    state = (debugEnabled: enabled, logLevel: state.logLevel);
  }

  Future<void> setLogLevel(LogLevel level) async {
    ref.read(appLoggerProvider).info('[DebugSettings] logLevel: ${level.name}');
    await ref.read(setLogLevelUseCaseProvider).execute(level);
    state = (debugEnabled: state.debugEnabled, logLevel: level);
  }
}
