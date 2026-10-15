// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Environment — see the enum `_Section` for what points at it.
extension _EnvironmentSection on _SettingsPanelState {
  /// Workspace environment variables (ADR-0064): names on the list, values
  /// in the keychain and never displayed again. The store is a
  /// ChangeNotifier; the list section listens so add/remove repaints.
  List<Widget> _environmentSection(BuildContext context, DswAlias color) {
    final store = widget.environment;
    return [
      _heading(
        color,
        AppLocalizations.of(context).settingsEnvironment,
        AppLocalizations.of(context).settingsEnvironmentIntro,
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (store.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        store.error!,
                        style: DswType.xxs12.copyWith(
                          color: color.stateErrorPrimary,
                        ),
                      ),
                    ),
                  ),
                for (final name in store.names)
                  _EnvironmentRow(
                    name: name,
                    onEdit: () => _editEnvironmentValue(context, store, name),
                    onDelete: () => store.remove(name),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: CapsuleButton(
              label: AppLocalizations.of(context).envAdd,
              onTap: () => _addEnvironmentVariable(context, store),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _addEnvironmentVariable(
    BuildContext context,
    EnvironmentStore store,
  ) async {
    final name = TextEditingController();
    final value = TextEditingController();
    final step = MediaQuery.textScalerOf(context).scale(1);
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          AppLocalizations.of(context).envAdd,
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
              controller: name,
              placeholder: Text(AppLocalizations.of(context).envNameHint),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            ShadInput(
              controller: value,
              placeholder: Text(AppLocalizations.of(context).envValueHint),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    value.dispose();
    if (saved == true) await store.add(name.text.trim(), value.text);
  }

  Future<void> _editEnvironmentValue(
    BuildContext context,
    EnvironmentStore store,
    String name,
  ) async {
    final value = TextEditingController();
    final step = MediaQuery.textScalerOf(context).scale(1);
    final saved = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(name, style: DswType.sStrong14),
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
        child: ShadInput(
          controller: value,
          placeholder: Text(AppLocalizations.of(context).envValueHint),
          autofocus: true,
        ),
      ),
    );
    value.dispose();
    if (saved == true) await store.updateValue(name, value.text);
  }
}

/// One environment variable of the management list: the name, with edit
/// (rewrite the keychain value) and delete. The value itself is never read
/// back for display — a secret shown once is a secret stored twice.
class _EnvironmentRow extends StatelessWidget {
  const _EnvironmentRow({
    required this.name,
    required this.onEdit,
    required this.onDelete,
  });

  final String name;
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
            child: Text(
              name,
              style: DswType.s14.copyWith(color: color.labelPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            tooltip: AppLocalizations.of(context).envDelete,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

/// One instruction card of the management list: title, one-line preview,
/// an enable switch writing the settings document, and edit/delete.
