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

/// How much of the sheet the chosen-tag chips may take before they scroll.
///
/// Roughly three rows of chips. Past that the picker below is what the
/// reader needs to see — the chips are a record of what is already chosen,
/// and scrolling them costs less than losing the search field.
const double _chosenTagsMaxHeight = 132;

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
///
/// A name the library does not hold yet is offered as a tag to make, from
/// the search field itself. That is the one thing here that reaches the
/// server before Save — a tag has to exist before media can point at it —
/// and it still changes nothing about the media until the reader saves.
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

  /// True while a new tag is being put into the library.
  ///
  /// Separate from [_saving] because it interrupts a different thing: the
  /// header keeps showing Save, and it is the picker's row that reports the
  /// wait.
  bool _creating = false;

  /// True while anything is in flight. Every control is disabled together:
  /// making a tag and saving the set both act on the chosen set, and letting
  /// one run during the other would save a set the reader is still changing.
  bool get _busy => _saving || _creating;

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

  /// Puts [name] into the library and files this media under it.
  ///
  /// No permission check of its own: the server guards `POST /api/tags` with
  /// the same `media:tag-manage` it guards the replacement with, so a reader
  /// who can open this editor at all can already make tags.
  Future<void> _create(String name, List<Tag> chosen) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _creating = true);
    final Tag created;
    try {
      created = await ref.read(editMediaTagsUseCaseProvider).create(name);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      messenger.showSnackBar(
        SnackBar(content: Text(describeLoadError(error, l10n))),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _creating = false;
      // Chosen straight away: naming a tag from this sheet is how the reader
      // says this photo belongs under it. Nothing reaches the media until
      // they save, exactly as when they tick an existing tag.
      //
      // Guarded because the server answers a name it already holds with the
      // existing tag, which the reader may already have chosen.
      _chosen = chosen.contains(created) ? chosen : [...chosen, created];
    });
    // The picker's answer for this query was read before the tag existed, so
    // it would go on offering to make one that is now in the library.
    ref.invalidate(tagSuggestionsProvider(_query));
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
        creating: _creating,
        onQueryChanged: _onQueryChanged,
        onToggle: (tag) => _toggle(tag, _chosen ?? loaded),
        onCreate: (name) => unawaited(_create(name, _chosen ?? loaded)),
        onSave: _busy ? null : () => unawaited(_save(_chosen ?? loaded)),
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
    required this.creating,
    required this.onQueryChanged,
    required this.onToggle,
    required this.onCreate,
    required this.onSave,
  });

  final List<Tag> chosen;
  final String query;
  final TextEditingController searchController;
  final bool saving;
  final bool creating;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<Tag> onToggle;
  final ValueChanged<String> onCreate;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final suggestions = ref.watch(tagSuggestionsProvider(query));
    final busy = saving || creating;

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
          // Bounded and scrollable: a media item with many tags — or a few
          // long ones on a narrow screen — would otherwise grow the chips
          // until they pushed the search field and Save off the sheet, and
          // adding tags is exactly how a reader reaches that state.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _chosenTagsMaxHeight),
            child: SingleChildScrollView(
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
                            onDeleted: busy ? null : () => onToggle(tag),
                          ),
                      ],
                    ),
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
              enabled: !busy,
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
                query: query,
                enabled: !busy,
                creating: creating,
                onToggle: onToggle,
                onCreate: onCreate,
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

/// The library's tags, with the ones already on this media ticked, headed by
/// an offer to make the typed name into a tag when the library holds no such
/// name.
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.available,
    required this.chosen,
    required this.query,
    required this.enabled,
    required this.creating,
    required this.onToggle,
    required this.onCreate,
  });

  final List<Tag> available;
  final List<Tag> chosen;

  /// What the picker was filtered by — the name a new tag would take.
  final String query;
  final bool enabled;
  final bool creating;
  final ValueChanged<Tag> onToggle;
  final ValueChanged<String> onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final name = query.trim();
    // Offered only when no tag in reach carries this exact name. Chosen tags
    // are checked as well as the picker's answer: a tag just made is chosen
    // immediately, and until the picker has re-read it would otherwise be
    // offered a second time.
    final creatable =
        name.isNotEmpty &&
        !_holdsName(available, name) &&
        !_holdsName(chosen, name);
    if (available.isEmpty && !creatable) {
      return _SheetMessage(text: l10n.mediaTagsNoMatches);
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: available.length + (creatable ? 1 : 0),
      itemBuilder: (context, index) {
        if (creatable && index == 0) {
          return ListTile(
            leading: creating
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            title: Text(l10n.mediaTagsCreate(name)),
            onTap: enabled ? () => onCreate(name) : null,
          );
        }
        final tag = available[creatable ? index - 1 : index];
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

  /// Whether any of [tags] is named [name], ignoring case — the same
  /// comparison the server makes before it decides a name is new, so the
  /// offer appears exactly when a tap would actually make something.
  static bool _holdsName(List<Tag> tags, String name) {
    final folded = name.toLowerCase();
    return tags.any((tag) => tag.name.toLowerCase() == folded);
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
