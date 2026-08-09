import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/auth_session.dart';
import 'package:photonest/domain/errors/app_error.dart';

void main() {
  AuthSession build({
    String accessToken = 'access',
    String refreshToken = 'refresh',
    String email = 'user@example.com',
    List<String> scopes = const ['gui:view', 'album:view'],
  }) {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      email: email,
      scopes: scopes,
    );
  }

  group('AuthSession', () {
    test('rejects blank tokens', () {
      expect(() => build(accessToken: '  '), throwsA(isA<DomainError>()));
      expect(() => build(refreshToken: ''), throwsA(isA<DomainError>()));
    });

    test('hasScope answers from the granted scopes', () {
      final session = build();
      expect(session.hasScope('album:view'), isTrue);
      expect(session.hasScope('system:manage'), isFalse);
    });

    test('scopes cannot be mutated from outside', () {
      expect(() => build().scopes.add('x'), throwsUnsupportedError);
    });

    test('withTokens keeps the identity and swaps the token pair', () {
      final refreshed = build().withTokens(
        accessToken: 'access-2',
        refreshToken: 'refresh-2',
      );
      expect(refreshed.accessToken, 'access-2');
      expect(refreshed.refreshToken, 'refresh-2');
      expect(refreshed.email, 'user@example.com');
      expect(refreshed.scopes, ['gui:view', 'album:view']);
    });

    test('withTokens can replace the scopes when the server re-grants', () {
      final refreshed = build().withTokens(
        accessToken: 'a2',
        refreshToken: 'r2',
        scopes: const ['gui:view'],
      );
      expect(refreshed.scopes, ['gui:view']);
    });

    test('equality is by token pair and identity', () {
      expect(build(), build());
      expect(build(), isNot(build(accessToken: 'other')));
    });

    test('toString never contains the tokens', () {
      final printed = build(
        accessToken: 'secret-access',
        refreshToken: 'secret-refresh',
      ).toString();
      expect(printed, isNot(contains('secret-access')));
      expect(printed, isNot(contains('secret-refresh')));
    });
  });
}
