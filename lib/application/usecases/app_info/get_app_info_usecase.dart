import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/repositories/app_info_repository.dart';

/// Returns the application's version and build metadata.
final class GetAppInfoUseCase {
  const GetAppInfoUseCase(this._repository);

  final AppInfoRepository _repository;

  Future<AppInfo> execute() => _repository.getAppInfo();
}
