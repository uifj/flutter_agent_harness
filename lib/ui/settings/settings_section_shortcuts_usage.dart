// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// ShortcutsUsage — see the enum `_Section` for what points at it.
extension _ShortcutAndUsageSections on _SettingsPanelState {
  /// Backup & Restore: export all persistent data to a zip archive, or restore
  /// from one. The operations are fire-and-forget — the file picker handles the
  /// path, and the service does the work. A snackbar reports the outcome.
  /// The shortcut registry as a read-only table (ADR-0045 PC): one place
  /// defines the bindings, this surface only names them. Recording and
  /// conflict handling are a later batch.
  List<Widget> _shortcutsSection(DswAlias color) {
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    return [
      _heading(
        color,
        AppLocalizations.of(context).settingsShortcuts,
        AppLocalizations.of(context).settingsShortcutsIntro,
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          for (final command in shortcuts.ShortcutRegistry.commands)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      trKey(AppLocalizations.of(context), command.labelKey),
                      style: DswType.s14.copyWith(color: color.labelPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DswShape.sm,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.bgLayer2,
                      borderRadius: BorderRadius.circular(DswShape.inner),
                    ),
                    child: Text(
                      shortcuts.ShortcutRegistry.acceleratorFor(
                        command.defaultSpec,
                        isMacOS: isMac,
                      ),
                      style: DswType.xs13.copyWith(
                        color: color.labelSecondary,
                        fontFamily: 'SF Mono',
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  /// The local usage ledger rendered as counts — the local subset of ZCode's
  /// usage snapshot (`usage-stats.ts:170-251`), fed by `AppScope.usageLedger`
  /// through the widget's new `onOpenCrashLog`/usage parameters. Read-only:
  /// nothing here writes back to any store.
  List<Widget> _usageSection(DswAlias color) {
    final summary = widget.usageSummary;
    return [
      _heading(
        color,
        AppLocalizations.of(context).settingsUsage,
        AppLocalizations.of(context).settingsUsageIntro,
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          _UsageStatRow(
            label: AppLocalizations.of(context).usageTurns,
            value: '${summary.turns}',
          ),
          _UsageStatRow(
            label: AppLocalizations.of(context).usageTotalTokens,
            value: '${summary.totalTokens}',
          ),
          _UsageStatRow(
            label: AppLocalizations.of(context).usageErrorRate,
            value: '${(summary.errorRate * 100).toStringAsFixed(1)}%',
          ),
          if (widget.crashFiles != null)
            _ActionRow(
              title: AppLocalizations.of(context).usageCrashLogTitle,
              description: AppLocalizations.of(context).usageCrashLogDesc,
              button: CapsuleButton(
                label: AppLocalizations.of(context).usageCrashLogOpen,
                onTap: widget.onOpenCrashLog ?? () {},
              ),
              last: true,
            ),
        ],
      ),
    ];
  }
}
