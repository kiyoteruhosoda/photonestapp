import 'package:flutter/foundation.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/usecases/debug/get_debug_settings_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_debug_mode_usecase.dart';
import 'package:flutterbase/application/usecases/debug/set_log_level_usecase.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';

/// Manages debug mode and log-level preferences.
///
/// Debug mode controls the visibility of developer-only menu items (Logs,
/// Debug Info). Log level controls the minimum severity recorded by
/// [AppLogger]. Both defaults are intentionally developer-friendly
/// (on / debug).
class DebugSettingsViewModel extends ChangeNotifier {
  DebugSettingsViewModel(
    this._getSettings,
    this._setDebugMode,
    this._setLogLevel,
    this._logger,
  ) {
    _debugEnabled = _getSettings.executeDebugMode();
    _logLevel = _getSettings.executeLogLevel();
    _logger.debug(
      '[DebugSettingsViewModel] init — debugEnabled: $_debugEnabled, '
      'logLevel: ${_logLevel.name}',
    );
  }

  final GetDebugSettingsUseCase _getSettings;
  final SetDebugModeUseCase _setDebugMode;
  final SetLogLevelUseCase _setLogLevel;
  final AppLogger _logger;

  late bool _debugEnabled;
  late LogLevel _logLevel;

  bool get debugEnabled => _debugEnabled;
  LogLevel get logLevel => _logLevel;

  Future<void> setDebugEnabled(bool value) async {
    _logger.info('[DebugSettingsViewModel] setDebugEnabled: $value');
    await _setDebugMode.execute(value);
    _debugEnabled = value;
    notifyListeners();
  }

  Future<void> setLogLevel(LogLevel level) async {
    _logger.info('[DebugSettingsViewModel] setLogLevel: ${level.name}');
    await _setLogLevel.execute(level);
    _logLevel = level;
    notifyListeners();
  }
}
