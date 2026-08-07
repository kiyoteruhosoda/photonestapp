import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';

void main() {
  group('AppError', () {
    test('is an Exception, so it can cross an async boundary', () {
      final error = DomainError('rule violated'.toString());
      expect(error, isA<Exception>());
      expect(error, isA<AppError>());
    });

    test('exhaustive switch covers every variant', () {
      String describe(AppError error) => switch (error) {
        DomainError() => 'domain',
        InfrastructureError() => 'infrastructure',
        UnexpectedError() => 'unexpected',
      };

      expect(describe(const DomainError('a')), equals('domain'));
      expect(
        describe(const InfrastructureError('b')),
        equals('infrastructure'),
      );
      expect(describe(const UnexpectedError('c')), equals('unexpected'));
    });
  });

  group('DomainError', () {
    test('carries the message it was given', () {
      // Built at runtime, not as a const: a const expression is evaluated by
      // the compiler, so the constructor never runs under the test.
      final error = DomainError('theme is unknown'.toString());
      expect(error.message, 'theme is unknown');
    });
  });

  group('InfrastructureError', () {
    test('cause defaults to null', () {
      expect(InfrastructureError('disk full'.toString()).cause, isNull);
    });

    test('retains the underlying cause when supplied', () {
      final cause = Exception('ENOSPC');
      final error = InfrastructureError('disk full', cause: cause);
      expect(error.message, 'disk full');
      expect(error.cause, same(cause));
    });
  });

  group('UnexpectedError', () {
    test('cause and stackTrace default to null', () {
      final error = UnexpectedError('boom'.toString());
      expect(error.cause, isNull);
      expect(error.stackTrace, isNull);
    });

    test('retains cause and stack trace when supplied', () {
      final cause = StateError('bad state');
      final stackTrace = StackTrace.current;
      final error = UnexpectedError(
        'boom',
        cause: cause,
        stackTrace: stackTrace,
      );
      expect(error.message, 'boom');
      expect(error.cause, same(cause));
      expect(error.stackTrace, same(stackTrace));
    });
  });
}
