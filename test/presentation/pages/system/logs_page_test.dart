import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/domain/value_objects/log_level.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/pages/system/logs_page.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/recording_app_logger.dart';
import '../../../support/test_harness.dart';

const l10n = AppLocalizationsEn();

/// A scope whose logger holds exactly one entry per level.
///
/// The entries are written *after* the scope is built, because constructing
/// the ViewModels logs their initial state.
TestScope scopeWithEntries() {
  final logger = RecordingAppLogger();
  final scope = TestScope(logger: logger);
  logger
    ..reset()
    ..verbose('verbose entry')
    ..debug('debug entry')
    ..info('info entry')
    ..warning('warning entry')
    ..error('error entry', error: Exception('boom'));
  return scope;
}

/// A scope whose log buffer is genuinely empty.
TestScope scopeWithoutEntries() {
  final logger = RecordingAppLogger();
  final scope = TestScope(logger: logger);
  logger.reset();
  return scope;
}

void main() {
  group('LogsPage — empty', () {
    testWidgets('shows the empty state when nothing has been logged', (
      tester,
    ) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithoutEntries());
      expect(find.byType(AppEmptyView), findsOneWidget);
      expect(find.text(l10n.logsEmpty), findsOneWidget);
    });
  });

  group('LogsPage — entries', () {
    testWidgets('lists every buffered entry, newest first', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      expect(find.text('verbose entry'), findsOneWidget);
      expect(find.text('error entry'), findsOneWidget);

      final errorY = tester.getTopLeft(find.text('error entry')).dy;
      final verboseY = tester.getTopLeft(find.text('verbose entry')).dy;
      expect(errorY, lessThan(verboseY));
    });

    testWidgets('renders the level badge for each entry', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      for (final label in ['V', 'D', 'I', 'W', 'E']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('shows the error object beneath its message', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      expect(find.text('Exception: boom'), findsOneWidget);
    });
  });

  group('LogsPage — filtering', () {
    testWidgets('starts on the All filter', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, l10n.logsAll),
      );
      expect(chip.selected, isTrue);
    });

    testWidgets('filtering by error hides the other levels', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      await tester.tap(find.widgetWithText(FilterChip, l10n.logsError));
      await tester.pumpAndSettle();

      expect(find.text('error entry'), findsOneWidget);
      expect(find.text('info entry'), findsNothing);
      expect(find.text('debug entry'), findsNothing);
    });

    testWidgets('every level filter is reachable', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      final filters = <(String, String)>[
        (l10n.logsVerbose, 'verbose entry'),
        (l10n.logsDebug, 'debug entry'),
        (l10n.logsInfo, 'info entry'),
        (l10n.logsWarning, 'warning entry'),
      ];
      for (final (label, message) in filters) {
        await tester.tap(find.widgetWithText(FilterChip, label));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget, reason: 'filter $label');
      }
    });

    testWidgets('returning to All restores every entry', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      await tester.tap(find.widgetWithText(FilterChip, l10n.logsError));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, l10n.logsAll));
      await tester.pumpAndSettle();
      expect(find.text('info entry'), findsOneWidget);
    });

    testWidgets('a filter with no matches shows the empty state', (
      tester,
    ) async {
      final scope = scopeWithoutEntries();
      scope.logger.info('only info');
      await pumpInScope(tester, const LogsPage(), scope: scope);
      await tester.tap(find.widgetWithText(FilterChip, l10n.logsError));
      await tester.pumpAndSettle();
      expect(find.byType(AppEmptyView), findsOneWidget);
    });
  });

  group('LogsPage — export', () {
    testWidgets('reports success when the logger produced a file', (
      tester,
    ) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logsDownloadSuccess), findsOneWidget);
    });

    testWidgets('reports failure when the logger could not write', (
      tester,
    ) async {
      final scope = scopeWithoutEntries();
      scope.logger
        ..info('entry')
        ..exportFails = true;
      await pumpInScope(tester, const LogsPage(), scope: scope);
      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pumpAndSettle();
      expect(find.text(l10n.logsDownloadError), findsOneWidget);
    });
  });

  group('LogsPage — clearing', () {
    testWidgets('asks for confirmation before clearing', (tester) async {
      final scope = scopeWithEntries();
      await pumpInScope(tester, const LogsPage(), scope: scope);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text(l10n.logsClearConfirmTitle), findsOneWidget);
      expect(scope.logger.clearBufferCalls, 0);
    });

    testWidgets('cancelling leaves the buffer alone', (tester) async {
      final scope = scopeWithEntries();
      await pumpInScope(tester, const LogsPage(), scope: scope);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.logsCancel));
      await tester.pumpAndSettle();

      expect(scope.logger.clearBufferCalls, 0);
      expect(find.text('info entry'), findsOneWidget);
    });

    testWidgets('confirming clears the buffer and shows the empty state', (
      tester,
    ) async {
      final scope = scopeWithEntries();
      await pumpInScope(tester, const LogsPage(), scope: scope);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.logsConfirm));
      await tester.pumpAndSettle();

      expect(scope.logger.clearBufferCalls, 1);
      expect(find.text(l10n.logsClearSuccess), findsOneWidget);
      expect(find.byType(AppEmptyView), findsOneWidget);
    });
  });

  group('LogsPage — copy', () {
    testWidgets('long-pressing an entry copies its log line', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      await tester.longPress(find.text('info entry'));
      await tester.pumpAndSettle();

      expect(copied, contains('info entry'));
      expect(copied, contains('[I]'));
      expect(find.text(l10n.logsCopied), findsOneWidget);
    });
  });

  group('LogsPage — level colours', () {
    testWidgets('each level renders with a distinct badge', (tester) async {
      await pumpInScope(tester, const LogsPage(), scope: scopeWithEntries());
      for (final level in LogLevel.values) {
        final label = switch (level) {
          LogLevel.verbose => 'V',
          LogLevel.debug => 'D',
          LogLevel.info => 'I',
          LogLevel.warning => 'W',
          LogLevel.error => 'E',
        };
        expect(find.text(label), findsOneWidget);
      }
    });
  });
}
