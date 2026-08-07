import 'package:flutterbase/domain/entities/app_info.dart';

/// Provides build-time and runtime application metadata.
///
/// Implementations live in `infrastructure/repositories/`.
abstract interface class AppInfoRepository {
  /// Returns the application's version, build, and runtime metadata.
  Future<AppInfo> getAppInfo();
}
