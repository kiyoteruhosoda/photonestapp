import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/login_credentials.dart';

void main() {
  LoginCredentials build({
    String serverUrl = 'https://photos.example.com',
    String email = 'user@example.com',
    String password = 'secret',
  }) {
    return LoginCredentials(
      serverUrl: Uri.parse(serverUrl),
      email: email,
      password: password,
    );
  }

  group('LoginCredentials', () {
    test('accepts a well-formed submission and trims the e-mail', () {
      final credentials = build(email: '  user@example.com  ');
      expect(credentials.email, 'user@example.com');
      expect(credentials.serverUrl, Uri.parse('https://photos.example.com'));
      expect(credentials.password, 'secret');
    });

    test('accepts plain http for development servers', () {
      expect(build(serverUrl: 'http://192.168.1.10:8000'), isNotNull);
    });

    test('rejects a server URL that is not http(s)', () {
      expect(
        () => build(serverUrl: 'ftp://photos.example.com'),
        throwsA(isA<DomainError>()),
      );
      expect(() => build(serverUrl: 'photos'), throwsA(isA<DomainError>()));
    });

    test('rejects a server URL without a host', () {
      expect(() => build(serverUrl: 'https://'), throwsA(isA<DomainError>()));
    });

    test('rejects an e-mail without a local part or host', () {
      expect(() => build(email: 'no-at-sign'), throwsA(isA<DomainError>()));
      expect(() => build(email: '@host.com'), throwsA(isA<DomainError>()));
      expect(() => build(email: 'user@'), throwsA(isA<DomainError>()));
    });

    test('rejects an empty password', () {
      expect(() => build(password: ''), throwsA(isA<DomainError>()));
    });

    test('equality is field-by-field', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(password: 'other')));
    });

    test('toString never contains the password', () {
      expect(build(password: 'hunter2').toString(), isNot(contains('hunter2')));
    });
  });
}
