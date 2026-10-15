// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Workbench — see the enum `_Section` for what points at it.
extension _WorkbenchSection on _SettingsPanelState {
  List<Widget> _workbenchSection(DswAlias color) {
    final prefs = widget.workbenchPrefs;
    return [
      _heading(
        color,
        AppLocalizations.of(context).terminal,
        AppLocalizations.of(context).settingsTerminalIntro,
      ),
      const SizedBox(height: 12),
      _Field(
        label: AppLocalizations.of(context).fontFamily,
        controller: _fontFamily,
        hint: AppLocalizations.of(context).fontFamilyHint,
        code: true,
        focusNode: _fontFamilyFocus,
        onSubmitted: (_) => _commitFontFamily(),
      ),
      const SizedBox(height: 12),
      _Stepper(
        label: AppLocalizations.of(context).fontSize,
        value: prefs.terminalFontSize,
        min: terminalFontSizeMin,
        max: terminalFontSizeMax,
        onChanged: (size) =>
            widget.onPrefsChange?.call(prefs.copyWith(terminalFontSize: size)),
      ),
      const SizedBox(height: 12),
      _SwitchRow(
        label: AppLocalizations.of(context).seedBottomPanel,
        description: AppLocalizations.of(context).seedBottomPanelDesc,
        value: prefs.bottomPanelAutoTerminal,
        onChanged: (value) => widget.onPrefsChange?.call(
          prefs.copyWith(bottomPanelAutoTerminal: value),
        ),
      ),
      const SizedBox(height: 28),
      _heading(
        color,
        AppLocalizations.of(context).tabs,
        AppLocalizations.of(context).settingsTabsIntro,
      ),
      const SizedBox(height: 12),
      _SwitchRow(
        label: AppLocalizations.of(context).explorer,
        description: AppLocalizations.of(context).explorerDesc,
        value: prefs.tabEnabled('explorer'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('explorer', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: AppLocalizations.of(context).terminal,
        description: AppLocalizations.of(context).terminalDesc,
        value: prefs.tabEnabled('terminal'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('terminal', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: AppLocalizations.of(context).git,
        description: AppLocalizations.of(context).gitDesc,
        value: prefs.tabEnabled('git'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('git', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: AppLocalizations.of(context).subagents,
        description: AppLocalizations.of(context).subagentsDesc,
        value: prefs.tabEnabled('subagent'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('subagent', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: AppLocalizations.of(context).browser,
        description: AppLocalizations.of(context).browserDesc,
        value: prefs.tabEnabled('browser'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('browser', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: AppLocalizations.of(context).sidechat,
        description: AppLocalizations.of(context).sideChatDesc,
        value: prefs.tabEnabled('sidechat'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('sidechat', value)),
      ),
    ];
  }
}
