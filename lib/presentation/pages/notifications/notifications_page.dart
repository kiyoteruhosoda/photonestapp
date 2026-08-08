import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/backup_notification.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/l10n/error_descriptions.dart';
import 'package:flutterbase/presentation/providers/notification_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

/// The notification list behind the header's bell button.
///
/// Today it holds backup results only — ADR-0005 named those the first use
/// of the reserved button. Opening the list marks everything read (the
/// provider does that after a successful load).
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifications = ref.watch(backupNotificationsProvider);

    return Scaffold(
      appBar: AppMainHeader(title: l10n.notificationsTitle),
      body: switch (notifications) {
        AsyncLoading<List<BackupNotification>>() => const AppLoadingView(),
        AsyncError<List<BackupNotification>>(:final error) => AppErrorView(
          message: describeLoadError(error, l10n),
          onRetry: () => unawaited(
            ref.read(backupNotificationsProvider.notifier).reload(),
          ),
        ),
        AsyncData<List<BackupNotification>>(value: final items)
            when items.isEmpty =>
          AppEmptyView(
            message:
                '${l10n.notificationsEmpty}\n'
                '${l10n.notificationsEmptyHint}',
            icon: Icons.notifications_none_outlined,
          ),
        AsyncData<List<BackupNotification>>(value: final items) =>
          ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.pageMargin),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _NotificationTile(notification: items[index]),
          ),
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final BackupNotification notification;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final title = notification.hasFailures
        ? l10n.notificationBackupHadFailures
        : l10n.notificationBackupCompleted;
    final details = <String>[
      if (notification.uploadedCount > 0)
        l10n.uploadDone(notification.uploadedCount),
      if (notification.failedCount > 0)
        l10n.uploadFailed(notification.failedCount),
    ].join(' ');
    return ListTile(
      leading: Icon(
        notification.hasFailures
            ? Icons.error_outline
            : Icons.check_circle_outline,
        color: notification.hasFailures
            ? colorScheme.error
            : colorScheme.primary,
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontWeight: notification.isRead ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '$details\n${_formatInstant(notification.occurredAt.toLocal())}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      isThreeLine: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.componentPadding,
        vertical: AppSpacing.xs,
      ),
    );
  }

  /// `2026-08-08 12:30` — stored UTC, shown in the user's local time.
  static String _formatInstant(DateTime local) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
