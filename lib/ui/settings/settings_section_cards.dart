// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Cards — see the enum `_Section` for what points at it.
extension _CardSections on _SettingsPanelState {
  /// Instruction cards (ADR-0067): edit cards here; the enable switches
  /// write the settings document through onSave — the same draft path the
  /// toggles use, so Save is the commit point for the enable-set.
  List<Widget> _cardsSection(BuildContext context, DswAlias color) {
    final store = widget.instructionCards;
    final enabled = widget.settings.enabledCardIds;
    return [
      _heading(
        color,
        AppLocalizations.of(context).settingsCards,
        AppLocalizations.of(context).settingsCardsIntro,
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final cards = store.cards;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cards.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          AppLocalizations.of(context).cardsEmpty,
                          style: DswType.xxs12.copyWith(
                            color: color.labelTertiary,
                          ),
                        ),
                      ),
                    ),
                  for (final card in cards)
                    _CardRow(
                      title: card.title,
                      text: card.text,
                      enabled: enabled.contains(card.id),
                      onToggle: (value) {
                        final next = value
                            ? [...enabled, card.id]
                            : [
                                for (final id in enabled)
                                  if (id != card.id) id,
                              ];
                        _saveWith(
                          widget.settings.copyWith(enabledCardIds: next),
                        );
                      },
                      onEdit: () => _editCard(card),
                      onDelete: () {
                        store.remove(card.id);
                        if (enabled.contains(card.id)) {
                          _saveWith(
                            widget.settings.copyWith(
                              enabledCardIds: [
                                for (final id in enabled)
                                  if (id != card.id) id,
                              ],
                            ),
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: CapsuleButton(
              label: AppLocalizations.of(context).cardAdd,
              enabled: !store.isFull,
              onTap: () => _editCard(null),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _editCard(InstructionCard? card) async {
    final title = TextEditingController(text: card?.title ?? '');
    final body = TextEditingController(text: card?.text ?? '');
    final step = MediaQuery.textScalerOf(context).scale(1);
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          AppLocalizations.of(context).cardAdd,
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
              placeholder: Text(AppLocalizations.of(context).cardTitleHint),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            ShadInput(
              controller: body,
              placeholder: Text(AppLocalizations.of(context).cardTextHint),
              minLines: 3,
              maxLines: 6,
            ),
          ],
        ),
      ),
    );
    title.dispose();
    body.dispose();
    if (saved != true) return;
    if (card == null) {
      widget.instructionCards.add(title.text, body.text);
    } else {
      widget.instructionCards.update(
        card.id,
        title: title.text,
        text: body.text,
      );
    }
  }
}

/// One instruction card of the management list: title, one-line preview,
/// an enable switch writing the settings document, and edit/delete.
class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.title,
    required this.text,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String text;
  final bool enabled;
  final ValueChanged<bool> onToggle;
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
                  title,
                  style: DswType.s14.copyWith(color: color.labelPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  text,
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
            tooltip: AppLocalizations.of(context).cardDelete,
            onTap: onDelete,
          ),
          const SizedBox(width: 4),
          ShadSwitch(value: enabled, onChanged: onToggle),
        ],
      ),
    );
  }
}

/// One scheduled task of the list: name over the schedule summary, with the
/// enable switch and delete.
