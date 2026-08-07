import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_log_level_usecase.dart';
import 'package:flutterbase/domain/repositories/debug_settings_repository.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

import '../../../support/recording_app_logger.dart';

/// Records every call so tests can assert on the outbound repository port.
final class _FakeDebugSettingsRepository implements DebugSettingsRepository {
  _FakeDebugSettingsRepository({
    this.debugMode = true,
    this.minLogLevel = LogLevel.debug,
  });

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

/// A repository whose writes always fail, for the error paths.
final class _FailingDebugSettingsRepository implements DebugSettingsRepository {
  @override
  bool getDebugModeEnabled() => true;

  @override
  LogLevel getMinLogLevel() => LogLevel.debug;

  @override
  Future<void> saveDebugModeEnabled(bool enabled) async =>
      throw Exception('storage unavailable');

  @override
  Future<void> saveMinLogLevel(LogLevel level) async =>
      throw Exception('storage unavailable');
}

void main() {
  group('GetDebugSettingsUseCase', () {
    test('returns the debug flag the repository holds', () {
      final repository = _FakeDebugSettingsRepository(debugMode: false);
      expect(GetDebugSettingsUseCase(repository).executeDebugMode(), isFalse);
    });

    test('returns the log level the repository holds', () {
      final repository = _FakeDebugSettingsRepository(
        minLogLevel: LogLevel.warning,
      );
      expect(
        GetDebugSettingsUseCase(repository).executeLogLevel(),
        equals(LogLevel.warning),
      );
    });
  });

  group('SetDebugModeUseCase', () {
    test('forwards the flag to the repository exactly once', () async {
      final repository = _FakeDebugSettingsRepository();
      await SetDebugModeUseCase(repository).execute(false);
      expect(repository.savedDebugModes, equals([false]));
    });

    test('propagates a repository failure to the caller', () {
      final useCase = SetDebugModeUseCase(_FailingDebugSettingsRepository());
      expect(useCase.execute(true), throwsA(isA<Exception>()));
    });
  });

  group('SetLogLevelUseCase', () {
    test('persists the level and applies it to the live logger', () async {
      final repository = _FakeDebugSettingsRepository();
      final logger = RecordingAppLogger();

      await SetLogLevelUseCase(repository, logger).execute(LogLevel.error);

      expect(repository.savedLogLevels, equals([LogLevel.error]));
      expect(logger.setMinLevelCalls, equals([LogLevel.error]));
      expect(logger.minLevel, equals(LogLevel.error));
    });

    test('leaves the logger untouched when persistence fails', () {
      final logger = RecordingAppLogger();
      final useCase = SetLogLevelUseCase(
        _FailingDebugSettingsRepository(),
        logger,
      );

      expect(useCase.execute(LogLevel.error), throwsA(isA<Exception>()));
      expect(logger.setMinLevelCalls, isEmpty);
    });

    test('applies each level in call order', () async {
      final repository = _FakeDebugSettingsRepository();
      final logger = RecordingAppLogger();
      final useCase = SetLogLevelUseCase(repository, logger);

      await useCase.execute(LogLevel.info);
      await useCase.execute(LogLevel.verbose);

      expect(
        logger.setMinLevelCalls,
        equals([LogLevel.info, LogLevel.verbose]),
      );
      expect(
        repository.savedLogLevels,
        equals([LogLevel.info, LogLevel.verbose]),
      );
    });
  });
}
