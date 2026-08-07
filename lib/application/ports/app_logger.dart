import 'package:flutterbase/domain/entities/log_entry.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

/// Outbound logging port.
///
/// Declared in Application so that Use Cases and Presentation depend on the
/// contract rather than on a logging backend. The concrete adapter lives in
/// `infrastructure/logging/` and is bound in `app/di/service_locator.dart`.
///
/// The port deliberately speaks in [String] paths rather than `dart:io`
/// handles: `dart:io` is an Infrastructure detail and is rejected outside
/// that layer by `tool/check_architecture.dart`.
abstract interface class AppLogger {
  void verbose(String message, {Object? error, StackTrace? stackTrace});
  void debug(String message, {Object? error, StackTrace? stackTrace});
  void info(String message, {Object? error, StackTrace? stackTrace});
  void warning(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});

  /// All entries currently in the in-memory buffer (oldest first).
  List<LogEntry> get entries;

  /// Entries filtered by [level]; null returns all.
  List<LogEntry> entriesForLevel(LogLevel? level);

  /// Current minimum log level. Messages below this level are silently dropped.
  LogLevel get minLevel;

  /// Changes the minimum log level at runtime.
  void setMinLevel(LogLevel level);

  /// Clears the in-memory buffer. Persistent files are unaffected.
  void clearBuffer();

  /// Exports the buffer to a new file and returns its path, or null on
  /// failure.
  Future<String?> exportLogs();

  /// Returns the paths of all persisted log files (newest first).
  Future<List<String>> logFilePaths();
}
