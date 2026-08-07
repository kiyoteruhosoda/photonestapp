import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/domain/entities/log_entry.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

/// In-memory [AppLogger] test double.
///
/// Records every call so tests can assert on outbound port interactions
/// without touching the file system.
final class RecordingAppLogger implements AppLogger {
  final List<LogEntry> _entries = <LogEntry>[];

  /// Set when [exportLogs] should report a failure.
  bool exportFails = false;

  /// Number of times [clearBuffer] was called.
  int clearBufferCalls = 0;

  /// Levels passed to [setMinLevel], in call order.
  final List<LogLevel> setMinLevelCalls = <LogLevel>[];

  LogLevel _minLevel = LogLevel.verbose;

  /// Messages recorded at [level], in call order.
  List<String> messagesAt(LogLevel level) =>
      _entries.where((e) => e.level == level).map((e) => e.message).toList();

  void _record(
    LogLevel level,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    _entries.add(
      LogEntry(
        // Fixed instant: tests must not depend on wall-clock time.
        timestamp: DateTime.utc(2024),
        level: level,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  @override
  void verbose(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.verbose, message, error, stackTrace);

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.debug, message, error, stackTrace);

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.info, message, error, stackTrace);

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.warning, message, error, stackTrace);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _record(LogLevel.error, message, error, stackTrace);

  @override
  List<LogEntry> get entries => List.unmodifiable(_entries);

  @override
  List<LogEntry> entriesForLevel(LogLevel? level) =>
      level == null ? entries : entries.where((e) => e.level == level).toList();

  @override
  LogLevel get minLevel => _minLevel;

  @override
  void setMinLevel(LogLevel level) {
    setMinLevelCalls.add(level);
    _minLevel = level;
  }

  /// Drops every recorded entry without counting as a [clearBuffer] call.
  ///
  /// Wiring a [TestScope] constructs the ViewModels, and each of those logs
  /// its initial state — so a test that cares about buffer contents starts by
  /// resetting, not by calling the method it is about to assert on.
  void reset() {
    _entries.clear();
    setMinLevelCalls.clear();
    clearBufferCalls = 0;
  }

  @override
  void clearBuffer() {
    clearBufferCalls++;
    _entries.clear();
  }

  @override
  Future<String?> exportLogs() async =>
      exportFails ? null : '/tmp/recording-app-logger.log';

  @override
  Future<List<String>> logFilePaths() async => const <String>[];
}
