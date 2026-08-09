import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/auth/get_api_endpoint_usecase.dart';
import 'package:photonest/application/usecases/auth/login_usecase.dart';
import 'package:photonest/application/usecases/auth/logout_usecase.dart';
import 'package:photonest/application/usecases/auth/restore_session_usecase.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/log_level.dart';
import 'package:photonest/domain/value_objects/login_credentials.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeSessionRepository sessions;
  late FakeApiEndpointRepository endpoints;
  late RecordingAppLogger logger;

  setUp(() {
    auth = FakeAuthRepository();
    sessions = FakeSessionRepository();
    endpoints = FakeApiEndpointRepository();
    logger = RecordingAppLogger();
  });

  LoginCredentials credentials() => LoginCredentials(
    serverUrl: Uri.parse('https://photos.example.com'),
    email: 'user@example.com',
    password: 'secret',
  );

  group('LoginUseCase', () {
    test(
      'saves the endpoint before logging in, then persists the session', //
      () async {
        final usecase = LoginUseCase(auth, sessions, endpoints, logger);

        final session = await usecase.execute(credentials());

        expect(endpoints.saved, [Uri.parse('https://photos.example.com')]);
        expect(auth.logins, hasLength(1));
        expect(sessions.saved, [session]);
        expect(sessions.load(), session);
        expect(session.email, 'user@example.com');
      },
    );

    test(
      'does not persist a session when the server rejects the login', //
      () async {
        auth.failure = const AuthenticationError('nope');
        final usecase = LoginUseCase(auth, sessions, endpoints, logger);

        await expectLater(
          usecase.execute(credentials()),
          throwsA(isA<AuthenticationError>()),
        );
        expect(sessions.saved, isEmpty);
        expect(sessions.load(), isNull);
      },
    );
  });

  group('LogoutUseCase', () {
    test('revokes server-side and clears the local session', () async {
      await sessions.save(testAuthSession);
      final usecase = LogoutUseCase(auth, sessions, logger);

      await usecase.execute();

      expect(auth.loggedOut, [testAuthSession]);
      expect(sessions.load(), isNull);
    });

    test('still clears locally when the server cannot be reached', () async {
      await sessions.save(testAuthSession);
      auth.failure = const InfrastructureError('offline');
      final usecase = LogoutUseCase(auth, sessions, logger);

      await usecase.execute();

      expect(sessions.load(), isNull);
      expect(logger.messagesAt(LogLevel.warning), isNotEmpty);
    });

    test('is a no-op when nobody is signed in', () async {
      final usecase = LogoutUseCase(auth, sessions, logger);
      await usecase.execute();
      expect(auth.loggedOut, isEmpty);
      expect(sessions.cleared, 0);
    });
  });

  group('RestoreSessionUseCase', () {
    test('returns the stored session', () async {
      await sessions.save(testAuthSession);
      expect(RestoreSessionUseCase(sessions).execute(), testAuthSession);
    });

    test('returns null when nothing is stored', () {
      expect(RestoreSessionUseCase(sessions).execute(), isNull);
    });
  });

  group('GetApiEndpointUseCase', () {
    test('returns the stored endpoint, or null', () async {
      expect(GetApiEndpointUseCase(endpoints).execute(), isNull);
      await endpoints.save(Uri.parse('https://photos.example.com'));
      expect(
        GetApiEndpointUseCase(endpoints).execute(),
        Uri.parse('https://photos.example.com'),
      );
    });
  });
}
