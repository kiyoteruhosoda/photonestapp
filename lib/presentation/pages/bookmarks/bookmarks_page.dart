import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/navigation/app_routes.dart';
import 'package:flutterbase/presentation/pages/bookmarks/bookmark_form_dialog.dart';
import 'package:flutterbase/presentation/providers/bookmark_providers.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';
import 'package:go_router/go_router.dart';

/// Lists the bookmarks stored in SQLite.
///
/// A [ConsumerWidget] rather than a `StatefulWidget` with a ViewModel: the
/// list has no local state beyond what the repository holds, so Riverpod's
/// [AsyncValue] carries the loading, error, and data states directly.
class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final bookmarks = ref.watch(bookmarkListProvider);

    return Scaffold(
      appBar: AppMainHeader(title: l10n.bookmarksTitle),
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(_addBookmark(context, ref)),
        tooltip: l10n.bookmarksAdd,
        child: const Icon(Icons.add),
      ),
      body: switch (bookmarks) {
        AsyncLoading<List<Bookmark>>() => const AppLoadingView(),
        AsyncError<List<Bookmark>>(:final error) => AppErrorView(
          message: _describe(error, l10n),
          onRetry: () =>
              unawaited(ref.read(bookmarkListProvider.notifier).reload()),
        ),
        AsyncData<List<Bookmark>>(value: final items) when items.isEmpty =>
          AppEmptyView(
            message: '${l10n.bookmarksEmpty}\n${l10n.bookmarksEmptyHint}',
            icon: Icons.bookmark_border,
            actionLabel: l10n.bookmarksAdd,
            action: () => unawaited(_addBookmark(context, ref)),
          ),
        AsyncData<List<Bookmark>>(value: final items) => _BookmarkList(
          bookmarks: items,
        ),
      },
    );
  }

  Future<void> _addBookmark(BuildContext context, WidgetRef ref) async {
    final draft = await showBookmarkFormDialog(context);
    if (draft == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = AppLocalizations.of(context).bookmarksSaved;
    final stored = await ref.read(bookmarkListProvider.notifier).add(draft);
    // On failure the list itself has already flipped to its error state,
    // which names what went wrong — so say nothing rather than claim a save
    // that did not happen.
    if (!stored) return;
    messenger.showSnackBar(SnackBar(content: Text(saved)));
  }

  /// Turns a thrown object into something worth showing a user.
  ///
  /// Typed [AppError]s already carry a message written for humans; anything
  /// else is an unexpected failure, so the generic string is used rather than
  /// leaking a stack-trace-shaped `toString()` into the UI.
  static String _describe(Object error, AppLocalizations l10n) =>
      error is AppError ? error.message : l10n.commonError;
}

class _BookmarkList extends ConsumerWidget {
  const _BookmarkList({required this.bookmarks});

  final List<Bookmark> bookmarks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: ref.read(bookmarkListProvider.notifier).reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.pageMargin),
        itemCount: bookmarks.length,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.listItemGap),
        itemBuilder: (context, index) {
          final bookmark = bookmarks[index];
          return AppListCard(
            title: bookmark.title,
            subtitle: bookmark.url.toString(),
            leading: const Icon(Icons.bookmark_outline),
            onTap: () =>
                context.push(AppRoutes.bookmarkDetailPath(bookmark.id)),
          );
        },
      ),
    );
  }
}
