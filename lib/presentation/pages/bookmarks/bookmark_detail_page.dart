import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/providers/bookmark_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:flutterbase/shared/app_config.dart';

/// A single bookmark — and the screen an App Link lands on.
///
/// It is reachable two ways: tapped from the list, or opened cold from
/// `https://<host>/bookmarks/42`. Both go through the same provider, so the
/// screen does not need to know which one happened. The id may be missing
/// (the link was deleted) or unparseable (someone typed the URL), and both
/// render the not-found state rather than throwing.
class BookmarkDetailPage extends ConsumerWidget {
  const BookmarkDetailPage({required this.id, super.key});

  /// Null when the path parameter was not a valid [BookmarkId].
  final BookmarkId? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookmarkId = id;

    return Scaffold(
      appBar: AppMainHeader(title: l10n.bookmarkDetailTitle),
      body: bookmarkId == null
          ? _NotFound(l10n: l10n)
          : switch (ref.watch(bookmarkProvider(bookmarkId))) {
              AsyncLoading<Bookmark?>() => const AppLoadingView(),
              AsyncError<Bookmark?>(:final error) => AppErrorView(
                message: error is AppError ? error.message : l10n.commonError,
                onRetry: () => ref.invalidate(bookmarkProvider(bookmarkId)),
              ),
              AsyncData<Bookmark?>(value: null) => _NotFound(l10n: l10n),
              AsyncData<Bookmark?>(value: final bookmark?) => _Details(
                bookmark: bookmark,
              ),
            },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      message: '${l10n.bookmarkNotFound}\n${l10n.bookmarkNotFoundHint}',
      icon: Icons.link_off,
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.bookmark});

  final Bookmark bookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      children: [
        AppSectionHeader(title: bookmark.title),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Field(label: l10n.bookmarkUrlLabel, value: '${bookmark.url}'),
              const SizedBox(height: AppSpacing.md),
              _Field(
                label: l10n.bookmarkCreatedAtLabel,
                value: _formatLocal(context, bookmark.createdAt),
              ),
              const SizedBox(height: AppSpacing.md),
              _Field(
                label: l10n.bookmarkDeepLinkLabel,
                value: AppConfig.appLink(
                  AppRoutes.bookmarkDetailPath(bookmark.id),
                ).toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: l10n.bookmarkOpen,
          width: double.infinity,
          onPressed: () => unawaited(_open(context, ref)),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppSecondaryButton(
          label: l10n.bookmarkRemove,
          width: double.infinity,
          onPressed: () => unawaited(_remove(context, ref)),
        ),
      ],
    );
  }

  /// Renders a UTC instant in the viewer's own time zone.
  ///
  /// Storage and Domain keep UTC; the conversion happens here, at the edge,
  /// using the locale's own date and time formats.
  static String _formatLocal(BuildContext context, DateTime utc) {
    final local = utc.toLocal();
    final materialL10n = MaterialLocalizations.of(context);
    final date = materialL10n.formatFullDate(local);
    final time = materialL10n.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date $time';
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = AppLocalizations.of(context).bookmarkOpenFailed;
    final opened = await ref
        .read(openBookmarkUseCaseProvider)
        .execute(bookmark);
    if (!opened) {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.bookmarkRemoveConfirmTitle),
        content: Text(l10n.bookmarkRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.bookmarksCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.bookmarkRemove),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final removed = l10n.bookmarksRemoved;
    final failed = l10n.commonError;

    final deleted = await ref
        .read(bookmarkListProvider.notifier)
        .remove(bookmark.id);
    if (!deleted) {
      // Nothing was written, so stay on the bookmark that still exists
      // rather than reporting a deletion and navigating away from it.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(removed)));
    if (navigator.canPop()) navigator.pop();
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
