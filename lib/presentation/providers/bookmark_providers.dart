import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutterbase/application/usecases/bookmark/add_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/get_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/list_bookmarks_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/open_bookmark_usecase.dart';
import 'package:flutterbase/application/usecases/bookmark/remove_bookmark_usecase.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/value_objects/bookmark_id.dart';
import 'package:flutterbase/presentation/providers/app_providers.dart';

// ─── Use-case seams ────────────────────────────────────────────────────────
//
// One provider per use case, each overridden by the composition root. Screens
// depend on these rather than on a service locator, so a widget test swaps in
// a fake by overriding the same provider.

final Provider<ListBookmarksUseCase> listBookmarksUseCaseProvider =
    Provider<ListBookmarksUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('listBookmarksUseCaseProvider'),
      );
    });

final Provider<GetBookmarkUseCase> getBookmarkUseCaseProvider =
    Provider<GetBookmarkUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('getBookmarkUseCaseProvider'),
      );
    });

final Provider<AddBookmarkUseCase> addBookmarkUseCaseProvider =
    Provider<AddBookmarkUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('addBookmarkUseCaseProvider'),
      );
    });

final Provider<RemoveBookmarkUseCase> removeBookmarkUseCaseProvider =
    Provider<RemoveBookmarkUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('removeBookmarkUseCaseProvider'),
      );
    });

final Provider<OpenBookmarkUseCase> openBookmarkUseCaseProvider =
    Provider<OpenBookmarkUseCase>((ref) {
      throw UnimplementedError(
        missingOverrideMessage('openBookmarkUseCaseProvider'),
      );
    });

// ─── Screen state ──────────────────────────────────────────────────────────

/// The bookmark list, together with the commands that change it.
///
/// Written by hand rather than with `riverpod_generator`: this template does
/// not adopt `riverpod_annotation`, so there is no build step between editing
/// this file and running the app. See `docs/adr/0002-starter-stack.md`.
final AsyncNotifierProvider<BookmarkListNotifier, List<Bookmark>>
bookmarkListProvider =
    AsyncNotifierProvider<BookmarkListNotifier, List<Bookmark>>(
      BookmarkListNotifier.new,
    );

/// Loads and mutates the stored bookmarks.
///
/// Every mutation re-reads the list from the repository instead of patching
/// the in-memory copy: storage stays the single source of truth, so a failed
/// write cannot leave the screen showing a bookmark that was never saved.
class BookmarkListNotifier extends AsyncNotifier<List<Bookmark>> {
  @override
  Future<List<Bookmark>> build() {
    return ref.read(listBookmarksUseCaseProvider).execute();
  }

  /// Stores [draft], then refreshes the list.
  ///
  /// Returns false when the write failed. A rejected draft also surfaces as
  /// an [AsyncError] on this provider, so the list renders its error state —
  /// but the caller has to know too, or it would report success over a write
  /// that never happened.
  Future<bool> add(BookmarkDraft draft) {
    final add = ref.read(addBookmarkUseCaseProvider);
    return _mutate(() => add.execute(draft));
  }

  /// Deletes the bookmark [id], then refreshes the list.
  ///
  /// Returns false when the delete failed.
  Future<bool> remove(BookmarkId id) {
    final remove = ref.read(removeBookmarkUseCaseProvider);
    return _mutate(() => remove.execute(id));
  }

  /// Runs a write, re-reads the list, and drops the cached details.
  ///
  /// Invalidating [bookmarkProvider] here — rather than having the detail
  /// provider watch this one — keeps the dependency one-directional: the
  /// screen that changed something tells the caches about it.
  ///
  /// Returns whether the write succeeded. [AsyncValue.guard] turns the
  /// failure into provider state rather than an exception, which is what the
  /// list screen wants; without also reporting it back, every caller would
  /// carry on as if the write had landed.
  Future<bool> _mutate(Future<void> Function() write) async {
    state = const AsyncValue<List<Bookmark>>.loading();
    state = await AsyncValue.guard(() async {
      await write();
      return ref.read(listBookmarksUseCaseProvider).execute();
    });
    ref.invalidate(bookmarkProvider);
    return !state.hasError;
  }

  /// Re-reads the list, e.g. after a pull-to-refresh.
  Future<void> reload() async {
    state = const AsyncValue<List<Bookmark>>.loading();
    state = await AsyncValue.guard(
      () => ref.read(listBookmarksUseCaseProvider).execute(),
    );
  }
}

/// A single bookmark, keyed by id.
///
/// The detail screen reads this instead of filtering [bookmarkListProvider]
/// so a deep link can open it directly, before any list has been loaded.
/// Resolves to null when the id is not (or is no longer) stored.
///
/// [BookmarkListNotifier] invalidates this family after every write, so a
/// bookmark deleted from the list flips an open detail screen to its
/// not-found state.
final bookmarkProvider = FutureProvider.family<Bookmark?, BookmarkId>((
  ref,
  id,
) {
  return ref.read(getBookmarkUseCaseProvider).execute(id);
});
