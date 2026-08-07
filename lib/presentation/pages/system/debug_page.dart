import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutterbase/presentation/app_scope.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/viewmodels/debug_viewmodel.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

/// Debug information page — shows build metadata and diagnostic actions.
class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  DebugViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_viewModel != null) return;
    final viewModel = AppScope.of(context).createDebugViewModel();
    _viewModel = viewModel;
    viewModel.addListener(_onViewModelChange);
    unawaited(viewModel.loadAppInfo());
  }

  @override
  void dispose() {
    _viewModel?.removeListener(_onViewModelChange);
    super.dispose();
  }

  void _onViewModelChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppMainHeader(
        title: l10n.debugTitle,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyAllToClipboard,
            tooltip: l10n.debugCopyAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.componentPadding),
            decoration: BoxDecoration(
              color: AppColors.statusWarningBg,
              borderRadius: AppRadius.lgBorder,
              border: Border.all(color: AppColors.statusWarning),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: AppColors.statusWarning),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.debugWarning,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.statusWarning,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // App info card
          AppSectionHeader(title: l10n.debugAppInfoSection),
          const SizedBox(height: AppSpacing.sm),
          switch (_viewModel?.state ?? DebugState.loading) {
            DebugState.loading => const AppLoadingView(),
            DebugState.error => AppErrorView(
              message: _viewModel?.appError?.message ?? l10n.commonError,
              onRetry: () => unawaited(_viewModel!.loadAppInfo()),
            ),
            DebugState.loaded => _buildInfoCard(context),
          },
          const SizedBox(height: AppSpacing.lg),

          // Theme info card
          AppSectionHeader(title: l10n.debugThemeSection),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              children: [
                _DebugInfoRow(
                  label: l10n.debugThemeMode,
                  value: Theme.of(context).brightness == Brightness.dark
                      ? l10n.debugThemeModeDark
                      : l10n.debugThemeModeLight,
                ),
                const Divider(height: AppSpacing.xl),
                _DebugInfoRow(
                  label: l10n.debugPrimaryColor,
                  value: colorScheme.primary.toHexString(),
                  valueWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: AppSpacing.iconSm,
                        height: AppSpacing.iconSm,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: AppRadius.smBorder,
                          border: Border.all(color: colorScheme.outline),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        colorScheme.primary.toHexString(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(height: AppSpacing.xl),
                _DebugInfoRow(
                  label: l10n.debugSurfaceColor,
                  value: colorScheme.surface.toHexString(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Actions card
          AppSectionHeader(title: l10n.debugActionsSection),
          const SizedBox(height: AppSpacing.sm),
          AppListCard(
            title: l10n.debugClearLogs,
            leading: const Icon(Icons.clear_all),
            onTap: () {
              _viewModel?.clearLogs();
              _showSnackBar(l10n.debugClearLogsSuccess);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppListCard(
            title: l10n.debugClearCache,
            leading: const Icon(Icons.cleaning_services_outlined),
            onTap: () => _showSnackBar(l10n.debugClearCacheSuccess),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppListCard(
            title: l10n.debugTestCrash,
            leading: const Icon(Icons.warning, color: AppColors.statusError),
            onTap: _showCrashConfirmDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final info = _viewModel!.appInfo!;
    final l10n = AppLocalizations.of(context);
    final entries = <(String, String)>[
      (l10n.debugAppName, AppConfig.appName),
      (l10n.debugVersion, info.version),
      (l10n.debugBuildNumber, info.buildNumber),
      (l10n.debugGitCommit, info.gitCommitFull),
      (l10n.debugFlutterVersion, info.flutterVersion),
      (l10n.debugDartVersion, info.dartVersion),
      (l10n.debugPlatform, l10n.aboutPlatformValue),
      (l10n.debugDesignSystem, AppConfig.designSystemLabel),
      (l10n.debugBuildDate, info.buildDate),
      (l10n.debugIsDebugBuild, info.isDebug.toString()),
    ];
    return AppCard(
      child: Column(
        children: List.generate(entries.length, (i) {
          return Column(
            children: [
              if (i > 0) const Divider(height: AppSpacing.xl),
              _DebugInfoRow(label: entries[i].$1, value: entries[i].$2),
            ],
          );
        }),
      ),
    );
  }

  void _copyAllToClipboard() {
    final info = _viewModel?.appInfo;
    if (info == null) return;
    final l10n = AppLocalizations.of(context);
    final buffer = StringBuffer()
      ..writeln('${l10n.debugAppName}: ${AppConfig.appName}')
      ..writeln('${l10n.debugVersion}: ${info.version}')
      ..writeln('${l10n.debugBuildNumber}: ${info.buildNumber}')
      ..writeln('${l10n.debugGitCommit}: ${info.gitCommitFull}')
      ..writeln('${l10n.debugFlutterVersion}: ${info.flutterVersion}')
      ..writeln('${l10n.debugDartVersion}: ${info.dartVersion}')
      ..writeln('${l10n.debugBuildDate}: ${info.buildDate}')
      ..writeln('${l10n.debugIsDebugBuild}: ${info.isDebug}');
    unawaited(Clipboard.setData(ClipboardData(text: buffer.toString())));
    _showSnackBar(l10n.debugCopiedToClipboard);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showCrashConfirmDialog() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.debugTestCrashTitle),
        content: Text(l10n.debugTestCrashBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.debugCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.debugCrash),
          ),
        ],
      ),
    );
    if (confirmed == true) throw Exception('Test crash');
  }
}

class _DebugInfoRow extends StatelessWidget {
  const _DebugInfoRow({
    required this.label,
    required this.value,
    this.valueWidget,
  });

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child:
              valueWidget ??
              SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
        ),
      ],
    );
  }
}

extension ColorExtension on Color {
  /// Returns the color as an uppercase hex string (e.g. "#1A2B3C").
  String toHexString() {
    // ignore: deprecated_member_use
    final v = value; // ARGB32 int — works across all Flutter versions
    final r = ((v >> 16) & 0xFF).toRadixString(16).padLeft(2, '0');
    final g = ((v >> 8) & 0xFF).toRadixString(16).padLeft(2, '0');
    final b = (v & 0xFF).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }
}
