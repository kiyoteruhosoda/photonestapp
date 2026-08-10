import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/application/usecases/auth/manage_account_usecase.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/log_level.dart';

import '../../../support/fakes.dart';
import '../../../support/recording_app_logger.dart';

void main() {
  late FakeAccountRepository repository;
  late RecordingAppLogger logger;

  setUp(() {
    repository = FakeAccountRepository();
    logger = RecordingAppLogger();
  });

  ManageAccountUseCase usecase() => ManageAccountUseCase(repository, logger);

  group('changePassword', () {
    test('sends what the reader typed, whitespace and all', () async {
      // Sign-in does not trim either, so a password stripped here could not
      // be typed back in.
      await usecase().changePassword('  hunter2secret  ');

      expect(repository.passwords.single, '  hunter2secret  ');
    });

    test('refuses a short password without asking the server', () async {
      await expectLater(
        usecase().changePassword('short'),
        throwsA(isA<DomainError>()),
      );

      expect(repository.passwords, isEmpty);
    });

    test('never writes the password into the log', () async {
      await usecase().changePassword('hunter2secret');

      final logged = logger.messagesAt(LogLevel.info);
      expect(logged, isNotEmpty);
      for (final message in logged) {
        expect(message, isNot(contains('hunter2secret')));
      }
    });
  });

  group('confirmTwoFactor', () {
    test('strips the spacing an authenticator shows the code with', () async {
      await usecase().confirmTwoFactor(secret: 'SECRET', code: '123 456');

      expect(repository.confirmations.single.code, '123456');
    });

    test('refuses an empty code without asking the server', () async {
      await expectLater(
        usecase().confirmTwoFactor(secret: 'SECRET', code: '   '),
        throwsA(isA<DomainError>()),
      );

      expect(repository.confirmations, isEmpty);
    });

    test('lets a rejected code surface', () async {
      repository.confirmationFailure = const InfrastructureError(
        'invalid_code',
      );

      await expectLater(
        usecase().confirmTwoFactor(secret: 'SECRET', code: '000000'),
        throwsA(isA<InfrastructureError>()),
      );
    });
  });

  test('beginTwoFactorEnrollment changes nothing on its own', () async {
    await usecase().beginTwoFactorEnrollment();

    // Enrollment is not registration: the secret only takes effect once the
    // code proves it arrived.
    expect(repository.confirmations, isEmpty);
    expect(repository.profile.twoFactorEnabled, isFalse);
  });

  test('disableTwoFactor removes the authenticator', () async {
    repository.profile = repository.profile.withTwoFactor(enabled: true);

    await usecase().disableTwoFactor();

    expect(repository.disableCount, 1);
    expect(repository.profile.twoFactorEnabled, isFalse);
  });
}
