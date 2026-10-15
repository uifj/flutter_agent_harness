// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// General — see the enum `_Section` for what points at it.
extension _GeneralAndAppearanceSections on _SettingsPanelState {
  /// The font field leaving focus is a commit — the same value a submit would
  /// have written, minus the need for an Enter key.
  void _onFontFieldBlur() {
    if (_fontFamilyFocus.hasFocus) return;
    _commitFontFamily();
  }

  void _commitFontFamily() {
    final next = _fontFamily.text.trim();
    if (next == widget.workbenchPrefs.terminalFontFamily) return;
    widget.onPrefsChange?.call(
      widget.workbenchPrefs.copyWith(terminalFontFamily: next),
    );
  }

  /// General: the preferences with no home of their own — dsh's General
  /// section is the `settings.general.item` list of Setting-Cell rows
  /// (pad 16/0, hairline separator between, none after the last), of which
  /// this build has the appearance and language rows. Each selector is the
  /// figma `Selector` pill — a 36px r18 capsule on the module fill, no border
  /// — because that is dsh's language row's own shape (`LanguageRow.module.css`).
  List<Widget> _general(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsGeneral,
      AppLocalizations.of(context).settingsGeneralIntro,
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        _SettingCellRow(
          title: AppLocalizations.of(context).theme,
          description: AppLocalizations.of(context).themeDesc,
          leading: LucideIcons.palette,
          labels: {
            settings.ThemeMode.system: AppLocalizations.of(
              context,
            ).followSystem,
            settings.ThemeMode.light: AppLocalizations.of(context).light,
            settings.ThemeMode.dark: AppLocalizations.of(context).dark,
          },
          value: _theme,
          onChanged: (mode) => rebuild(() => _theme = mode),
          last: true,
        ),
        _SettingCellRow(
          title: AppLocalizations.of(context).language,
          description: AppLocalizations.of(context).languageDesc,
          leading: LucideIcons.languages,
          labels: {
            settings.LocaleMode.system: AppLocalizations.of(
              context,
            ).followSystem,
            settings.LocaleMode.en: 'English',
            settings.LocaleMode.zh: '中文',
          },
          value: _locale,
          onChanged: (mode) => rebuild(() => _locale = mode),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: _SwitchRow(
            label: AppLocalizations.of(context).notificationsOn,
            description: AppLocalizations.of(context).notificationsOnDesc,
            value: _notificationsOn,
            onChanged: (value) => rebuild(() => _notificationsOn = value),
          ),
        ),
      ],
    ),
  ];

  /// Appearance (ADR-0005): the starkins preference set ported onto this
  /// panel's own controls — the selector pill for the enums, the switch for the
  /// toggles, all grouped in one `SettingsCard`. Held as drafts and committed on
  /// Save like the theme; none of them rebuilds the runtime, so the wiring that
  /// makes width/preview/tool-expansion actually take effect is ADR-0005 S4.
  List<Widget> _appearanceSection(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsAppearance,
      AppLocalizations.of(context).settingsAppearanceIntro,
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        _SettingCellRow<settings.AppFontSize>(
          title: AppLocalizations.of(context).appearanceTextSize,
          description: AppLocalizations.of(context).appearanceTextSizeDesc,
          labels: {
            settings.AppFontSize.small: AppLocalizations.of(context).sizeSmall,
            settings.AppFontSize.medium: AppLocalizations.of(
              context,
            ).sizeMedium,
            settings.AppFontSize.large: AppLocalizations.of(context).sizeLarge,
          },
          value: _textSize,
          onChanged: (v) => rebuild(() => _textSize = v),
          last: true,
        ),
        _SettingCellRow<settings.AppConversationWidth>(
          title: AppLocalizations.of(context).conversationWidth,
          description: AppLocalizations.of(context).conversationWidthDesc,
          leading: LucideIcons.move_horizontal,
          labels: {
            settings.AppConversationWidth.normal: AppLocalizations.of(
              context,
            ).widthNormal,
            settings.AppConversationWidth.wide: AppLocalizations.of(
              context,
            ).widthWide,
          },
          value: _conversationWidth,
          onChanged: (v) => rebuild(() => _conversationWidth = v),
          last: true,
        ),
        // `_SwitchRow` is a bare row (the workbench section lays it out by
        // hand), so it carries the padding the selector rows get from a cell.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _SwitchRow(
            label: AppLocalizations.of(context).expandToolCalls,
            description: AppLocalizations.of(context).expandToolCallsDesc,
            value: _expandToolCalls,
            onChanged: (v) => rebuild(() => _expandToolCalls = v),
          ),
        ),
      ],
    ),
  ];
}
