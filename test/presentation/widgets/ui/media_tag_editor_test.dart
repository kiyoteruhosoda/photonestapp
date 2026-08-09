import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/widgets/ui/media_tag_editor.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

/// A page whose only job is to open the editor, the way the media viewer
/// does.
///
/// The editor is a modal bottom sheet in the app, so it is exercised through
/// [showMediaTagEditor] rather than pumped as a page: the sheet is what
/// supplies the Material its chips draw on, and saving closes it — which has
/// nothing to close when the editor *is* the page.
class _EditorHost extends StatefulWidget {
  const _EditorHost();

  @override
  State<_EditorHost> createState() => _EditorHostState();
}

class _EditorHostState extends State<_EditorHost> {
  /// What the sheet handed back, once it has closed.
  List<Tag>? result;

  /// True once the sheet has closed, whatever it returned.
  bool closed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final settled = await showMediaTagEditor(context, id: MediaId(10));
            if (!mounted) return;
            setState(() {
              result = settled;
              closed = true;
            });
          },
          child: const Text('open'),
        ),
      ),
    );
  }
}

void main() {
  /// A library with three tags, one of which is already on media 10.
  FakeMediaTagRepository seededTags() {
    final kyoto = testTag(id: 1, name: 'Kyoto', attribute: TagAttribute.place);
    return FakeMediaTagRepository()
      ..library = [
        kyoto,
        testTag(id: 2, name: 'Hanabi', attribute: TagAttribute.event),
        testTag(id: 3, name: 'Osaka', attribute: TagAttribute.place),
      ]
      ..byMedia[10] = [kyoto];
  }

  Future<_EditorHostState> openEditor(
    WidgetTester tester, {
    FakeMediaTagRepository? tags,
  }) async {
    await pumpInScope(
      tester,
      const _EditorHost(),
      scope: TestScope(mediaTagRepository: tags ?? seededTags()),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return tester.state<_EditorHostState>(find.byType(_EditorHost));
  }

  group('MediaTagEditor', () {
    testWidgets('shows the tags already on the media', (tester) async {
      await openEditor(tester);

      expect(find.widgetWithText(InputChip, 'Kyoto'), findsOneWidget);
      expect(find.text(l10n.mediaTagsNoneOnMedia), findsNothing);
    });

    testWidgets('an untagged item says so rather than looking broken', (
      tester,
    ) async {
      await openEditor(tester, tags: FakeMediaTagRepository());

      expect(find.text(l10n.mediaTagsNoneOnMedia), findsOneWidget);
      expect(find.text(l10n.mediaTagsNoMatches), findsOneWidget);
    });

    testWidgets('the picker ticks the tags the media already carries', (
      tester,
    ) async {
      await openEditor(tester);

      final ticked = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .where((tile) => tile.value ?? false);
      expect(ticked, hasLength(1));
      expect(find.text(l10n.tagAttributePlace), findsNWidgets(2));
    });

    testWidgets('nothing is sent until the reader saves', (tester) async {
      final tags = seededTags();
      await openEditor(tester, tags: tags);

      await tester.tap(find.text('Hanabi'));
      await tester.pumpAndSettle();

      // Choosing several tags is one request, and closing without saving
      // must leave the media exactly as it was.
      expect(tags.replacements, isEmpty);
      expect(find.widgetWithText(InputChip, 'Hanabi'), findsOneWidget);
    });

    testWidgets('saving sends the whole chosen set once and closes', (
      tester,
    ) async {
      final tags = seededTags();
      final host = await openEditor(tester, tags: tags);

      await tester.tap(find.text('Hanabi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.mediaTagsSave));
      await tester.pumpAndSettle();

      expect(tags.replacements.single.$1, MediaId(10));
      expect(tags.replacements.single.$2.map((id) => id.value), [1, 2]);
      expect(find.byType(MediaTagEditor), findsNothing);
      expect(host.result?.map((tag) => tag.id.value), [1, 2]);
    });

    testWidgets('closing without saving reports no change', (tester) async {
      final tags = seededTags();
      final host = await openEditor(tester, tags: tags);

      // Tapping the barrier is how a reader dismisses a bottom sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(tags.replacements, isEmpty);
      expect(host.closed, isTrue);
      expect(host.result, isNull);
    });

    testWidgets('removing a chosen tag drops it from the saved set', (
      tester,
    ) async {
      final tags = seededTags();
      await openEditor(tester, tags: tags);

      // The chip's only icon is its delete affordance.
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Kyoto'),
          matching: find.byType(Icon),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.mediaTagsSave));
      await tester.pumpAndSettle();

      expect(tags.replacements.single.$2, isEmpty);
    });

    testWidgets('typing narrows the picker after the debounce', (tester) async {
      final tags = seededTags();
      await openEditor(tester, tags: tags);

      await tester.enterText(find.byType(TextField), 'osa');
      await tester.pump(tagSearchDebounce);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CheckboxListTile, 'Osaka'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Kyoto'), findsNothing);
      // One request for the initial list and one for the narrowed one — not
      // one per keystroke.
      expect(tags.suggestQueries.map((query) => query.$1), ['', 'osa']);
    });

    testWidgets('a failure to read the current tags is shown, not hidden', (
      tester,
    ) async {
      await openEditor(
        tester,
        tags: FakeMediaTagRepository()
          ..failure = const NetworkUnreachableError('offline'),
      );

      expect(find.text(l10n.commonErrorNetwork), findsOneWidget);
      expect(find.text(l10n.mediaTagsSave), findsNothing);
    });

    testWidgets('a failed save keeps the sheet open and reports it', (
      tester,
    ) async {
      final tags = seededTags();
      await openEditor(tester, tags: tags);

      tags.failure = const NetworkUnreachableError('offline');
      await tester.tap(find.text(l10n.mediaTagsSave));
      await tester.pumpAndSettle();

      expect(find.text(l10n.commonErrorNetwork), findsOneWidget);
      // Still editable: the reader can retry without re-choosing.
      expect(find.byType(MediaTagEditor), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Kyoto'), findsOneWidget);
    });
  });
}
