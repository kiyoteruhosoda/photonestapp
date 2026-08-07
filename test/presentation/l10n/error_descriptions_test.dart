import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_ja.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';

void main() {
  const en = AppLocalizationsEn();
  const ja = AppLocalizationsJa();

  test('an authentication error reads as an expired session', () {
    const error = AuthenticationError('Not signed in.');
    expect(describeLoadError(error, en), en.commonErrorSessionExpired);
    expect(describeLoadError(error, ja), ja.commonErrorSessionExpired);
  });

  test('an infrastructure error reads as a connection problem', () {
    const error = InfrastructureError('Could not reach the server: refused');
    expect(describeLoadError(error, en), en.commonErrorNetwork);
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
