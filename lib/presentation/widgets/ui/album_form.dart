import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photonest/domain/entities/album.dart';
import 'package:photonest/domain/value_objects/media_id.dart';
import 'package:photonest/presentation/l10n/app_localizations.dart';
import 'package:photonest/presentation/providers/album_providers.dart';
import 'package:photonest/presentation/theme/theme.dart';
import 'package:photonest/presentation/widgets/ui/app_text_field.dart';

/// Asks for an album's name and description and creates it, returning the
/// album the server stored — or null when the reader backed out.
///
/// [holding] is filed under the new album in the same request. That is what
/// makes "new album" reachable from the viewer without a second round trip,
/// and it is why creating an album is useful on its own: the album arrives
/// with the photo already in it.
Future<Album?> showAlbumCreateForm(
  BuildContext context, {
  List<MediaId> holding = const <MediaId>[],
}) {
  return showDialog<Album>(
    context: context,
    builder: (dialogContext) => _AlbumForm(holding: holding),
  );
}

/// Asks for a new name and description for [album] and saves them,
/// returning the album the server settled on — or null when the reader
/// backed out.
Future<Album?> showAlbumEditForm(BuildContext context, Album album) {
  return showDialog<Album>(
    context: context,
    builder: (dialogContext) => _AlbumForm(album: album),
  );
}

/// One dialog for both creating and renaming.
///
/// The two differ only in what the fields start from and which call runs on
/// save; splitting them into two widgets would duplicate the validation, the
/// busy handling, and the failure line.
class _AlbumForm extends ConsumerStatefulWidget {
  const _AlbumForm({this.album, this.holding = const <MediaId>[]});

  /// The album being renamed, or null when one is being created.
  final Album? album;

  /// Media to file under a newly created album. Ignored when renaming — the
  /// rename call deliberately leaves the album's media alone.
  final List<MediaId> holding;

  @override
  ConsumerState<_AlbumForm> createState() => _AlbumFormState();
}

class _AlbumFormState extends ConsumerState<_AlbumForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.album?.title ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.album?.description ?? '',
  );

  /// True once the reader has tried to save with a blank name. The field
  /// stays quiet until then — an empty form is not yet a mistake.
  bool _nameRejected = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _nameRejected = true);
      return;
    }
    final editing = ref.read(albumEditingProvider.notifier);
    final existing = widget.album;
    final album = existing == null
        ? await editing.create(
            _name.text,
            description: _description.text,
            mediaIds: widget.holding,
          )
        : await editing.updateDetails(
            existing.id,
            title: _name.text,
            description: _description.text,
          );
    if (!mounted) return;
    if (album == null) {
      // The notifier holds the failure; the dialog stays open so the reader
      // can retry without retyping.
      ref.read(albumEditingProvider.notifier).acknowledgeFailure();
      messenger.showSnackBar(SnackBar(content: Text(l10n.albumSaveFailed)));
      return;
    }
    navigator.pop(album);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(albumEditingProvider.select((state) => state.busy));
    final creating = widget.album == null;
    return AlertDialog(
      title: Text(creating ? l10n.albumCreateTitle : l10n.albumEditTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _name,
            label: l10n.albumNameLabel,
            autofocus: true,
            enabled: !busy,
            errorText: _nameRejected ? l10n.albumNameRequired : null,
            textInputAction: TextInputAction.next,
            // Cleared as soon as the reader types, so the complaint does
            // not sit under a field that now has a name in it.
            onChanged: (_) {
              if (_nameRejected) setState(() => _nameRejected = false);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _description,
            label: l10n.albumDescriptionLabel,
            enabled: !busy,
            maxLines: 2,
            onSubmitted: (_) => unawaited(_save()),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: busy ? null : () => unawaited(_save()),
          child: Text(
            creating ? l10n.albumCreateAction : l10n.albumRenameAction,
          ),
        ),
      ],
    );
  }
}
