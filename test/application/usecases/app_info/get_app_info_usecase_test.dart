import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/app_info/get_app_info_usecase.dart';
import 'package:flutterbase/domain/entities/app_info.dart';
import 'package:flutterbase/domain/repositories/app_info_repository.dart';

// ─── Fake repository ─────────────────────────────────────────────────────

class _FakeAppInfoRepository implements AppInfoRepository {
  const _FakeAppInfoRepository(this._dto);
  final AppInfo _dto;

  @override
  Future<AppInfo> getAppInfo() async => _dto;
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  const fakeDto = AppInfo(
    version: '1.2.3',
    buildNumber: '42',
    gitCommit: 'abc1234',
    gitCommitFull: 'abc1234def5678',
    flutterVersion: '3.29.0',
    dartVersion: '3.7.0',
    buildDate: '2026-04-07T00:00:00Z',
    isDebug: true,
  );

  group('GetAppInfoUseCase', () {
    test('returns AppInfo from repository', () async {
      const useCase = GetAppInfoUseCase(_FakeAppInfoRepository(fakeDto));
      final result = await useCase.execute();
      expect(result.version, equals('1.2.3'));
      expect(result.buildNumber, equals('42'));
      expect(result.gitCommit, equals('abc1234'));
      expect(result.flutterVersion, equals('3.29.0'));
      expect(result.dartVersion, equals('3.7.0'));
      expect(result.isDebug, isTrue);
    });

    test('propagates repository exceptions', () async {
      final repo = _ThrowingAppInfoRepository();
      final useCase = GetAppInfoUseCase(repo);
      expect(useCase.execute, throwsException);
    });
  });
}

class _ThrowingAppInfoRepository implements AppInfoRepository {
  @override
  Future<AppInfo> getAppInfo() => throw Exception('platform unavailable');
}
