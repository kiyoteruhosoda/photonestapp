import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/log_entry.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/infrastructure/logging/persistent_app_logger.dart';

// PersistentAppLogger is exercised directly. `init()` is never called, so no
// file I/O happens and only the in-memory buffer and console output are under
// test. The default minimum level is `debug`, so tests that care about
// `verbose` lower it explicitly.
PersistentAppLogger _fresh({LogLevel minLevel = LogLevel.verbose}) {
  final logger = PersistentAppLogger()..setMinLevel(minLevel);
  return logger;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersistentAppLogger — in-memory buffer', () {
    test('buffer starts empty on a fresh instance', () {
      expect(_fresh().entries, isEmpty);
    });

    test('verbose logs are stored with correct level', () {
      final log = _fresh();
      log.verbose('verbose message');
      expect(log.entries, hasLength(1));
      expect(log.entries.first.level, equals(LogLevel.verbose));
      expect(log.entries.first.message, equals('verbose message'));
    });

    test('debug logs are stored', () {
      final log = _fresh();
      log.debug('debug msg');
      expect(log.entries.first.level, equals(LogLevel.debug));
    });

    test('info logs are stored', () {
      final log = _fresh();
      log.info('info msg');
      expect(log.entries.first.level, equals(LogLevel.info));
    });

    test('warning logs are stored', () {
      final log = _fresh();
      log.warning('warn msg');
      expect(log.entries.first.level, equals(LogLevel.warning));
    });

    test('error logs are stored with error object', () {
      final log = _fresh();
      final err = Exception('oops');
      log.error('error msg', error: err);
      final entry = log.entries.first;
      expect(entry.level, equals(LogLevel.error));
      expect(entry.error, equals(err));
    });

    test('entries accumulate in insertion order', () {
      final log = _fresh();
      log.info('first');
      log.info('second');
      log.info('third');
      expect(
        log.entries.map((e) => e.message),
        equals(['first', 'second', 'third']),
      );
    });

    test('buffer is capped at maxBufferEntries', () {
      final log = _fresh();
      for (var i = 0; i <= PersistentAppLogger.maxBufferEntries + 10; i++) {
        log.debug('entry $i');
      }
      expect(log.entries.length, equals(PersistentAppLogger.maxBufferEntries));
    });

    test('clearBuffer empties the buffer', () {
      final log = _fresh();
      log.info('test');
      log.clearBuffer();
      expect(log.entries, isEmpty);
    });
  });

  group('PersistentAppLogger — level filtering', () {
    late PersistentAppLogger log;

    setUp(() {
      log = _fresh();
      log.verbose('v');
      log.debug('d');
      log.info('i');
      log.warning('w');
      log.error('e');
    });

    test('entriesForLevel(null) returns all five entries', () {
      expect(log.entriesForLevel(null), hasLength(5));
    });

    test('entriesForLevel(verbose) returns only verbose', () {
      final filtered = log.entriesForLevel(LogLevel.verbose);
      expect(filtered, hasLength(1));
      expect(filtered.first.level, equals(LogLevel.verbose));
    });

    test('entriesForLevel(error) returns only errors', () {
      final filtered = log.entriesForLevel(LogLevel.error);
      expect(filtered, hasLength(1));
      expect(filtered.first.level, equals(LogLevel.error));
    });
  });

  group('LogEntry', () {
    test('toLogLine includes ISO timestamp, level label, and message', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 4, 7, 12, 0, 0),
        level: LogLevel.info,
        message: 'hello',
      );
      final line = entry.toLogLine();
      expect(line, contains('[I]'));
      expect(line, contains('hello'));
      expect(line, contains('2026-04-07'));
    });

    test('toLogLine appends error string when present', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'fail',
        error: Exception('boom'),
      );
      expect(entry.toLogLine(), contains('ERROR'));
    });

    test('levelLabel is a single uppercase character', () {
      final cases = {
        LogLevel.verbose: 'V',
        LogLevel.debug: 'D',
        LogLevel.info: 'I',
        LogLevel.warning: 'W',
        LogLevel.error: 'E',
      };
      for (final entry in cases.entries) {
        final logEntry = LogEntry(
          timestamp: DateTime.now(),
          level: entry.key,
          message: '',
        );
        expect(logEntry.levelLabel, equals(entry.value));
      }
    });
  });

  group('PersistentAppLogger — minimum level', () {
    test('defaults to debug, which drops verbose messages', () {
      final log = PersistentAppLogger();
      expect(log.minLevel, equals(LogLevel.debug));
      log.verbose('dropped');
      expect(log.entries, isEmpty);
    });

    test('setMinLevel raises the threshold and drops lower levels', () {
      final log = _fresh()..setMinLevel(LogLevel.warning);
      log
        ..debug('dropped')
        ..info('dropped')
        ..warning('kept')
        ..error('kept');
      expect(log.entries.map((e) => e.message), equals(['kept', 'kept']));
    });
  });

  group('PersistentAppLogger — file persistence', () {
    late Directory documentsDir;

    setUp(() async {
      documentsDir = await Directory.systemTemp.createTemp('flutterbase_logs');
      _stubDocumentsDirectory(documentsDir.path);
    });

    tearDown(() async {
      _stubDocumentsDirectory(null);
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
    });

    test('logFilePaths is empty before init opens a file', () async {
      expect(await _fresh().logFilePaths(), isEmpty);
    });

    test('init opens a log file that logFilePaths then reports', () async {
      final log = _fresh();
      await log.init();
      log.info('persisted');

      final paths = await log.logFilePaths();
      expect(paths, hasLength(1));
      expect(paths.single, endsWith('.log'));
    });

    test('init restores the saved minimum level', () async {
      final log = PersistentAppLogger();
      await log.init(savedLevel: LogLevel.warning);
      expect(log.minLevel, equals(LogLevel.warning));
    });

    test('exportLogs writes the buffer to a new file', () async {
      final log = _fresh();
      await log.init();
      log
        ..info('line one')
        ..error('line two');

      final exported = await log.exportLogs();
      expect(exported, isNotNull);

      final contents = await File(exported!).readAsString();
      expect(contents, contains('line one'));
      expect(contents, contains('line two'));
    });

    test(
      'exportLogs returns null when the platform has no directory',
      () async {
        _stubDocumentsDirectory(null);
        expect(await _fresh().exportLogs(), isNull);
      },
    );
  });
}

/// Points `path_provider` at [path], or makes it fail when [path] is null.
void _stubDocumentsDirectory(String? path) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        path == null
            ? null
            : (call) async => call.method == 'getApplicationDocumentsDirectory'
                  ? path
                  : null,
      );
}
