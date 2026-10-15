// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Phrases — see the enum `_Section` for what points at it.
extension _PhraseSections on _SettingsPanelState {
  /// Quick phrases (ADR-0063): the library's only editor. Changes commit
  /// through the store immediately — phrases are content, not panel drafts,
  /// and the composer reads them when it next mounts.
  List<Widget> _phrasesSection(DswAlias color) {
    final store = widget.quickPhrases;
    final phrases = store.phrases;
    return [
      _heading(
        color,
        AppLocalizations.of(context).settingsPhrases,
        AppLocalizations.of(context).settingsPhrasesIntro,
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          for (final phrase in phrases)
            _PhraseRow(
              phrase: phrase,
              onEdit: () => _editPhrase(phrase),
              onDelete: () => store.remove(phrase.id),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CapsuleButton(
                  label: AppLocalizations.of(context).quickPhraseAdd,
                  enabled: !store.isFull,
                  onTap: () => _editPhrase(null),
                ),
                if (store.isFull) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      AppLocalizations.of(context).quickPhraseFull,
                      style: DswType.xxs12.copyWith(color: color.labelTertiary),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ];
  }

  /// One editor for create and update: two fields, one save. An empty title
  /// or body does not write — a row that inserts nothing is not a phrase.
  Future<void> _editPhrase(QuickPhrase? phrase) async {
    final title = TextEditingController(text: phrase?.title ?? '');
    final body = TextEditingController(text: phrase?.text ?? '');
    final step = MediaQuery.textScalerOf(context).scale(1);
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          phrase == null
              ? AppLocalizations.of(context).quickPhraseAdd
              : AppLocalizations.of(context).edit,
          style: DswType.sStrong14,
        ),
        actions: [
          ShadButton.outline(
            height: 24 * step,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          ShadButton(
            height: 24 * step,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShadInput(
              controller: title,
              placeholder: Text(
                AppLocalizations.of(context).quickPhraseTitleHint,
              ),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            ShadInput(
              controller: body,
              placeholder: Text(
                AppLocalizations.of(context).quickPhraseTextHint,
              ),
              minLines: 3,
              maxLines: 5,
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    if (saved != true) return;
    if (phrase == null) {
      widget.quickPhrases.add(title.text, body.text);
    } else {
      widget.quickPhrases.update(phrase.id, title: title.text, text: body.text);
    }
  }
}

/// One phrase of the management list: title over a one-line preview, with
/// edit and delete as the row's trailing pair.
class _PhraseRow extends StatelessWidget {
  const _PhraseRow({
    required this.phrase,
    required this.onEdit,
    required this.onDelete,
  });

  final QuickPhrase phrase;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  phrase.title,
                  style: DswType.s14.copyWith(color: color.labelPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  phrase.text,
                  style: DswType.xxs12.copyWith(color: color.labelTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DswIconButton(
            icon: LucideIcons.pencil,
            tooltip: AppLocalizations.of(context).edit,
            onTap: onEdit,
          ),
          const SizedBox(width: 4),
          DswIconButton(
            icon: LucideIcons.trash,
            tooltip: AppLocalizations.of(context).quickPhraseDelete,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// One environment variable of the management list: the name, with edit
/// (rewrite the keychain value) and delete. The value itself is never read
/// back for display — a secret shown once is a secret stored twice.
