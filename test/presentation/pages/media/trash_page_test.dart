import 'package:flutter_test/flutter_test.dart';
import 'package:photonest/domain/errors/app_error.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/l10n/app_localizations_en.dart';
import 'package:photonest/presentation/pages/media/trash_page.dart';
import 'package:photonest/presentation/widgets/ui/widgets.dart';

import '../../../support/fakes.dart';
import '../../../support/test_harness.dart';

const AppLocalizationsEn l10n = AppLocalizationsEn();

void main() {
  group('TrashPage', () {
    testWidgets('an empty trash says so', (tester) async {
      await pumpInScope(tester, const TrashPage());
      await tester.pumpAndSettle();

      expect(find.text(l10n.trashEmpty), findsOneWidget);
    });

    testWidgets('lists what is in the trash with a way back', (tester) async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository()
          ..trashed = [
            testMediaItem(id: 9, filename: 'gone.jpg'),
            testMediaItem(id: 10, filename: 'also_gone.jpg'),
          ],
      );
      await pumpInScope(tester, const TrashPage(), scope: scope);
      await tester.pumpAndSettle();

      expect(find.text('gone.jpg'), findsOneWidget);
      expect(find.text(l10n.trashRestore), findsNWidgets(2));
    });

    testWidgets('restoring removes the row and says so', (tester) async {
      final curation = FakeMediaCurationRepository();
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository()
          ..trashed = [testMediaItem(id: 9, filename: 'gone.jpg')],
        mediaCurationRepository: curation,
      );
      await pumpInScope(tester, const TrashPage(), scope: scope);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.trashRestore));
      await tester.pumpAndSettle();

      expect(curation.restored, [MediaId(9)]);
      expect(find.text('gone.jpg'), findsNothing);
      expect(find.text(l10n.trashRestored), findsOneWidget);
      expect(find.text(l10n.trashEmpty), findsOneWidget);
    });

    testWidgets('a failed restore keeps the row and says why', (tester) async {
      final scope = TestScope(
        mediaLibraryRepository: FakeMediaLibraryRepository()
          ..trashed = [testMediaItem(id: 9, filename: 'gone.jpg')],
        mediaCurationRepository: FakeMediaCurationRepository()
          ..failure = const InfrastructureError('already purged'),
      );
      await pumpInScope(tester, const TrashPage(), scope: scope);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.trashRestore));
      await tester.pumpAndSettle();

      expect(find.text(l10n.trashRestoreFailed), findsOneWidget);
      // Still listed, so the reader can try again.
      expect(find.text('gone.jpg'), findsOneWidget);
    });

    testWidgets('a failed read offers a retry', (tester) async {
      final repository = FakeMediaLibraryRepository()
        ..failure = const NetworkUnreachableError('offline');
      final scope = TestScope(mediaLibraryRepository: repository);
      await pumpInScope(tester, const TrashPage(), scope: scope);
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);

      repository.failure = null;
      repository.trashed = [testMediaItem(id: 9, filename: 'gone.jpg')];
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(find.text('gone.jpg'), findsOneWidget);
    });
  });
}
