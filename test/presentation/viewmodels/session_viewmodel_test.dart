import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/application/usecases/auth/get_api_endpoint_usecase.dart';
import 'package:flutterbase/application/usecases/auth/login_usecase.dart';
import 'package:flutterbase/application/usecases/auth/logout_usecase.dart';
import 'package:flutterbase/application/usecases/auth/restore_session_usecase.dart';
import 'package:flutterbase/application/usecases/auth/watch_session_usecase.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/viewmodels/session_viewmodel.dart';

import '../../support/fakes.dart';
import '../../support/recording_app_logger.dart';

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

  SessionViewModel build() {
    return SessionViewModel(
      LoginUseCase(auth, sessions, endpoints, logger),
      LogoutUseCase(auth, sessions, logger),
      RestoreSessionUseCase(sessions),
      GetApiEndpointUseCase(endpoints),
      WatchSessionUseCase(sessions),
      logger,
    );
  }

  group('construction', () {
    test('starts signed out when nothing is stored', () {
      final viewModel = build();
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.session, isNull);
      expect(viewModel.lastServerUrl, isNull);
    });

    test('restores the stored session and endpoint synchronously', () async {
      await sessions.save(testAuthSession);
      await endpoints.save(Uri.parse('https://photos.example.com'));

      final viewModel = build();

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.session, testAuthSession);
      expect(viewModel.lastServerUrl, Uri.parse('https://photos.example.com'));
    });
  });

  group('login', () {
    test('a successful login stores the session and notifies', () async {
      final viewModel = build();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final ok = await viewModel.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'secret',
      );

      expect(ok, isTrue);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.lastFailure, isNull);
      expect(viewModel.busy, isFalse);
      expect(viewModel.lastServerUrl, Uri.parse('https://photos.example.com'));
      // Once entering busy, once leaving it.
      expect(notifications, greaterThanOrEqualTo(2));
    });

    test(
      'malformed input becomes invalidInput without a network call', //
      () async {
        final viewModel = build();

        final ok = await viewModel.login(
          serverUrl: 'not a url',
          email: 'user@example.com',
          password: 'secret',
        );

        expect(ok, isFalse);
        expect(viewModel.lastFailure, LoginFailure.invalidInput);
        expect(auth.logins, isEmpty);
      },
    );

    test('rejected credentials become invalidCredentials', () async {
      auth.failure = const AuthenticationError(
        'no',
        code: 'invalid_credentials',
      );
      final viewModel = build();

      final ok = await viewModel.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'wrong',
      );

      expect(ok, isFalse);
      expect(viewModel.lastFailure, LoginFailure.invalidCredentials);
      expect(viewModel.isAuthenticated, isFalse);
    });

    test('an unreachable server becomes network', () async {
      auth.failure = const InfrastructureError('refused');
      final viewModel = build();

      final ok = await viewModel.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'secret',
      );

      expect(ok, isFalse);
      expect(viewModel.lastFailure, LoginFailure.network);
    });

    test('a new attempt clears the previous failure', () async {
      auth.failure = const InfrastructureError('refused');
      final viewModel = build();
      await viewModel.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'secret',
      );
      expect(viewModel.lastFailure, LoginFailure.network);

      auth.failure = null;
      final ok = await viewModel.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'secret',
      );
      expect(ok, isTrue);
      expect(viewModel.lastFailure, isNull);
    });
  });

  group('store-driven changes', () {
    test(
      'an externally cleared session flips the app to signed out', //
      () async {
        await sessions.save(testAuthSession);
        final viewModel = build();
        expect(viewModel.isAuthenticated, isTrue);
        var notifications = 0;
        viewModel.addListener(() => notifications++);

        // What the API client does when a refresh is rejected.
        await sessions.clear();
        await pumpEventQueue();

        expect(viewModel.isAuthenticated, isFalse);
        expect(notifications, 1);
      },
    );

    test(
      'a rotated token pair is mirrored without a spurious sign-out', //
      () async {
        await sessions.save(testAuthSession);
        final viewModel = build();

        final rotated = testAuthSession.withTokens(
          accessToken: 'access-2',
          refreshToken: 'refresh-2',
        );
        await sessions.save(rotated);
        await pumpEventQueue();

        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.session, rotated);
      },
    );

    test('dispose stops mirroring the store', () async {
      await sessions.save(testAuthSession);
      build().dispose();
      await sessions.clear();
      await pumpEventQueue();
      // No crash from notifying a disposed ChangeNotifier is the assertion.
      expect(sessions.load(), isNull);
    });
  });

  group('logout', () {
    test('clears the session and notifies', () async {
      await sessions.save(testAuthSession);
      final viewModel = build();
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      await viewModel.logout();

      expect(viewModel.isAuthenticated, isFalse);
      expect(sessions.load(), isNull);
      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
