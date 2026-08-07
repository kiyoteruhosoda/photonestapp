import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/infrastructure/repositories/secure_storage_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> stored;

  setUp(() {
    stored = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      stored,
    );
  });

  Future<SecureStorageSessionRepository> open({
    Map<String, Object> legacyValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(legacyValues);
    return SecureStorageSessionRepository.create(
      const FlutterSecureStorage(),
      await SharedPreferences.getInstance(),
    );
  }

  test('starts signed out on an empty keystore', () async {
    final repository = await open();
    expect(repository.load(), isNull);
  });

  test('round-trips a session through the keystore', () async {
    final repository = await open();
    await repository.save(testAuthSession);

    expect(repository.load(), testAuthSession);
    expect(repository.load()?.scopes, testAuthSession.scopes);
    // The tokens really live in the (stubbed) keystore, not only in memory.
    expect(stored['auth.accessToken'], testAuthSession.accessToken);

    // A fresh instance — an app restart — reads the same session back.
    final reopened = await open();
    expect(reopened.load(), testAuthSession);
    expect(reopened.load()?.email, testAuthSession.email);
  });

  test('clear forgets the session everywhere', () async {
    final repository = await open();
    await repository.save(testAuthSession);
    await repository.clear();

    expect(repository.load(), isNull);
    expect(stored, isEmpty);
  });

  test('save and clear broadcast on the changes stream', () async {
    final repository = await open();
    final events = <Object?>[];
    final subscription = repository.changes.listen(events.add);
    addTearDown(subscription.cancel);

    await repository.save(testAuthSession);
    await repository.clear();
    await pumpEventQueue();

    expect(events, [testAuthSession, null]);
  });

  test(
    'migrates plaintext tokens a pre-keystore build left behind', //
    () async {
      final repository = await open(
        legacyValues: {
          'auth.accessToken': 'legacy-access',
          'auth.refreshToken': 'legacy-refresh',
          'auth.email': 'user@example.com',
          'auth.scopes': ['gui:view', 'album:view'],
        },
      );

      final restored = repository.load();
      expect(restored, isNotNull);
      expect(restored!.accessToken, 'legacy-access');
      expect(restored.refreshToken, 'legacy-refresh');
      expect(restored.email, 'user@example.com');
      expect(restored.scopes, ['gui:view', 'album:view']);

      // The plaintext copies are purged.
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString('auth.accessToken'), isNull);
      expect(preferences.getString('auth.refreshToken'), isNull);
    },
  );

  test('a half-written keystore does not count as migrated', () async {
    // A previous launch died between the two token writes. The fragment
    // must not be treated as the real session — and above all it must not
    // trigger the purge of the still-valid plaintext pair.
    stored['auth.accessToken'] = 'fragment-access';

    final repository = await open(
      legacyValues: {
        'auth.accessToken': 'legacy-access',
        'auth.refreshToken': 'legacy-refresh',
        'auth.email': 'user@example.com',
      },
    );

    final restored = repository.load();
    expect(restored, isNotNull);
    expect(restored!.accessToken, 'legacy-access');
    expect(restored.refreshToken, 'legacy-refresh');
    expect(stored['auth.accessToken'], 'legacy-access');
    expect(stored['auth.refreshToken'], 'legacy-refresh');
  });

  test('an existing keystore session wins over legacy leftovers', () async {
    final first = await open();
    await first.save(testAuthSession);

    final repository = await open(
      legacyValues: {
        'auth.accessToken': 'stale-legacy-access',
        'auth.refreshToken': 'stale-legacy-refresh',
      },
    );

    expect(repository.load(), testAuthSession);
    // The stale plaintext is still purged.
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('auth.accessToken'), isNull);
  });

  test('corrupted keystore content reads back as signed out', () async {
    stored['auth.accessToken'] = '';
    stored['auth.refreshToken'] = 'r';
    final repository = await open();
    expect(repository.load(), isNull);
  });
}
