import 'package:flutter/material.dart';
import 'package:flutterbase/domain/entities/bookmark.dart';
import 'package:flutterbase/domain/errors/app_error.dart';
import 'package:flutterbase/presentation/l10n/app_localizations.dart';
import 'package:flutterbase/presentation/theme/theme.dart';
import 'package:flutterbase/presentation/widgets/ui/widgets.dart';

/// Collects a title and a URL, returning a validated [BookmarkDraft].
///
/// Returns null when the user cancels. The dialog does not decide what a
/// valid bookmark is — it calls the Domain constructor and reports the
/// [DomainError] it throws, so the rule lives in exactly one place.
Future<BookmarkDraft?> showBookmarkFormDialog(BuildContext context) {
  return showDialog<BookmarkDraft>(
    context: context,
    builder: (context) => const _BookmarkFormDialog(),
  );
}

class _BookmarkFormDialog extends StatefulWidget {
  const _BookmarkFormDialog();

  @override
  State<_BookmarkFormDialog> createState() => _BookmarkFormDialogState();
}

class _BookmarkFormDialogState extends State<_BookmarkFormDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _url = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final draft = _buildDraft();
    if (draft == null) {
      setState(() => _errorText = l10n.bookmarksInvalidInput);
      return;
    }
    Navigator.of(context).pop(draft);
  }

  /// Builds the draft, or null when the Domain rejects the input.
  BookmarkDraft? _buildDraft() {
    final url = Uri.tryParse(_url.text.trim());
    if (url == null) return null;
    try {
      return BookmarkDraft(title: _title.text, url: url);
    } on DomainError {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.bookmarksAddTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _title,
            label: l10n.bookmarksTitleLabel,
            hint: l10n.bookmarksTitleHint,
            autofocus: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _url,
            label: l10n.bookmarksUrlLabel,
            hint: l10n.bookmarksUrlHint,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            errorText: _errorText,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bookmarksCancel),
        ),
        TextButton(onPressed: _submit, child: Text(l10n.bookmarksSave)),
      ],
    );
  }
}
