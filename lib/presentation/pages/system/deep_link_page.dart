import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

/// Shows how this build is wired for App Links, and echoes the URI it was
/// opened with.
///
/// The echo is the useful part when setting deep links up: reaching this
/// screen from a browser proves the intent filter matched, that Android
/// verified the domain, and that the router mapped the path — the three
/// things that can independently be wrong.
class DeepLinkPage extends StatelessWidget {
  const DeepLinkPage({required this.uri, super.key});

  /// The location the router resolved, query string included.
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final verified = AppConfig.appLink(AppRoutes.deepLink);
    final custom = AppConfig.customLink(AppRoutes.deepLink);

    return Scaffold(
      appBar: AppMainHeader(title: l10n.deepLinkTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        children: [
          AppCard(
            child: Text(
              l10n.deepLinkIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: l10n.deepLinkOpenedWith),
          const SizedBox(height: AppSpacing.sm),
          AppCard(child: SelectableText('$uri')),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: l10n.deepLinkParameters),
          const SizedBox(height: AppSpacing.sm),
          AppCard(child: _Parameters(parameters: uri.queryParameters)),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: l10n.deepLinkVerifiedSection),
          const SizedBox(height: AppSpacing.sm),
          _CopyableValue(value: '$verified'),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(title: l10n.deepLinkCustomSchemeSection),
          const SizedBox(height: AppSpacing.sm),
          _CopyableValue(value: '$custom'),
          const SizedBox(height: AppSpacing.lg),

          AppSectionHeader(
            title: l10n.deepLinkTrySection,
            subtitle: l10n.deepLinkTryHint,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CopyableValue(value: _adbCommand(verified)),
        ],
      ),
    );
  }

  /// The `adb` incantation that fires the same intent Android sends when a
  /// verified link is tapped in a browser.
  static String _adbCommand(Uri link) =>
      'adb shell am start -a android.intent.action.VIEW '
      '-c android.intent.category.BROWSABLE -d "$link"';
}

class _Parameters extends StatelessWidget {
  const _Parameters({required this.parameters});

  final Map<String, String> parameters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (parameters.isEmpty) {
      return Text(
        AppLocalizations.of(context).deepLinkNoParameters,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in parameters.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: SelectableText(
              '${entry.key} = ${entry.value}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _CopyableValue extends StatelessWidget {
  const _CopyableValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: l10n.deepLinkCopy,
            onPressed: () => unawaited(_copy(context)),
          ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).deepLinkCopied;
    await Clipboard.setData(ClipboardData(text: value));
    messenger.showSnackBar(SnackBar(content: Text(copied)));
  }
}
