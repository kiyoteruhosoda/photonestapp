import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_permission.dart';
import 'package:photonest/presentation/providers/session_providers.dart';

import '../../support/fakes.dart';
import '../../support/test_harness.dart';

void main() {
  test('an unexpected login exception propagates but clears busy', () async {
    final scope = TestScope(sessionRepository: FakeSessionRepository());
    scope.authRepository.unexpectedFailure = Exception('platform blew up');

    await expectLater(
      scope.session.login(
        serverUrl: 'https://photos.example.com',
        email: 'user@example.com',
        password: 'secret',
      ),
      throwsException,
    );

    // The form must come back — a stuck busy flag would disable the login
    // screen behind a permanent spinner until an app restart.
    final state = scope.container.read(sessionProvider);
    expect(state.busy, isFalse);
    expect(state.isAuthenticated, isFalse);
  });

  test('an unexpected logout exception propagates but clears busy', () async {
    final scope = TestScope();
    scope.authRepository.unexpectedFailure = Exception('platform blew up');

    await expectLater(scope.session.logout(), throwsException);

    expect(scope.container.read(sessionProvider).busy, isFalse);
  });

  test('a mapped failure still reports its kind', () async {
    final scope = TestScope(sessionRepository: FakeSessionRepository());
    scope.authRepository.failure = const AuthenticationError('no');

    final ok = await scope.session.login(
      serverUrl: 'https://photos.example.com',
      email: 'user@example.com',
      password: 'wrong',
    );

    expect(ok, isFalse);
    final state = scope.container.read(sessionProvider);
    expect(state.lastFailure, LoginFailure.invalidCredentials);
    expect(state.busy, isFalse);
  });

  test('granted permissions come from the signed-in session', () {
    final scope = TestScope(
      sessionRepository: FakeSessionRepository(restrictedTestAuthSession),
    );

    final granted = scope.container.read(grantedPermissionsProvider);
    expect(granted.allows(MediaPermission.uploadMedia), isFalse);
    expect(granted.allows(MediaPermission.trashMedia), isFalse);
  });

  test('signing out withdraws every permission', () async {
    final scope = TestScope();
    expect(
      scope.container
          .read(grantedPermissionsProvider)
          .allows(MediaPermission.uploadMedia),
      isTrue,
    );

    await scope.session.logout();

    expect(
      scope.container
          .read(grantedPermissionsProvider)
          .allows(MediaPermission.uploadMedia),
      isFalse,
    );
  });
}
