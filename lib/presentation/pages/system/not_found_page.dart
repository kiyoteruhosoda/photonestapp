import 'package:flutter/material.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:go_router/go_router.dart';

/// Shown when no route matches.
///
/// Deep links make this reachable in production, not just after a typo in a
/// `push` call: anyone can send a link to a path this build does not know, so
/// the screen names the location and offers a way back to Home.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({required this.uri, super.key});

  /// The location that failed to match.
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppMainHeader(title: l10n.commonPageNotFound),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.commonNotFound,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SelectableText(
              '$uri',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: l10n.navHome,
              onPressed: () => context.go(AppRoutes.main),
            ),
          ],
        ),
      ),
    );
  }
}
