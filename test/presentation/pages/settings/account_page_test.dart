import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/account_profile.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/pages/settings/account_page.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

void main() {
  TestScope scopeWith({bool twoFactorEnabled = false}) {
    return TestScope(
      accountRepository: FakeAccountRepository(
        profile: AccountProfile(
          id: 1,
          email: 'user@example.com',
          twoFactorEnabled: twoFactorEnabled,
        ),
      ),
    );
  }

  Future<void> enterPassword(
    WidgetTester tester,
    String password, {
    String? confirmation,
  }) async {
    await tester.enterText(
      find.widgetWithText(TextField, l10n.accountPasswordNewLabel),
      password,
    );
    await tester.enterText(
      find.widgetWithText(TextField, l10n.accountPasswordConfirmLabel),
      confirmation ?? password,
    );
  }

  testWidgets('names the account the reader is signed in as', (tester) async {
    await pumpInScope(tester, const AccountPage(), scope: scopeWith());

    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('shows the error state with a retry that recovers', (
    tester,
  ) async {
    final scope = TestScope(
      accountRepository: FakeAccountRepository()
        ..failure = const NetworkUnreachableError('server down'),
    );
    await pumpInScope(tester, const AccountPage(), scope: scope);

    // The developer-facing message stays out of the UI.
    expect(find.text('server down'), findsNothing);
    expect(find.text(l10n.commonErrorNetwork), findsOneWidget);

    scope.accountRepository.failure = null;
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pumpAndSettle();

    expect(find.text('user@example.com'), findsOneWidget);
  });

  testWidgets('changes the password and clears what was typed', (tester) async {
    final scope = scopeWith();
    await pumpInScope(tester, const AccountPage(), scope: scope);

    await enterPassword(tester, 'hunter2secret');
    await tester.tap(find.text(l10n.accountPasswordChange));
    await tester.pumpAndSettle();

    expect(scope.accountRepository.passwords.single, 'hunter2secret');
    expect(find.text(l10n.accountPasswordChanged), findsOneWidget);
    // Not left sitting in the fields behind whatever the reader does next.
    expect(find.text('hunter2secret'), findsNothing);
  });

  testWidgets('refuses two entries that do not match', (tester) async {
    final scope = scopeWith();
    await pumpInScope(tester, const AccountPage(), scope: scope);

    await enterPassword(tester, 'hunter2secret', confirmation: 'hunter2secre');
    await tester.tap(find.text(l10n.accountPasswordChange));
    await tester.pumpAndSettle();

    expect(find.text(l10n.accountPasswordMismatch), findsOneWidget);
    // A mistyped password would lock the reader out of every other device.
    expect(scope.accountRepository.passwords, isEmpty);
  });

  testWidgets('refuses a short password before it travels', (tester) async {
    final scope = scopeWith();
    await pumpInScope(tester, const AccountPage(), scope: scope);

    await enterPassword(tester, 'short');
    await tester.tap(find.text(l10n.accountPasswordChange));
    await tester.pumpAndSettle();

    expect(find.text(l10n.accountPasswordTooShort(8)), findsOneWidget);
    expect(scope.accountRepository.passwords, isEmpty);
  });

  testWidgets('reports a failed password change and keeps the entry', (
    tester,
  ) async {
    final scope = scopeWith();
    await pumpInScope(tester, const AccountPage(), scope: scope);

    scope.accountRepository.failure = const NetworkUnreachableError('offline');
    await enterPassword(tester, 'hunter2secret');
    await tester.tap(find.text(l10n.accountPasswordChange));
    await tester.pumpAndSettle();

    expect(find.text(l10n.commonErrorNetwork), findsOneWidget);
    expect(find.text('hunter2secret'), findsNWidgets(2));
  });

  group('two-factor', () {
    testWidgets('registers an authenticator from the sheet', (tester) async {
      final scope = scopeWith();
      await pumpInScope(tester, const AccountPage(), scope: scope);
      expect(find.text(l10n.accountTwoFactorOff), findsOneWidget);

      await tester.tap(find.text(l10n.accountTwoFactorEnable));
      await tester.pumpAndSettle();

      // The setup key is on screen for an authenticator that cannot be
      // opened by URI.
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, l10n.accountTwoFactorCodeLabel),
        '123 456',
      );
      await tester.tap(find.text(l10n.accountTwoFactorConfirm));
      await tester.pumpAndSettle();

      // The spacing an authenticator shows is stripped before it is sent.
      expect(scope.accountRepository.confirmations.single.code, '123456');
      expect(find.text(l10n.accountTwoFactorEnabled), findsOneWidget);
      // Patched from the server's answer — no second read to fail.
      expect(find.text(l10n.accountTwoFactorOn), findsOneWidget);
    });

    testWidgets('hands the otpauth URI to the authenticator app', (
      tester,
    ) async {
      final scope = scopeWith();
      await pumpInScope(tester, const AccountPage(), scope: scope);

      await tester.tap(find.text(l10n.accountTwoFactorEnable));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.accountTwoFactorOpenApp));
      await tester.pumpAndSettle();

      expect(scope.externalLinkLauncher.opened.single.scheme, 'otpauth');
    });

    testWidgets('keeps the sheet open when the code is rejected', (
      tester,
    ) async {
      final scope = scopeWith();
      scope.accountRepository.confirmationFailure = const InfrastructureError(
        'invalid_code',
      );
      await pumpInScope(tester, const AccountPage(), scope: scope);

      await tester.tap(find.text(l10n.accountTwoFactorEnable));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, l10n.accountTwoFactorCodeLabel),
        '000000',
      );
      await tester.tap(find.text(l10n.accountTwoFactorConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.accountTwoFactorInvalidCode), findsOneWidget);
      // Still off: a rejected code registers nothing.
      expect(find.text(l10n.accountTwoFactorSetupTitle), findsOneWidget);
    });

    testWidgets('backing out of the sheet enables nothing', (tester) async {
      final scope = scopeWith();
      await pumpInScope(tester, const AccountPage(), scope: scope);

      await tester.tap(find.text(l10n.accountTwoFactorEnable));
      await tester.pumpAndSettle();
      // Tapping the barrier is how a bottom sheet is dismissed.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(scope.accountRepository.confirmations, isEmpty);
      expect(find.text(l10n.accountTwoFactorOff), findsOneWidget);
    });

    testWidgets('turns the authenticator off after a confirmation', (
      tester,
    ) async {
      final scope = scopeWith(twoFactorEnabled: true);
      await pumpInScope(tester, const AccountPage(), scope: scope);
      expect(find.text(l10n.accountTwoFactorOn), findsOneWidget);

      await tester.tap(find.text(l10n.accountTwoFactorDisable));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.accountTwoFactorDisable),
      );
      await tester.pumpAndSettle();

      expect(scope.accountRepository.disableCount, 1);
      expect(find.text(l10n.accountTwoFactorOff), findsOneWidget);
    });

    testWidgets('cancelling the confirmation leaves it on', (tester) async {
      final scope = scopeWith(twoFactorEnabled: true);
      await pumpInScope(tester, const AccountPage(), scope: scope);

      await tester.tap(find.text(l10n.accountTwoFactorDisable));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonCancel));
      await tester.pumpAndSettle();

      expect(scope.accountRepository.disableCount, 0);
      expect(find.text(l10n.accountTwoFactorOn), findsOneWidget);
    });
  });

  testWidgets('says where passkeys live rather than hiding them', (
    tester,
  ) async {
    await pumpInScope(tester, const AccountPage(), scope: scopeWith());

    expect(find.text(l10n.accountPasskeysUnavailable), findsOneWidget);
  });
}
