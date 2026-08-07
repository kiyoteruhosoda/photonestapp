import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/auth/login_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

void main() {
  TestScope signedOut({FakeApiEndpointRepository? endpoints}) => TestScope(
    sessionRepository: FakeSessionRepository(),
    apiEndpointRepository: endpoints,
  );

  Future<void> fillForm(WidgetTester tester) async {
    await tester.enterText(
      find.byType(AppTextField).at(0),
      'https://photos.example.com',
    );
    await tester.enterText(find.byType(AppTextField).at(1), 'user@example.com');
    await tester.enterText(find.byType(AppTextField).at(2), 'secret');
  }

  testWidgets('renders the three fields and the submit button', (tester) async {
    await pumpInScope(tester, const LoginPage(), scope: signedOut());

    expect(find.text(l10n.loginServerLabel), findsOneWidget);
    expect(find.text(l10n.loginEmailLabel), findsOneWidget);
    expect(find.text(l10n.loginPasswordLabel), findsOneWidget);
    expect(find.byType(AppPrimaryButton), findsOneWidget);
  });

  testWidgets('prefills the server URL from the last login', (tester) async {
    final scope = signedOut(
      endpoints: FakeApiEndpointRepository(
        Uri.parse('https://photos.example.com'),
      ),
    );
    await pumpInScope(tester, const LoginPage(), scope: scope);

    // The hint renders the same string, so assert on the field's value.
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller?.text, 'https://photos.example.com');
  });

  testWidgets('a successful submit signs the session in', (tester) async {
    final scope = signedOut();
    await pumpInScope(tester, const LoginPage(), scope: scope);

    await fillForm(tester);
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(scope.sessionViewModel.isAuthenticated, isTrue);
    expect(scope.authRepository.logins.single.email, 'user@example.com');
  });

  testWidgets('rejected credentials render the credentials error', (
    tester,
  ) async {
    final scope = signedOut();
    scope.authRepository.failure = const AuthenticationError('no');
    await pumpInScope(tester, const LoginPage(), scope: scope);

    await fillForm(tester);
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginErrorInvalidCredentials), findsOneWidget);
    expect(scope.sessionViewModel.isAuthenticated, isFalse);
  });

  testWidgets('an unreachable server renders the network error', (
    tester,
  ) async {
    final scope = signedOut();
    scope.authRepository.failure = const InfrastructureError('refused');
    await pumpInScope(tester, const LoginPage(), scope: scope);

    await fillForm(tester);
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginErrorNetwork), findsOneWidget);
  });

  testWidgets('a malformed form renders the input error without a call', (
    tester,
  ) async {
    final scope = signedOut();
    await pumpInScope(tester, const LoginPage(), scope: scope);

    await tester.enterText(find.byType(AppTextField).at(0), 'not a url');
    await tester.enterText(find.byType(AppTextField).at(1), 'user');
    await tester.enterText(find.byType(AppTextField).at(2), '');
    await tester.tap(find.byType(AppPrimaryButton));
    await tester.pumpAndSettle();

    expect(find.text(l10n.loginErrorInvalidInput), findsOneWidget);
    expect(scope.authRepository.logins, isEmpty);
  });

  testWidgets('submitting from the password field works too', (tester) async {
    final scope = signedOut();
    await pumpInScope(tester, const LoginPage(), scope: scope);

    await fillForm(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(scope.sessionViewModel.isAuthenticated, isTrue);
  });
}
