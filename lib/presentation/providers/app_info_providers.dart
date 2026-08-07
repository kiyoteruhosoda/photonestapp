import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

final Provider<GetAppInfoUseCase> getAppInfoUseCaseProvider =
    Provider<GetAppInfoUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getAppInfoUseCaseProvider'),
      );
    });

/// Build metadata for the About and Debug pages.
///
/// `autoDispose` so each visit loads fresh — the same lifetime the old
/// per-route ViewModels had — and `ref.invalidate` is the retry button.
final FutureProvider<AppInfo> appInfoProvider =
    FutureProvider.autoDispose<AppInfo>((ref) async {
      final logger = ref.read(appLoggerProvider);
      logger.debug('[AppInfo] load start');
      try {
        final info = await ref.read(getAppInfoUseCaseProvider).execute();
        logger.debug('[AppInfo] load success — v${info.version}');
        return info;
      } on Exception catch (error, stackTrace) {
        logger.error(
          '[AppInfo] load failed',
          error: error,
          stackTrace: stackTrace,
        );
        rethrow;
      }
    });
