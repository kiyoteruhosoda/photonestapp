import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

void main() {
  /// Pumps a screen whose only job is to open the create form, and reports
  /// what it returned.
  Future<(TestScope, List<Album?>)> openCreateForm(
    WidgetTester tester, {
    TestScope? scope,
    List<MediaId> holding = const <MediaId>[],
  }) async {
    final used = scope ?? TestScope();
    final results = <Album?>[];
    await pumpInScope(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showAlbumCreateForm(context, holding: holding),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      scope: used,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (used, results);
  }

  testWidgets('creates the album the reader named', (tester) async {
    final (scope, results) = await openCreateForm(tester);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.albumNameLabel),
      'Kyoto',
    );
    await tester.tap(find.text(l10n.albumCreateAction));
    await tester.pumpAndSettle();

    expect(scope.albumEditingRepository.created.single.title, 'Kyoto');
    // The dialog hands the album back, so whoever opened it can say what
    // happened without reading the list again.
    expect(results.single?.title, 'Kyoto');
  });

  testWidgets('files the media it was opened with into the new album', (
    tester,
  ) async {
    final (scope, _) = await openCreateForm(
      tester,
      holding: <MediaId>[MediaId(9)],
    );

    await tester.enterText(
      find.widgetWithText(TextField, l10n.albumNameLabel),
      'Kyoto',
    );
    await tester.tap(find.text(l10n.albumCreateAction));
    await tester.pumpAndSettle();

    expect(scope.albumEditingRepository.created.single.mediaIds, [MediaId(9)]);
  });

  testWidgets('refuses a blank name and stays open', (tester) async {
    final (scope, _) = await openCreateForm(tester);

    await tester.tap(find.text(l10n.albumCreateAction));
    await tester.pumpAndSettle();

    expect(find.text(l10n.albumNameRequired), findsOneWidget);
    expect(scope.albumEditingRepository.created, isEmpty);
    // Still on screen: a rejected name is a correction, not a dismissal.
    expect(find.text(l10n.albumCreateTitle), findsOneWidget);
  });

  testWidgets('a failed save keeps what the reader typed', (tester) async {
    final scope = TestScope(
      albumEditingRepository: FakeAlbumEditingRepository()
        ..failure = const NetworkUnreachableError('offline'),
    );
    await openCreateForm(tester, scope: scope);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.albumNameLabel),
      'Kyoto',
    );
    await tester.tap(find.text(l10n.albumCreateAction));
    await tester.pumpAndSettle();

    expect(find.text(l10n.albumSaveFailed), findsOneWidget);
    expect(find.text('Kyoto'), findsOneWidget);
  });

  testWidgets('the edit form starts from the album it was given', (
    tester,
  ) async {
    final scope = TestScope();
    await pumpInScope(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAlbumEditForm(context, testAlbum(id: 4, title: 'Trip')),
            child: const Text('open'),
          ),
        ),
      ),
      scope: scope,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Trip'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, l10n.albumNameLabel),
      'Kyoto',
    );
    await tester.tap(find.text(l10n.albumRenameAction));
    await tester.pumpAndSettle();

    final updated = scope.albumEditingRepository.updated.single;
    expect(updated.title, 'Kyoto');
    // A rename must not touch the album's contents.
    expect(scope.albumEditingRepository.replaced, isEmpty);
  });
}
