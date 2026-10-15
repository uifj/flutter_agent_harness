// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Extensions and approvals — see the enum `_Section` for what points at it.
extension _ExtensionAndApprovalSections on _SettingsPanelState {
  List<Widget> _extensionsSection(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsMcpServers,
      AppLocalizations.of(context).settingsMcpIntro,
    ),
    const SizedBox(height: 12),
    for (final draft in List<_ServerDraft>.of(_servers)) ...[
      _serverCard(color, draft),
      const SizedBox(height: 8),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: CapsuleButton(
        label: AppLocalizations.of(context).addServer,
        onTap: _addServer,
      ),
    ),
    const SizedBox(height: 28),
    _heading(
      color,
      AppLocalizations.of(context).settingsSkills,
      AppLocalizations.of(context).settingsSkillsIntro,
    ),
    const SizedBox(height: 12),
    _Field(
      label: AppLocalizations.of(context).folder,
      controller: _skills,
      hint: '${widget.supportPath}/skills',
      code: true,
    ),
  ];

  /// The decisions the approval panel's "Always allow" saved for this folder,
  /// each with the way to take it back. A rule nobody can see or revoke is not
  /// a permission but a hidden bypass, which is why the list ships with the
  /// button that writes it (ADR-0012).
  List<Widget> _approvalsSection(DswAlias color) {
    final store = widget.approvals!;
    final rules = store.saved;
    return [
      _heading(
        color,
        AppLocalizations.of(context).approvalsTitle,
        AppLocalizations.of(context).approvalsNote,
      ),
      const SizedBox(height: 12),
      if (rules.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: Text(
            AppLocalizations.of(context).approvalsEmpty,
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
        )
      else
        SettingsCard(
          dividers: true,
          children: [
            for (final rule in rules)
              _ActionRow(
                title: rule.display,
                description: rule.outcome == ApprovalOutcome.allow
                    ? AppLocalizations.of(context).approvalAllowed
                    : AppLocalizations.of(context).approvalDenied,
                button: CapsuleButton(
                  label: AppLocalizations.of(context).forget,
                  onTap: () => store.forget(rule),
                ),
              ),
            _ActionRow(
              title: AppLocalizations.of(context).forgetWorkspaceApprovals,
              description: AppLocalizations.of(context).approvalsNote,
              button: CapsuleButton(
                label: AppLocalizations.of(context).forget,
                danger: true,
                onTap: () =>
                    store.forgetWorkspace(widget.settings.workspaceRoot),
              ),
              last: true,
            ),
          ],
        ),
    ];
  }
}
