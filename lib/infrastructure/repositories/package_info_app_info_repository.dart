import 'package:package_info_plus/package_info_plus.dart';
import 'package:photonest/domain/entities/app_info.dart';
import 'package:photonest/domain/repositories/app_info_repository.dart';
import 'package:photonest/shared/build_info.dart';

/// Retrieves app version from [PackageInfo] and build metadata from
/// [BuildInfo].
final class PackageInfoAppInfoRepository implements AppInfoRepository {
  const PackageInfoAppInfoRepository();

  @override
  Future<AppInfo> getAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();

    // Prefer PackageInfo.version (reflects actual installed build),
    // fall back to the compile-time constant from BuildInfo.
    final version = packageInfo.version.isNotEmpty
        ? packageInfo.version
        : BuildInfo.version;

    return AppInfo(
      version: version,
      buildNumber: BuildInfo.buildNumber,
      gitCommit: BuildInfo.gitCommit,
      gitCommitFull: BuildInfo.gitCommitFull,
      flutterVersion: BuildInfo.flutterVersion,
      dartVersion: BuildInfo.dartVersion,
      buildDate: BuildInfo.buildDate,
      isDebug: BuildInfo.isDebug,
    );
  }
}
