import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterbase/presentation/l10n/app_localizations_en.dart';
import 'package:flutterbase/presentation/theme/app_theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

import '../../../support/test_harness.dart';

void main() {
  group('AppCard', () {
    testWidgets('renders its child', (tester) async {
      await pumpComponent(tester, const AppCard(child: Text('content')));
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('is not tappable when no handler is given', (tester) async {
      await pumpComponent(tester, const AppCard(child: Text('content')));
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        AppCard(onTap: () => taps++, child: const Text('content')),
      );
      await tester.tap(find.text('content'));
      expect(taps, 1);
    });

    testWidgets('exposes its semantic label', (tester) async {
      await pumpComponent(
        tester,
        const AppCard(semanticLabel: 'summary', child: Text('content')),
      );
      expect(find.bySemanticsLabel(RegExp('summary')), findsAtLeastNWidgets(1));
    });

    testWidgets('honours a custom padding', (tester) async {
      await pumpComponent(
        tester,
        const AppCard(padding: EdgeInsets.zero, child: Text('content')),
      );
      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Padding),
            )
            .first,
      );
      expect(padding.padding, EdgeInsets.zero);
    });
  });

  group('AppListCard', () {
    testWidgets('renders title, subtitle and leading widget', (tester) async {
      await pumpComponent(
        tester,
        const AppListCard(
          title: 'Title',
          subtitle: 'Subtitle',
          leading: Icon(Icons.article_outlined),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Subtitle'), findsOneWidget);
      expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    });

    testWidgets('omits the subtitle when none is given', (tester) async {
      await pumpComponent(tester, const AppListCard(title: 'Title'));
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.subtitle, isNull);
    });

    testWidgets('shows a chevron only when tappable', (tester) async {
      await pumpComponent(tester, const AppListCard(title: 'Title'));
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await pumpComponent(tester, AppListCard(title: 'Title', onTap: () {}));
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('a custom trailing widget wins over the chevron', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        AppListCard(
          title: 'Title',
          trailing: const Icon(Icons.star),
          onTap: () {},
        ),
      );
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('invokes onTap', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        AppListCard(title: 'Title', onTap: () => taps++),
      );
      await tester.tap(find.text('Title'));
      expect(taps, 1);
    });
  });

  group('AppMainHeader', () {
    testWidgets('renders the title, leading widget and actions', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        const Scaffold(
          appBar: AppMainHeader(
            title: 'Header',
            leading: Icon(Icons.menu),
            actions: [Icon(Icons.notifications_outlined)],
          ),
        ),
      );
      expect(find.text('Header'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('preferredSize is the toolbar height without a bottom', (
      tester,
    ) async {
      const header = AppMainHeader(title: 'Header');
      expect(header.preferredSize.height, kToolbarHeight);
    });

    testWidgets('preferredSize grows to fit a bottom widget', (tester) async {
      const bottom = TabBar(
        tabs: [
          Tab(text: 'a'),
          Tab(text: 'b'),
        ],
      );
      const header = AppMainHeader(title: 'Header', bottom: bottom);
      expect(
        header.preferredSize.height,
        kToolbarHeight + bottom.preferredSize.height,
      );
    });
  });

  group('AppSectionHeader', () {
    testWidgets('renders the title only by default', (tester) async {
      await pumpComponent(tester, const AppSectionHeader(title: 'Section'));
      expect(find.text('Section'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('renders a subtitle when given', (tester) async {
      await pumpComponent(
        tester,
        const AppSectionHeader(title: 'Section', subtitle: 'Detail'),
      );
      expect(find.text('Detail'), findsOneWidget);
    });

    testWidgets('shows the action only when both label and handler are set', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        AppSectionHeader(title: 'Section', action: () {}),
      );
      expect(find.byType(TextButton), findsNothing);

      var taps = 0;
      await pumpComponent(
        tester,
        AppSectionHeader(
          title: 'Section',
          action: () => taps++,
          actionLabel: 'More',
        ),
      );
      await tester.tap(find.text('More'));
      expect(taps, 1);
    });
  });

  group('AppPrimaryButton', () {
    testWidgets('renders its label and fires onPressed', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        AppPrimaryButton(label: 'Submit', onPressed: () => taps++),
      );
      await tester.tap(find.text('Submit'));
      expect(taps, 1);
    });

    testWidgets('renders an icon beside the label', (tester) async {
      await pumpComponent(
        tester,
        AppPrimaryButton(label: 'Submit', icon: Icons.send, onPressed: () {}),
      );
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
    });

    testWidgets('while loading shows a spinner and blocks presses', (
      tester,
    ) async {
      var taps = 0;
      await pumpComponent(
        tester,
        AppPrimaryButton(
          label: 'Submit',
          isLoading: true,
          onPressed: () => taps++,
        ),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(taps, 0);
    });

    testWidgets('a null handler leaves the button disabled', (tester) async {
      await pumpComponent(
        tester,
        const AppPrimaryButton(label: 'Submit', onPressed: null),
      );
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
    });

    testWidgets('honours an explicit width', (tester) async {
      await pumpComponent(
        tester,
        AppPrimaryButton(label: 'Submit', width: 200, onPressed: () {}),
      );
      final box = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(ElevatedButton),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(box.width, 200);
    });
  });

  group('AppSecondaryButton', () {
    testWidgets('renders its label and fires onPressed', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        AppSecondaryButton(label: 'Cancel', onPressed: () => taps++),
      );
      await tester.tap(find.text('Cancel'));
      expect(taps, 1);
    });

    testWidgets('renders an icon beside the label', (tester) async {
      await pumpComponent(
        tester,
        AppSecondaryButton(
          label: 'Cancel',
          icon: Icons.close,
          onPressed: () {},
        ),
      );
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('while loading shows a spinner and blocks presses', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        AppSecondaryButton(label: 'Cancel', isLoading: true, onPressed: () {}),
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
    });
  });

  group('AppTextField', () {
    testWidgets('renders label, hint and helper text', (tester) async {
      await pumpComponent(
        tester,
        const AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          helperText: 'We never share this',
        ),
      );
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('you@example.com'), findsOneWidget);
      expect(find.text('We never share this'), findsOneWidget);
    });

    testWidgets('surfaces an error message', (tester) async {
      await pumpComponent(
        tester,
        const AppTextField(label: 'Email', errorText: 'Required'),
      );
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('reports every keystroke through onChanged', (tester) async {
      final changes = <String>[];
      await pumpComponent(
        tester,
        AppTextField(label: 'Email', onChanged: changes.add),
      );
      await tester.enterText(find.byType(TextField), 'hello');
      expect(changes, equals(['hello']));
    });

    testWidgets('reports submission through onSubmitted', (tester) async {
      String? submitted;
      await pumpComponent(
        tester,
        AppTextField(label: 'Email', onSubmitted: (v) => submitted = v),
      );
      await tester.enterText(find.byType(TextField), 'done');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submitted, 'done');
    });

    testWidgets('a controller keeps the field in sync', (tester) async {
      final controller = TextEditingController(text: 'preset');
      addTearDown(controller.dispose);
      await pumpComponent(tester, AppTextField(controller: controller));
      expect(find.text('preset'), findsOneWidget);
    });

    testWidgets('disabled fields reject input', (tester) async {
      await pumpComponent(tester, const AppTextField(enabled: false));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('renders prefix and suffix icons', (tester) async {
      await pumpComponent(
        tester,
        const AppTextField(
          prefixIcon: Icon(Icons.search),
          suffixIcon: Icon(Icons.clear),
        ),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('obscures text when asked', (tester) async {
      await pumpComponent(tester, const AppTextField(obscureText: true));
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        isTrue,
      );
    });
  });

  group('AppLoadingView', () {
    testWidgets('shows a spinner', (tester) async {
      await pumpComponent(tester, const AppLoadingView(), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows an optional message', (tester) async {
      await pumpComponent(
        tester,
        const AppLoadingView(message: 'Loading…'),
        settle: false,
      );
      expect(find.text('Loading…'), findsOneWidget);
    });
  });

  group('AppErrorView', () {
    testWidgets('shows the message and an error icon', (tester) async {
      await pumpComponent(tester, const AppErrorView(message: 'Went wrong'));
      expect(find.text('Went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('hides the retry button when no handler is given', (
      tester,
    ) async {
      await pumpComponent(tester, const AppErrorView(message: 'Went wrong'));
      expect(find.byType(AppPrimaryButton), findsNothing);
    });

    testWidgets('retry uses the localised default label', (tester) async {
      var retries = 0;
      await pumpComponent(
        tester,
        AppErrorView(message: 'Went wrong', onRetry: () => retries++),
      );
      const l10n = AppLocalizationsEn();
      await tester.tap(find.text(l10n.commonRetry));
      expect(retries, 1);
    });

    testWidgets('retry accepts a custom label', (tester) async {
      await pumpComponent(
        tester,
        AppErrorView(
          message: 'Went wrong',
          retryLabel: 'Try again',
          onRetry: () {},
        ),
      );
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('AppEmptyView', () {
    testWidgets('shows the message with the default icon', (tester) async {
      await pumpComponent(tester, const AppEmptyView(message: 'Nothing here'));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });

    testWidgets('accepts a custom icon', (tester) async {
      await pumpComponent(
        tester,
        const AppEmptyView(message: 'Nothing here', icon: Icons.search),
      );
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows the action only when label and handler are both set', (
      tester,
    ) async {
      await pumpComponent(
        tester,
        AppEmptyView(message: 'Nothing here', action: () {}),
      );
      expect(find.byType(AppPrimaryButton), findsNothing);

      var taps = 0;
      await pumpComponent(
        tester,
        AppEmptyView(
          message: 'Nothing here',
          action: () => taps++,
          actionLabel: 'Add one',
        ),
      );
      await tester.tap(find.text('Add one'));
      expect(taps, 1);
    });
  });

  group('AppMainFooter', () {
    testWidgets('collapses to nothing without links', (tester) async {
      await pumpComponent(tester, const AppMainFooter());
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('collapses to nothing with an empty link list', (tester) async {
      await pumpComponent(tester, const AppMainFooter(links: []));
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders one tappable link per entry', (tester) async {
      var taps = 0;
      await pumpComponent(
        tester,
        AppMainFooter(
          links: [
            AppFooterLink(label: 'About', onTap: () => taps++),
            AppFooterLink(label: 'Licenses', onTap: () {}),
          ],
        ),
      );
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Licenses'), findsOneWidget);
      await tester.tap(find.text('About'));
      expect(taps, 1);
    });
  });

  group('AppDefaultFooter', () {
    testWidgets('navigates to /about when the About link is tapped', (
      tester,
    ) async {
      final scope = await pumpInScope(
        tester,
        const Scaffold(bottomNavigationBar: AppDefaultFooter()),
      );
      const l10n = AppLocalizationsEn();
      await tester.tap(find.text(l10n.footerAbout));
      await tester.pumpAndSettle();
      expect(scope.location, '/about');
      expect(find.text('route:/about'), findsOneWidget);
    });

    testWidgets('opens the license page from the Licenses link', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        const Scaffold(bottomNavigationBar: AppDefaultFooter()),
      );
      const l10n = AppLocalizationsEn();
      await tester.tap(find.text(l10n.footerLicenses));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('AppDrawer', () {
    Widget drawerHost(Widget drawer) =>
        Scaffold(drawer: drawer, body: const SizedBox.shrink());

    testWidgets('renders the app name, subtitle and items', (tester) async {
      await pumpComponent(
        tester,
        wrapInScaffold: false,
        drawerHost(
          AppDrawer(
            appName: 'FlutterBase',
            headerSubtitle: 'Design System',
            items: [
              AppDrawerItem(label: 'Home', icon: Icons.home, onTap: () {}),
              const AppDrawerItem.divider(),
              AppDrawerItem(label: 'Search', icon: Icons.search, onTap: () {}),
            ],
          ),
        ),
      );
      final state = tester.state<ScaffoldState>(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('FlutterBase'), findsOneWidget);
      expect(find.text('Design System'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.byType(Divider), findsAtLeastNWidgets(2));
    });

    testWidgets('taps an item and closes via the close button', (tester) async {
      var homeTaps = 0;
      var closes = 0;
      await pumpComponent(
        tester,
        wrapInScaffold: false,
        drawerHost(
          AppDrawer(
            appName: 'FlutterBase',
            onClose: () => closes++,
            items: [
              AppDrawerItem(
                label: 'Home',
                icon: Icons.home,
                isSelected: true,
                onTap: () => homeTaps++,
              ),
            ],
          ),
        ),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(homeTaps, 1);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(closes, 1);
    });

    testWidgets('the default close handler pops the drawer', (tester) async {
      await pumpComponent(
        tester,
        wrapInScaffold: false,
        drawerHost(
          AppDrawer(
            appName: 'FlutterBase',
            items: [AppDrawerItem(label: 'Home', onTap: () {})],
          ),
        ),
      );
      final state = tester.state<ScaffoldState>(find.byType(Scaffold));
      state.openDrawer();
      await tester.pumpAndSettle();
      expect(state.isDrawerOpen, isTrue);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(state.isDrawerOpen, isFalse);
    });

    testWidgets('renders bottom items below a divider', (tester) async {
      await pumpComponent(
        tester,
        wrapInScaffold: false,
        drawerHost(
          AppDrawer(
            appName: 'FlutterBase',
            items: [AppDrawerItem(label: 'Home', onTap: () {})],
            bottomItems: [
              AppDrawerItem(label: 'About', icon: Icons.info, onTap: () {}),
            ],
          ),
        ),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('About'), findsOneWidget);
    });

    testWidgets('an empty bottom list adds no extra divider', (tester) async {
      await pumpComponent(
        tester,
        wrapInScaffold: false,
        drawerHost(
          AppDrawer(
            appName: 'FlutterBase',
            items: [AppDrawerItem(label: 'Home', onTap: () {})],
            bottomItems: const [],
          ),
        ),
      );
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('AppDrawerItem', () {
    test('divider factory carries no label, icon or handler', () {
      const item = AppDrawerItem.divider();
      expect(item.isDivider, isTrue);
      expect(item.label, isEmpty);
      expect(item.icon, isNull);
      expect(item.onTap, isNull);
      expect(item.isSelected, isFalse);
    });

    test('a normal item is not selected by default', () {
      const item = AppDrawerItem(label: 'Home');
      expect(item.isDivider, isFalse);
      expect(item.isSelected, isFalse);
    });
  });

  group('openAppLicensePage', () {
    testWidgets('opens the license page with the app branding', (tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openAppLicensePage(context),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });

    testWidgets('renders in the dark theme too', (tester) async {
      await pumpComponent(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => openAppLicensePage(context),
            child: const Text('Open'),
          ),
        ),
        theme: AppTheme.dark,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });
}
