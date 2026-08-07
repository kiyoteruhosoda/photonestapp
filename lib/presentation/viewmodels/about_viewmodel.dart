import 'package:flutter/foundation.dart';
import 'package:flutterbase/application/ports/app_logger.dart';
import 'package:flutterbase/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/errors/app_error.dart';

/// UI state for the About page.
enum AboutState { loading, loaded, error }

/// ViewModel for `AboutPage`.
///
/// Calls [GetAppInfoUseCase] and exposes the result for display.
/// Contains no business logic — only loading state and display data.
class AboutViewModel extends ChangeNotifier {
  AboutViewModel(this._getAppInfo, this._logger);

  final GetAppInfoUseCase _getAppInfo;
  final AppLogger _logger;

  AboutState _state = AboutState.loading;
  AppInfo? _appInfo;
  AppError? _error;

  AboutState get state => _state;
  AppInfo? get appInfo => _appInfo;
  AppError? get appError => _error;

  Future<void> loadAppInfo() async {
    _logger.debug('[AboutViewModel] loadAppInfo start');
    _state = AboutState.loading;
    _error = null;
    notifyListeners();

    try {
      _appInfo = await _getAppInfo.execute();
      _state = AboutState.loaded;
      _logger.debug(
        '[AboutViewModel] loadAppInfo success — v${_appInfo?.version}',
      );
    } on Exception catch (e, st) {
      _error = UnexpectedError(
        'Failed to load app info',
        cause: e,
        stackTrace: st,
      );
      _state = AboutState.error;
      _logger.error(
        '[AboutViewModel] loadAppInfo failed',
        error: e,
        stackTrace: st,
      );
    } finally {
      notifyListeners();
    }
  }
}
