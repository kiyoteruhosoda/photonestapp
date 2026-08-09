import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/domain/entities/tag.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/l10n/error_descriptions.dart';
import 'package:photonest/presentation/providers/media_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';

/// How long typing has to pause before the library's tags are searched.
///
/// Matches the timeline's search field: each change is a request, so sending
/// on every keystroke would fire one per character and let a stale answer
/// land after a newer one.
const Duration tagSearchDebounce = Duration(milliseconds: 350);

/// Opens the tag editor for [id] as a bottom sheet.
///
/// Returns the tags the server settled on when the reader saved, or null when
/// they closed without saving — the caller then knows whether anything about
/// this media changed.
Future<List<Tag>?> showMediaTagEditor(
  BuildContext context, {
  required MediaId id,
}) {
  return showModalBottomSheet<List<Tag>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => MediaTagEditor(id: id),
  );
}

/// Shows the tags on one media item and lets the reader change which of the
/// library's tags it carries.
///
/// The editor works on a *set it owns* and writes the whole set back on save,
/// which is the shape the server's endpoint takes. Nothing is sent while the
/// reader is still choosing: adding three tags is one request, and closing
/// without saving leaves the media exactly as it was.
class MediaTagEditor extends ConsumerStatefulWidget {
  const MediaTagEditor({required this.id, super.key});

  final MediaId id;

  @override
  ConsumerState<MediaTagEditor> createState() => _MediaTagEditorState();
}

class _MediaTagEditorState extends ConsumerState<MediaTagEditor> {
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  /// What the picker is currently filtered by. Separate from the field's own
  /// text so the request follows the debounce rather than every keystroke.
  String _query = '';

  /// The tags the reader has settled on, or null until the media's current
  /// tags have been read.
  ///
  /// Null rather than an empty list: an empty list is a real answer ("no
  /// tags"), and starting from one would let a save that raced the initial
  /// read wipe every tag the media had.
  List<Tag>? _chosen;

  /// True while the replacement is in flight — the save disables itself so a
  /// double tap cannot send twice.
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(tagSearchDebounce, () {
      if (!mounted || _query == value) return;
      setState(() => _query = value);
    });
  }

  void _toggle(Tag tag, List<Tag> chosen) {
    setState(() {
      _chosen = chosen.contains(tag)
          ? [
              for (final each in chosen)
                if (each != tag) each,
            ]
          : [...chosen, tag];
    });
  }

  Future<void> _save(List<Tag> chosen) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    final List<Tag> settled;
    try {
      settled = await ref
          .read(editMediaTagsUseCaseProvider)
          .replace(widget.id, chosen);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text(describeLoadError(error, l10n))),
      );
      return;
    }
    if (!mounted) return;
    // The sheet closes on the server's answer rather than on what was asked
    // for: a tag another device deleted meanwhile is simply not in it.
    navigator.pop(settled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(mediaTagsProvider(widget.id));

    return switch (current) {
      AsyncData<List<Tag>>(value: final loaded) => _EditorBody(
        chosen: _chosen ?? loaded,
        query: _query,
        searchController: _search,
        saving: _saving,
        onQueryChanged: _onQueryChanged,
        onToggle: (tag) => _toggle(tag, _chosen ?? loaded),
        onSave: _saving ? null : () => unawaited(_save(_chosen ?? loaded)),
      ),
      AsyncError<List<Tag>>(:final error) => _SheetMessage(
        text: describeLoadError(error, l10n),
      ),
      _ => const _SheetMessage.loading(),
    };
  }
}

/// The editor once the media's current tags are known.
class _EditorBody extends ConsumerWidget {
  const _EditorBody({
    required this.chosen,
    required this.query,
    required this.searchController,
    required this.saving,
    required this.onQueryChanged,
    required this.onToggle,
    required this.onSave,
  });

  final List<Tag> chosen;
  final String query;
  final TextEditingController searchController;
  final bool saving;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Tag> onToggle;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suggestions = ref.watch(tagSuggestionsProvider(query));

    return Padding(
      // Lifts the sheet clear of the on-screen keyboard, which covers the
      // picker as soon as the search field takes focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.lg,
              AppSpacing.pageMargin,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.mediaTagsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (saving)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton(
                    onPressed: onSave,
                    child: Text(l10n.mediaTagsSave),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageMargin,
            ),
            child: chosen.isEmpty
                ? Text(l10n.mediaTagsNoneOnMedia)
                : Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final tag in chosen)
                        InputChip(
                          label: Text(tag.name),
                          onDeleted: saving ? null : () => onToggle(tag),
                        ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageMargin,
              AppSpacing.md,
              AppSpacing.pageMargin,
              AppSpacing.sm,
            ),
            child: TextField(
              controller: searchController,
              enabled: !saving,
              onChanged: onQueryChanged,
              decoration: InputDecoration(
                labelText: l10n.mediaTagsSearchLabel,
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          Flexible(
            child: switch (suggestions) {
              AsyncData<List<Tag>>(value: final available) => _SuggestionList(
                available: available,
                chosen: chosen,
                enabled: !saving,
                onToggle: onToggle,
              ),
              AsyncError<List<Tag>>(:final error) => _SheetMessage(
                text: describeLoadError(error, l10n),
              ),
              _ => const _SheetMessage.loading(),
            },
          ),
        ],
      ),
    );
  }
}

/// The library's tags, with the ones already on this media ticked.
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.available,
    required this.chosen,
    required this.enabled,
    required this.onToggle,
  });

  final List<Tag> available;
  final List<Tag> chosen;
  final bool enabled;
  final ValueChanged<Tag> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (available.isEmpty) {
      return _SheetMessage(text: l10n.mediaTagsNoMatches);
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: available.length,
      itemBuilder: (context, index) {
        final tag = available[index];
        final attribute = tag.attribute;
        return CheckboxListTile(
          value: chosen.contains(tag),
          onChanged: enabled ? (_) => onToggle(tag) : null,
          title: Text(tag.name),
          subtitle: attribute == null
              ? null
              : Text(_attributeLabel(attribute, l10n)),
        );
      },
    );
  }

  static String _attributeLabel(
    TagAttribute attribute,
    AppLocalizations l10n,
  ) => switch (attribute) {
    TagAttribute.thing => l10n.tagAttributeThing,
    TagAttribute.person => l10n.tagAttributePerson,
    TagAttribute.place => l10n.tagAttributePlace,
    TagAttribute.event => l10n.tagAttributeEvent,
    TagAttribute.scene => l10n.tagAttributeScene,
    TagAttribute.activity => l10n.tagAttributeActivity,
    TagAttribute.source => l10n.tagAttributeSource,
    TagAttribute.others => l10n.tagAttributeOthers,
  };
}

/// A single line of text filling the sheet — a wait, a failure, or "nothing
/// matched".
class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.text}) : loading = false;

  const _SheetMessage.loading() : text = null, loading = true;

  final String? text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: loading
            ? const CircularProgressIndicator()
            : Text(text ?? '', textAlign: TextAlign.center),
      ),
    );
  }
}
