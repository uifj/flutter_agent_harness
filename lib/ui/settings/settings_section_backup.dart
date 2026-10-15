// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Backup — see the enum `_Section` for what points at it.
extension _BackupSection on _SettingsPanelState {
  List<Widget> _backupSection(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsBackup,
      AppLocalizations.of(context).settingsBackupIntro,
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        _ActionRow(
          title: AppLocalizations.of(context).backupCreate,
          description: AppLocalizations.of(context).backupCreateDesc,
          button: CapsuleButton(
            label: AppLocalizations.of(context).backupExport,
            onTap: _createBackup,
          ),
        ),
        _ActionRow(
          title: AppLocalizations.of(context).backupRestore,
          description: AppLocalizations.of(context).backupRestoreDesc,
          button: CapsuleButton(
            label: AppLocalizations.of(context).backupImport,
            onTap: _restoreBackup,
          ),
        ),
        if (widget.onOpenPreRestoreFolder != null)
          _ActionRow(
            title: AppLocalizations.of(context).preRestoreTitle,
            description: AppLocalizations.of(context).preRestoreDesc,
            button: CapsuleButton(
              label: AppLocalizations.of(context).revealInFiles,
              onTap: widget.onOpenPreRestoreFolder!,
            ),
          ),
        _ActionRow(
          title: AppLocalizations.of(context).settingsReset,
          description: AppLocalizations.of(context).settingsResetDesc,
          button: CapsuleButton(
            label: AppLocalizations.of(context).settingsReset,
            danger: true,
            onTap: _resetSettings,
          ),
          last: true,
        ),
      ],
    ),
  ];

  /// The reset entry (ADR-0045 PB): confirm first — this throws configuration
  /// away — then let the stores quarantine their own files.
  Future<void> _resetSettings() async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppLocalizations.of(context).settingsResetConfirmTitle,
      description: AppLocalizations.of(context).settingsResetConfirmBody,
      confirmLabel: AppLocalizations.of(context).settingsReset,
    );
    if (!confirmed || !mounted) return;
    await widget.onReset();
    if (!mounted) return;
    showFeedback(context, AppLocalizations.of(context).settingsResetDone);
  }

  Future<void> _createBackup() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: AppLocalizations.of(context).backupExport,
      fileName: BackupService.defaultFileName(),
      type: FileType.custom,
      allowedExtensions: [BackupService.backupExtension],
    );
    if (path == null || !mounted) return;
    try {
      final count = await BackupService.createBackup(path);
      if (!mounted) return;
      showFeedback(
        context,
        AppLocalizations.of(context).backupCreated('$count'),
      );
    } catch (e) {
      if (!mounted) return;
      showFeedback(
        context,
        '${AppLocalizations.of(context).backupFailed}: $e',
        destructive: true,
      );
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: AppLocalizations.of(context).backupImport,
      type: FileType.custom,
      allowedExtensions: [BackupService.backupExtension],
    );
    if (result == null || result.files.single.path == null || !mounted) return;
    try {
      final count = await BackupService.restoreBackup(
        result.files.single.path!,
      );
      if (!mounted) return;
      showFeedback(
        context,
        AppLocalizations.of(context).backupRestored('$count'),
      );
    } catch (e) {
      if (!mounted) return;
      showFeedback(
        context,
        '${AppLocalizations.of(context).backupFailed}: $e',
        destructive: true,
      );
    }
  }
}
