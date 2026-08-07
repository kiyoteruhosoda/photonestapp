import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/entities/app_info.dart';

AppInfo buildAppInfo({String version = '1.2.3', bool isDebug = false}) =>
    AppInfo(
      version: version,
      buildNumber: '42',
      gitCommit: 'abc1234',
      gitCommitFull: 'abc1234def5678',
      flutterVersion: '3.44.8',
      dartVersion: '3.12.2',
      buildDate: '2026-08-03T00:00:00Z',
      isDebug: isDebug,
    );

void main() {
  group('AppInfo', () {
    test('exposes every field it was constructed with', () {
      final info = buildAppInfo();
      expect(info.version, '1.2.3');
      expect(info.buildNumber, '42');
      expect(info.gitCommit, 'abc1234');
      expect(info.gitCommitFull, 'abc1234def5678');
      expect(info.flutterVersion, '3.44.8');
      expect(info.dartVersion, '3.12.2');
      expect(info.buildDate, '2026-08-03T00:00:00Z');
      expect(info.isDebug, isFalse);
    });

    test('short commit is a prefix of the full commit', () {
      final info = buildAppInfo();
      expect(info.gitCommitFull, startsWith(info.gitCommit));
    });

    test('carries the debug flag through unchanged', () {
      expect(buildAppInfo(isDebug: true).isDebug, isTrue);
    });
  });
}
