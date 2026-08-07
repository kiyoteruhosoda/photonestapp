import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:flutterbase/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_log_level_usecase.dart';
import 'package:flutterbase/application/usecases/language/get_language_preference_usecase.dart';
import 'package:flutterbase/application/usecases/language/set_language_preference_usecase.dart';
import 'package:flutterbase/domain/value_objects/app_language.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/viewmodels/about_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/debug_settings_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/debug_viewmodel.dart';
import 'package:flutterbase/presentation/viewmodels/language_viewmodel.dart';

import '../../support/fakes.dart';
import '../../support/recording_app_logger.dart';

LanguageViewModel _languageViewModel(
  FakeLanguagePreferenceRepository repository, {
  RecordingAppLogger? logger,
}) => LanguageViewModel(
  GetLanguagePreferenceUseCase(repository),
  SetLanguagePreferenceUseCase(repository),
  logger ?? RecordingAppLogger(),
);

DebugSettingsViewModel _debugSettingsViewModel(
  FakeDebugSettingsRepository repository, {
  RecordingAppLogger? logger,
}) {
  final resolved = logger ?? RecordingAppLogger();
  return DebugSettingsViewModel(
    GetDebugSettingsUseCase(repository),
    SetDebugModeUseCase(repository),
    SetLogLevelUseCase(repository, resolved),
    resolved,
  );
}

void main() {
  group('LanguageViewModel', () {
    test('reads the stored language on construction', () {
      final viewModel = _languageViewModel(
        FakeLanguagePreferenceRepository(AppLanguage.japanese),
      );
      expect(viewModel.language, AppLanguage.japanese);
    });

    test('logs its initial state', () {
      final logger = RecordingAppLogger();
      _languageViewModel(FakeLanguagePreferenceRepository(), logger: logger);
      expect(
        logger.messagesAt(LogLevel.debug).join(),
        contains('LanguageViewModel'),
      );
    });

    test('maps english to the en locale', () {
      final viewModel = _languageViewModel(
        FakeLanguagePreferenceRepository(AppLanguage.english),
      );
      expect(viewModel.locale, const Locale('en'));
    });

    test('maps japanese to the ja locale', () {
      final viewModel = _languageViewModel(
        FakeLanguagePreferenceRepository(AppLanguage.japanese),
      );
      expect(viewModel.locale, const Locale('ja'));
    });

    test('maps system to a null locale so the OS decides', () {
      final viewModel = _languageViewModel(FakeLanguagePreferenceRepository());
      expect(viewModel.locale, isNull);
    });

    test('setLanguage persists, updates and notifies', () async {
      final repository = FakeLanguagePreferenceRepository();
      final viewModel = _languageViewModel(repository);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.setLanguage(AppLanguage.japanese);

      expect(viewModel.language, AppLanguage.japanese);
      expect(repository.saved, equals([AppLanguage.japanese]));
      expect(notifications, 1);
    });

    test('setLanguage to the current value is a no-op', () async {
      final repository = FakeLanguagePreferenceRepository(AppLanguage.english);
      final viewModel = _languageViewModel(repository);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.setLanguage(AppLanguage.english);

      expect(repository.saved, isEmpty);
      expect(notifications, 0);
    });

    test('a persistence failure surfaces and skips the notification', () async {
      final repository = FakeLanguagePreferenceRepository()..failOnSave = true;
      final viewModel = _languageViewModel(repository);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await expectLater(
        viewModel.setLanguage(AppLanguage.japanese),
        throwsA(isA<Exception>()),
      );
      expect(notifications, 0);
    });
  });

  group('DebugSettingsViewModel', () {
    test('reads both settings on construction', () {
      final viewModel = _debugSettingsViewModel(
        FakeDebugSettingsRepository(
          debugMode: false,
          minLogLevel: LogLevel.warning,
        ),
      );
      expect(viewModel.debugEnabled, isFalse);
      expect(viewModel.logLevel, LogLevel.warning);
    });

    test('setDebugEnabled persists, updates and notifies', () async {
      final repository = FakeDebugSettingsRepository();
      final viewModel = _debugSettingsViewModel(repository);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.setDebugEnabled(false);

      expect(viewModel.debugEnabled, isFalse);
      expect(repository.savedDebugModes, equals([false]));
      expect(notifications, 1);
    });

    test('setLogLevel persists, applies to the logger and notifies', () async {
      final repository = FakeDebugSettingsRepository();
      final logger = RecordingAppLogger();
      final viewModel = _debugSettingsViewModel(repository, logger: logger);
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.setLogLevel(LogLevel.error);

      expect(viewModel.logLevel, LogLevel.error);
      expect(repository.savedLogLevels, equals([LogLevel.error]));
      expect(logger.setMinLevelCalls, equals([LogLevel.error]));
      expect(notifications, 1);
    });

    test('setDebugEnabled to the same value still writes through', () async {
      // Unlike theme and language, debug mode has no early-out: the switch
      // is the source of truth and a redundant write is harmless.
      final repository = FakeDebugSettingsRepository();
      final viewModel = _debugSettingsViewModel(repository);
      await viewModel.setDebugEnabled(true);
      expect(repository.savedDebugModes, equals([true]));
    });
  });

  group('AboutViewModel', () {
    test('starts in the loading state', () {
      final viewModel = AboutViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository()),
        RecordingAppLogger(),
      );
      expect(viewModel.state, AboutState.loading);
      expect(viewModel.appInfo, isNull);
      expect(viewModel.appError, isNull);
    });

    test('loads app info and lands in the loaded state', () async {
      final viewModel = AboutViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository()),
        RecordingAppLogger(),
      );
      final states = <AboutState>[];
      viewModel.addListener(() => states.add(viewModel.state));

      await viewModel.loadAppInfo();

      expect(viewModel.state, AboutState.loaded);
      expect(viewModel.appInfo?.version, testAppInfo.version);
      expect(states, equals([AboutState.loading, AboutState.loaded]));
    });

    test('a repository failure lands in the error state', () async {
      final viewModel = AboutViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository(failure: 'no platform')),
        RecordingAppLogger(),
      );

      await viewModel.loadAppInfo();

      expect(viewModel.state, AboutState.error);
      expect(viewModel.appError?.message, 'Failed to load app info');
      expect(viewModel.appInfo, isNull);
    });

    test('a failure is logged at error level', () async {
      final logger = RecordingAppLogger();
      final viewModel = AboutViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository(failure: 'no platform')),
        logger,
      );

      await viewModel.loadAppInfo();

      expect(logger.messagesAt(LogLevel.error), hasLength(1));
    });

    test('reloading clears the previous error', () async {
      final failing = FakeAppInfoRepository(failure: 'no platform');
      final viewModel = AboutViewModel(
        GetAppInfoUseCase(failing),
        RecordingAppLogger(),
      );
      await viewModel.loadAppInfo();
      expect(viewModel.appError, isNotNull);

      final healthy = AboutViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository()),
        RecordingAppLogger(),
      );
      await healthy.loadAppInfo();
      expect(healthy.appError, isNull);
      expect(healthy.state, AboutState.loaded);
    });
  });

  group('DebugViewModel', () {
    test('starts in the loading state', () {
      final viewModel = DebugViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository()),
        RecordingAppLogger(),
      );
      expect(viewModel.state, DebugState.loading);
    });

    test('loads app info and lands in the loaded state', () async {
      final viewModel = DebugViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository()),
        RecordingAppLogger(),
      );
      await viewModel.loadAppInfo();
      expect(viewModel.state, DebugState.loaded);
      expect(viewModel.appInfo?.buildNumber, testAppInfo.buildNumber);
    });

    test('a repository failure lands in the error state', () async {
      final viewModel = DebugViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository(failure: 'no platform')),
        RecordingAppLogger(),
      );
      await viewModel.loadAppInfo();
      expect(viewModel.state, DebugState.error);
      expect(viewModel.appError?.message, 'Failed to load debug info');
    });

    test('clearLogs empties the buffer and notifies', () {
      final logger = RecordingAppLogger();
      final viewModel = DebugViewModel(
        GetAppInfoUseCase(FakeAppInfoRepository()),
        logger,
      );
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      viewModel.clearLogs();

      expect(logger.clearBufferCalls, 1);
      expect(notifications, 1);
    });
  });
}
