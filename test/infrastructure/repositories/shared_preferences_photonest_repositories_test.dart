import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_api_endpoint_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_auto_upload_settings_repository.dart';
import 'package:flutterbase/infrastructure/repositories/shared_preferences_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> preferences() {
    SharedPreferences.setMockInitialValues(const {});
    return SharedPreferences.getInstance();
  }

  group('SharedPreferencesSessionRepository', () {
    test('round-trips a session', () async {
      final repository = SharedPreferencesSessionRepository(
        await preferences(),
      );

      expect(repository.load(), isNull);
      await repository.save(testAuthSession);

      final restored = repository.load();
      expect(restored, testAuthSession);
      expect(restored?.email, testAuthSession.email);
      expect(restored?.scopes, testAuthSession.scopes);
    });

    test('clear forgets everything', () async {
      final repository = SharedPreferencesSessionRepository(
        await preferences(),
      );
      await repository.save(testAuthSession);
      await repository.clear();
      expect(repository.load(), isNull);
    });

    test(
      'corrupted storage reads back as signed out, not as a crash', //
      () async {
        SharedPreferences.setMockInitialValues(const {
          'auth.accessToken': '',
          'auth.refreshToken': 'r',
        });
        final repository = SharedPreferencesSessionRepository(
          await SharedPreferences.getInstance(),
        );
        expect(repository.load(), isNull);
      },
    );
  });

  group('SharedPreferencesApiEndpointRepository', () {
    test('round-trips the endpoint', () async {
      final repository = SharedPreferencesApiEndpointRepository(
        await preferences(),
      );
      expect(repository.load(), isNull);

      await repository.save(Uri.parse('https://photos.example.com'));
      expect(repository.load(), Uri.parse('https://photos.example.com'));
    });
  });

  group('SharedPreferencesAutoUploadSettingsRepository', () {
    test('defaults to disabled with no stamp', () async {
      final repository = SharedPreferencesAutoUploadSettingsRepository(
        await preferences(),
      );
      expect(repository.isEnabled(), isFalse);
      expect(repository.enabledSince(), isNull);
    });

    test(
      'the first enable stamps "since" once and keeps it forever', //
      () async {
        final stamps = [DateTime.utc(2026, 8, 1), DateTime.utc(2026, 8, 5)];
        var calls = 0;
        final repository = SharedPreferencesAutoUploadSettingsRepository(
          await preferences(),
          clock: () => stamps[calls++],
        );

        await repository.setEnabled(true);
        expect(repository.isEnabled(), isTrue);
        expect(repository.enabledSince(), DateTime.utc(2026, 8, 1));

        // Toggling off and on again must not move the stamp: the photos taken
        // in the gap are already guarded by the upload history.
        await repository.setEnabled(false);
        await repository.setEnabled(true);
        expect(repository.enabledSince(), DateTime.utc(2026, 8, 1));
        expect(calls, 1);
      },
    );
  });
}
