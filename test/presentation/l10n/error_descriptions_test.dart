import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/l10n/app_localizations_ja.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';

void main() {
  const en = AppLocalizationsEn();
  const ja = AppLocalizationsJa();

  test('an authentication error reads as an expired session', () {
    const error = AuthenticationError('Not signed in.');
    expect(describeLoadError(error, en), en.commonErrorSessionExpired);
    expect(describeLoadError(error, ja), ja.commonErrorSessionExpired);
  });

  test('a transport failure reads as a connection problem', () {
    const error = NetworkUnreachableError('Could not reach the server');
    expect(describeLoadError(error, en), en.commonErrorNetwork);
    expect(describeLoadError(error, ja), ja.commonErrorNetwork);
  });

  test('a response the server did send stays generic — reconnecting will '
      'not fix it', () {
    const error = InfrastructureError('Server error (HTTP 500).');
    expect(describeLoadError(error, en), en.commonError);
  });

  test('anything else falls back to the generic error', () {
    expect(describeLoadError(StateError('bug'), en), en.commonError);
    expect(describeLoadError(const UnexpectedError('bug'), en), en.commonError);
  });

  test('the developer-facing message never leaks into the description', () {
    const error = InfrastructureError('stack trace and SQL');
    expect(describeLoadError(error, en), isNot(contains('SQL')));
  });
}
