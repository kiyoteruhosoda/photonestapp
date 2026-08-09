import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/domain/value_objects/media_library_query.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';

/// How long typing has to pause before the search is sent.
///
/// Each change re-reads the library from the first window, so sending on
/// every keystroke would fire a request per character and let a stale
/// answer land after a newer one.
const Duration mediaSearchDebounce = Duration(milliseconds: 350);

/// The search field and filter chips above the photo timeline.
///
/// The narrowing lives in [libraryMediaQueryProvider], not here: the timeline
/// reloads from it, and it outlives this widget so a rebuild (rotation, tab
/// switch) does not silently drop what the reader typed.
class MediaSearchBar extends ConsumerStatefulWidget {
  const MediaSearchBar({super.key});

  @override
  ConsumerState<MediaSearchBar> createState() => _MediaSearchBarState();
}

class _MediaSearchBarState extends ConsumerState<MediaSearchBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Seeded from the provider so returning to the tab shows what is
    // actually being filtered on.
    _controller = TextEditingController(
      text: ref.read(libraryMediaQueryProvider).text,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(mediaSearchDebounce, () {
      if (!mounted) return;
      ref.read(libraryMediaQueryProvider.notifier).search(value);
    });
  }

  /// Sends immediately — the reader pressed the keyboard's search key, so
  /// there is nothing left to wait for.
  void _onSubmitted(String value) {
    _debounce?.cancel();
    ref.read(libraryMediaQueryProvider.notifier).search(value);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(libraryMediaQueryProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(libraryMediaQueryProvider);
    final notifier = ref.read(libraryMediaQueryProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageMargin,
        AppSpacing.sm,
        AppSpacing.pageMargin,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onChanged: _onTextChanged,
            onSubmitted: _onSubmitted,
            decoration: InputDecoration(
              labelText: l10n.searchFieldLabel,
              hintText: l10n.searchFieldHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isUnfiltered
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: l10n.searchClearFilters,
                      onPressed: _clear,
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final kind in MediaKindFilter.values)
                ChoiceChip(
                  label: Text(_kindLabel(kind, l10n)),
                  selected: query.kind == kind,
                  onSelected: (_) => notifier.filterByKind(kind),
                ),
              FilterChip(
                label: Text(l10n.searchFilterFavorites),
                avatar: const Icon(Icons.favorite_border, size: 18),
                selected: query.favoritesOnly,
                onSelected: notifier.showFavoritesOnly,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _kindLabel(MediaKindFilter kind, AppLocalizations l10n) =>
      switch (kind) {
        MediaKindFilter.any => l10n.searchFilterAll,
        MediaKindFilter.photo => l10n.searchFilterPhotos,
        MediaKindFilter.video => l10n.searchFilterVideos,
      };
}
