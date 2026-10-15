// The settings panel.
//
// A port of `ui-settings-general/src/client/SettingsRoot.module.css` (figma
// 501:29904 / 501:29947) for the shell — masked overlay, 800px panel, 188px nav
// rail, 54px header, scrolling options area — and of
// `ui-settings-models/src/client/ModelsSection.module.css` for the form
// vocabulary inside it: 32px fields, 12/18 field labels, capsule actions.
//
// dsh's panel height is taken from the viewport rather than from the content,
// because its sections differ by hundreds of pixels and a content-sized panel
// would resize under the pointer on every nav click. Kept, even though this
// build has two short sections today.
//
// Everything is edited into controllers and committed on Save. That is dsh's
// shape too (`EditorFooter` / apply), and it is the only one that works here:
// saving the model fields tears the runtime down, so it cannot happen per
// keystroke.

import 'dart:async' show TimeoutException;
import 'dart:io' show Directory, HttpException, SocketException;

import 'package:app_common/app_common.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show
        ShadAccordion,
        ShadAccordionController,
        ShadAccordionItem,
        ShadBorder,
        ShadButton,
        ShadCard,
        ShadDialog,
        ShadInput,
        ShadOption,
        ShadBadge,
        ShadSeparator,
        ShadSwitch,
        showShadDialog;
import 'package:url_launcher/url_launcher.dart';

import '../../genkit/models_endpoint.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/tr_key.dart';
import '../../model/app_meta.dart';
import '../../model/app_settings.dart' hide ThemeMode;
import '../../model/app_settings.dart' as settings;
import '../../model/approval_rule.dart';
import '../../model/mcp_settings.dart';
import '../../model/model_settings.dart';
import '../../model/workbench_prefs.dart';
import '../../state/approval_rule_store.dart';
import '../../state/backup_service.dart';
import '../../model/shortcut_registry.dart' as shortcuts;
import '../../state/usage_ledger.dart';
import '../../model/instruction_card.dart';
import '../../state/instruction_card_store.dart';
import '../../model/scheduled_task.dart';
import '../../state/scheduled_task_store.dart';
import '../../state/environment_store.dart';
import '../../state/quick_phrase_store.dart';
import '../../model/quick_phrase.dart';
import '../primitives/confirm_dialog.dart';
import '../primitives/icon_button.dart';
import '../../theme/dsw_shad_bridge.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/tappable.dart';
import '../primitives/feedback.dart';
import '../primitives/menu.dart';
import '../primitives/capsule_button.dart';
import 'widgets/settings_card.dart';

// ADR-0085 D7: the page's sections live one file each, as parts of this library.
// The split is a relocation, not a redesign — every section body stayed verbatim,
// so the state it reads and the widgets it draws have one owner each. `_content`
// below is the registry: `_Section` names the section, the switch picks its file.
part 'settings_rows.dart';
part 'settings_shell_nav.dart';
part 'settings_section_general.dart';
part 'settings_section_models.dart';
part 'settings_section_workspace.dart';
part 'settings_section_workbench.dart';
part 'settings_section_extensions.dart';
part 'settings_section_shortcuts_usage.dart';
part 'settings_section_environment.dart';
part 'settings_section_cards.dart';
part 'settings_section_tasks.dart';
part 'settings_section_phrases.dart';
part 'settings_section_diagnostics.dart';
part 'settings_section_backup.dart';

/// Which section the rail is pointing at.
enum _Section {
  general,
  appearance,
  models,
  workspace,
  workbench,
  extensions,
  shortcuts,
  phrases,
  environment,
  cards,
  tasks,
  usage,
  diagnostics,
  approvals,
  backup,
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSave,
    required this.onReset,
    required this.usageSummary,
    required this.onSaveCurrentToBook,
    required this.onActivateSavedProvider,
    required this.onDeleteSavedProvider,
    this.onOpenCrashLog,
    this.crashFiles,
    this.onOpenDiagnosticsFolder,
    this.onOpenPreRestoreFolder,
    required this.quickPhrases,
    required this.environment,
    required this.instructionCards,
    required this.scheduledTasks,
    required this.onClose,
    required this.onPickFolder,
    required this.supportPath,
    this.workbenchPrefs = const WorkbenchPrefs(),
    this.onPrefsChange,
    this.modelsFetcher,
    this.approvals,
  });

  final AppSettings settings;

  /// Commits the edited document. Awaited, so the panel can report the outcome
  /// rather than closing on faith.
  final Future<void> Function(AppSettings next) onSave;

  /// The Backup section's reset entry: quarantines both preference files and
  /// clears the keychain key (ADR-0045 PB). Behind a confirm dialog here;
  /// the store-level work lives in the stores.
  final Future<void> Function() onReset;

  /// The local usage summary (ADR-0045 PC): read by the caller, rendered
  /// read-only here.
  final UsageSummary usageSummary;

  /// The saved-provider book (ADR-0045 PF-2): the store owns the secret-slot
  /// choreography; the section only calls.
  final Future<void> Function() onSaveCurrentToBook;
  final Future<void> Function(String id) onActivateSavedProvider;
  final Future<void> Function(String id) onDeleteSavedProvider;

  /// Opens the crash-log directory in the file manager; null hides the row.
  final VoidCallback? onOpenCrashLog;

  /// Whether a crash-log directory exists at all.
  final bool? crashFiles;

  /// Opens the diagnostics directory in the file manager (ADR-0058); null
  /// hides the row.
  final VoidCallback? onOpenDiagnosticsFolder;

  /// Opens the pre-restore snapshots in the file manager (ADR-0065); null
  /// hides the row.
  final VoidCallback? onOpenPreRestoreFolder;

  /// The quick phrase library (ADR-0063): this section is its only editor;
  /// the composer reads the same store through the host.
  final QuickPhraseStore quickPhrases;

  /// The workspace environment store (ADR-0064): this section manages names;
  /// values live in the keychain and are never shown again.
  final EnvironmentStore environment;

  /// The instruction card store (ADR-0067): this section edits cards and
  /// their enable set (on the settings document through onSave).
  final InstructionCardStore instructionCards;

  /// The scheduled task store (ADR-0069): created and deleted here; the
  /// scheduler in the scope reads it every quarter minute.
  final ScheduledTaskStore scheduledTasks;

  final VoidCallback onClose;

  /// Where this app keeps its own data, resolved at startup and handed in —
  /// the field hints below name a directory, and a hint is a fact the user can
  /// act on, so it cannot be an invented example (ADR-0033: the skills hint used
  /// to read `/Users/you/.dsh/skills`, a path from the project this one was
  /// written against, on a screen whose own description said "application
  /// support directory").
  final String supportPath;

  /// Opens the platform's directory picker and adopts the choice (or null when
  /// the picker is dismissed), returning the settings document with the choice
  /// applied. The panel cannot own this: the picker needs a real window to
  /// attach to, and the document lives above it.
  final Future<AppSettings?> Function(AppSettings current) onPickFolder;

  /// The endpoint interrogation behind "Test connection" and the model field's
  /// quick select — the same fetch answers both. Null keeps the editor free of
  /// live network controls (tests, previews); the app hands it the HTTP one.
  final ModelsEndpointFetcher? modelsFetcher;

  /// The workbench preferences, shown in their own section. Unlike every other
  /// section they commit immediately — none of them can rebuild the agent, so
  /// there is no Save to wait for.
  final WorkbenchPrefs workbenchPrefs;

  /// Commits a workbench preference change. Null leaves the section read-only,
  /// which is what a host that never wired the prefs store wants.
  final ValueChanged<WorkbenchPrefs>? onPrefsChange;

  /// The saved approval decisions for the open folder, listed here so a
  /// decision taken in a hurry can be taken back. Null hides the section
  /// entirely — the same contract as [onPrefsChange] (ADR-0012).
  final ApprovalRuleStore? approvals;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final _key = TextEditingController(text: widget.settings.model.apiKey);
  late final _baseUrl = TextEditingController(
    text: widget.settings.model.baseUrl,
  );
  late final _model = TextEditingController(text: widget.settings.model.model);
  late final _workspace = TextEditingController(
    text: widget.settings.workspaceRoot ?? '',
  );
  late final _skills = TextEditingController(
    text: widget.settings.skillsRoot ?? '',
  );

  /// The terminal font family, committed on submit and on blur rather than per
  /// keystroke: a half-typed font stack is not a preference, and live-saving
  /// one would flash every terminal in the app for each letter.
  late final _fontFamily = TextEditingController(
    text: widget.workbenchPrefs.terminalFontFamily,
  );

  /// Tracks the font field's focus so a blur commits it. Created here rather
  /// than in the field so dispose can reach it.
  final _fontFamilyFocus = FocusNode();

  late LlmProvider _provider = widget.settings.model.provider;

  /// Which provider row carries the open editor card — dsh's "one editor at a
  /// time": the draft's provider starts expanded (the user came here to fix
  /// the connection that is already the document's), and Edit on another row
  /// adopts that provider and moves the card there. Null: every card closed.
  late LlmProvider? _expanded = widget.settings.model.provider;

  /// The "Customized" disclosure inside the editor card, owned by the accordion
  /// rather than by a bool here: the panel used to hold the open flag *and* the
  /// widget used to animate it, which is the same fact in two places (§1B S8).
  /// Collapsed by default, like dsh's `<details>` — a key is the field that
  /// decides whether the connection works at all; the endpoint and the model id
  /// are the fields a working default already answers.
  final ShadAccordionController<String> _disclosure =
      ShadAccordionController<String>();

  /// The language choice, held and committed like the theme.
  late settings.LocaleMode _locale = widget.settings.locale;

  /// The editable copy of the MCP server list. Drafts hold their own
  /// controllers; an invalid draft is dropped at commit rather than refused
  /// at the field, the same repair-not-reject contract the model uses.
  late final List<_ServerDraft> _servers = [
    for (final server in widget.settings.mcpServers) _ServerDraft.of(server),
  ];

  /// The theme choice. Held locally like every other field, applied on Save —
  /// a live-following preview would repaint the panel mid-edit under the
  /// pointer.
  late settings.ThemeMode _theme = widget.settings.theme;

  /// The notification toggle (ADR-0045 PH). Held locally like the theme —
  /// applied on Save.
  late bool _notificationsOn = widget.settings.notificationsOn;

  /// The diagnostics toggles (ADR-0058). Held and committed like the
  /// notification toggle; neither rebuilds the runtime, so Save just
  /// persists and the next model call picks them up.
  late bool _diagnosticRequestLog = widget.settings.diagnosticRequestLog;
  late bool _diagnosticContextLog = widget.settings.diagnosticContextLog;

  /// The appearance/behaviour preferences (ADR-0005). Held and committed like
  /// the theme. None of them rebuilds the runtime — they ride Save purely to
  /// persist — so they need no restart warning, only the same draft-to-document
  /// flow the theme and language already use.
  late settings.AppFontSize _textSize = widget.settings.fontSize;
  late settings.AppConversationWidth _conversationWidth =
      widget.settings.conversationWidth;
  late bool _expandToolCalls = widget.settings.expandToolCalls;

  /// The recents as the picker will edit them. Tracked here rather than derived
  /// from [widget.settings] so an "adopted" folder survives a later cancel: the
  /// recent list is a history, not a permission, and history does not roll
  /// back with the form.
  late List<String> _recent = List.of(widget.settings.recentWorkspaces);

  _Section _section = _Section.general;

  /// The nav's filter field. Empty shows every cell; non-empty keeps only the
  /// cells whose label contains the query (case-insensitive).
  late final _search = TextEditingController();

  /// A key is a secret in a shared-screen sense, so it starts masked; the reveal
  /// is there because a mistyped key fails with the same 401 as a wrong one.
  bool _revealed = false;

  /// Whether the field's folder is absent from disk — derived on every build of
  /// the workspace section, so the warning describes the document as it stands
  /// (typed or picked) rather than the one it came from. A typed path gets the
  /// same warning a dead recent entry shows: both name a place the tools cannot
  /// reach. Stat-per-build is fine at settings-panel cadence.
  bool get _workspaceMissing => _fieldIsMissing(_workspace.text.trim());

  /// True whenever [path] names a folder that is not there.
  bool _fieldIsMissing(String path) =>
      path.isNotEmpty && !Directory(path).existsSync();

  bool _saving = false;
  bool _saved = false;

  /// The endpoint's `/models` ids feeding the model field's quick select —
  /// dsh's "pi-ai endpoint interrogation", here behind the same fetch that
  /// answers "Test connection". Empty until a fetch succeeds; free text in
  /// the field stays valid either way.
  List<String> _endpointModels = const [];

  /// The fetch in flight. One at a time: the button is the guard.
  bool _modelsLoading = false;

  /// What the last probe said. Exactly one of these is non-null after a
  /// fetch; both null before the first.
  String? _probeError;
  int? _probeCount;

  /// Stale-response guard, fa1's generation counter: bumped per fetch, so a
  /// late answer from an abandoned provider/endpoint pair is dropped rather
  /// than presented as the state of the current one.
  int _modelsFetchGeneration = 0;

  @override
  void initState() {
    super.initState();
    // A rule removed from this list is the same list the panel shows, so the
    // store's own notification is what repaints it.
    widget.approvals?.addListener(_onEdited);
    final controllers = [
      _key,
      _baseUrl,
      _model,
      _workspace,
      _skills,
      ..._servers.expand((draft) => draft.controllers),
      _disclosure,
    ];
    for (final controller in controllers) {
      // Dirty state is derived from the controllers, so the actions have to be
      // rebuilt as they change.
      controller.addListener(_onEdited);
    }
    // The fetched model list describes one endpoint; a baseUrl edit moves the
    // conversation somewhere else, and a list that outlives its endpoint is a
    // menu of wrong answers.
    _baseUrl.addListener(_onBaseUrlChanged);
    _fontFamilyFocus.addListener(_onFontFieldBlur);
    _search.addListener(_onEdited);
  }

  void _onEdited() {
    if (!_saved) {
      setState(() {});
      return;
    }
    // The saved notice describes the document on disk; editing invalidates it.
    setState(() => _saved = false);
  }

  /// The page's sections are part files (ADR-0085 D7), and an extension is not a
  /// subclass of `State`, so `setState` is out of reach there. Everything that needs
  /// to repaint the panel — here or in a section file — goes through this one door.
  void rebuild(VoidCallback mutate) => setState(mutate);

  @override
  void dispose() {
    widget.approvals?.removeListener(_onEdited);
    final controllers = [
      _key,
      _baseUrl,
      _model,
      _workspace,
      _skills,
      ..._servers.expand((draft) => draft.controllers),
    ];
    for (final controller in controllers) {
      controller.dispose();
    }
    _fontFamily.dispose();
    _fontFamilyFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Persists [next] through the panel's save path — the manual-model rows'
  /// write. The mirror is the form controllers plus widget.settings, and the
  /// save rebuilds the panel with the saved document.
  Future<void> _saveWith(AppSettings next) async {
    await widget.onSave(next);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.onSave(_edited);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return CallbackShortcuts(
      // Escape reaches here from whichever field has focus, since shortcuts
      // travel up the focus tree.
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: FocusScope(
        autofocus: true,
        // ADR-0006 S4: a full-screen view (main swaps the body to this), not a
        // masked overlay — there is no scrim to tap through, so closing is
        // Escape or the header's close button.
        child: _panel(color),
      ),
    );
  }

  /// Discards the edits. Deliberately: a settings panel dismissed by Escape or by
  /// a click outside has not agreed to anything, and the alternative — saving on
  /// dismissal — would rebuild the runtime by accident.
  void _close() {
    if (_saving) return;
    widget.onClose();
  }

  Widget _panel(DswAlias color) => ColoredBox(
    color: color.bgLayer2,
    child: SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nav(color),
          Expanded(child: _content(color)),
        ],
      ),
    ),
  );

  Widget _nav(DswAlias color) {
    final query = _search.text.trim().toLowerCase();
    final items = <_NavItem>[
      _NavItem(
        _Section.general,
        AppLocalizations.of(context).settingsGeneral,
        LucideIcons.settings,
      ),
      _NavItem(
        _Section.appearance,
        AppLocalizations.of(context).settingsAppearance,
        LucideIcons.sparkles,
      ),
      _NavItem(
        _Section.models,
        AppLocalizations.of(context).settingsModels,
        LucideIcons.network,
      ),
      _NavItem(
        _Section.workspace,
        AppLocalizations.of(context).settingsWorkspace,
        LucideIcons.folder_open,
      ),
      _NavItem(
        _Section.workbench,
        AppLocalizations.of(context).settingsWorkbench,
        LucideIcons.columns_2,
      ),
      _NavItem(
        _Section.extensions,
        AppLocalizations.of(context).settingsExtensions,
        LucideIcons.puzzle,
      ),
      _NavItem(
        _Section.shortcuts,
        AppLocalizations.of(context).settingsShortcuts,
        LucideIcons.keyboard,
      ),
      _NavItem(
        _Section.phrases,
        AppLocalizations.of(context).settingsPhrases,
        LucideIcons.text_cursor_input,
      ),
      _NavItem(
        _Section.environment,
        AppLocalizations.of(context).settingsEnvironment,
        LucideIcons.variable,
      ),
      _NavItem(
        _Section.cards,
        AppLocalizations.of(context).settingsCards,
        LucideIcons.layers,
      ),
      _NavItem(
        _Section.tasks,
        AppLocalizations.of(context).settingsTasks,
        LucideIcons.alarm_clock,
      ),
      _NavItem(
        _Section.usage,
        AppLocalizations.of(context).settingsUsage,
        LucideIcons.chart_column,
      ),
      _NavItem(
        _Section.diagnostics,
        AppLocalizations.of(context).settingsDiagnostics,
        LucideIcons.stethoscope,
      ),
      _NavItem(
        _Section.backup,
        AppLocalizations.of(context).settingsBackup,
        LucideIcons.database_backup,
      ),
      if (widget.approvals != null)
        _NavItem(
          _Section.approvals,
          AppLocalizations.of(context).approvalsTitle,
          LucideIcons.shield_check,
        ),
    ];
    final filtered = query.isEmpty
        ? items
        : items
              .where((item) => item.label.toLowerCase().contains(query))
              .toList();
    return SizedBox(
      width: 188,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 22, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                AppLocalizations.of(context).settings,
                style: DswType.baseStrong16.copyWith(color: color.labelPrimary),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SearchField(
                controller: _search,
                hint: AppLocalizations.of(context).searchSettings,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in filtered) ...[
                      _NavCell(
                        label: item.label,
                        icon: item.icon,
                        active: _section == item.section,
                        onTap: () => setState(() => _section = item.section),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(DswAlias color) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        // The action row is one line of chrome, so the whole seat rides the text
        // step: at 1.8x the label it holds needed more than the 26px this box
        // leaves after its own 20/8 padding, and was cut mid-glyph.
        height: 54 * MediaQuery.textScalerOf(context).scale(1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 20, 14, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // dsh's `settings.action` seat: the notices the panel owes the
              // user sit left of the actions, the actions left of the close.
              // Mutually exclusive, as dsh's savedNotice is: the saved line is
              // what the warning turns into, not a second line under it.
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_saved)
                      Text(
                        AppLocalizations.of(context).saved,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.xxs12.copyWith(
                          color: color.stateSuccessPrimary,
                        ),
                      )
                    else if (_dirty &&
                        _edited.model.requiresRestart(widget.settings.model))
                      Text(
                        AppLocalizations.of(context).restartWarning,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.xxs12.copyWith(
                          color: color.stateWarnLabel,
                        ),
                      ),
                  ],
                ),
              ),
              CapsuleButton(
                label: _saving
                    ? AppLocalizations.of(context).saving
                    : AppLocalizations.of(context).save,
                variant: CapsuleVariant.primary,
                // Dense: the header's content box is 26px tall, and a 36px
                // capsule there is an overflow waiting for a long label.
                size: CapsuleSize.sm,
                enabled: _dirty && !_saving,
                onTap: _save,
              ),
              const SizedBox(width: 8),
              DswIconButton(
                icon: LucideIcons.x,
                tooltip: AppLocalizations.of(context).closeSettings,
                onTap: _close,
                size: 28,
                iconSize: DswShape.iconSm,
              ),
            ],
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          // Centered (2026-09-16 audit F6): in the 800px overlay era a
          // stretch-aligned 720 column was fine, but on a full-screen surface
          // it hugged the left edge and left the whole right half empty.
          // Center keeps the readable line length without the lopsided look.
          child: Center(
            child: ConstrainedBox(
              // `.section` caps at 720 so a 32px field never stretches to a width
              // no value in it would ever reach.
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...switch (_section) {
                    _Section.general => _general(color),
                    _Section.appearance => _appearanceSection(color),
                    _Section.models => _models(color),
                    _Section.workspace => _workspaceSection(color),
                    _Section.workbench => _workbenchSection(color),
                    _Section.extensions => _extensionsSection(color),
                    _Section.shortcuts => _shortcutsSection(color),
                    _Section.phrases => _phrasesSection(color),
                    _Section.environment => _environmentSection(context, color),
                    _Section.cards => _cardsSection(context, color),
                    _Section.tasks => _tasksSection(context, color),
                    _Section.usage => _usageSection(color),
                    _Section.diagnostics => _diagnosticsSection(color),
                    _Section.backup => _backupSection(color),
                    _Section.approvals => _approvalsSection(color),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );

  /// `.title` + `.intro`: dsh's section column sits at `gap: 12` (every
  /// settings section — models, plugins, agent-preset — declares the same
  /// value), so the title and its intro are 12px apart, not the 4px a
  /// label/description pair inside a row would take.
  Widget _heading(DswAlias color, String title, String intro) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: DswType.baseStrong16.copyWith(color: color.labelPrimary),
      ),
      const SizedBox(height: 12),
      Text(intro, style: DswType.s14.copyWith(color: color.labelTertiary)),
    ],
  );
}

/// One General-section row, dsh's Setting-Cell (figma 501:30011): title and
/// description on the left, the figma `Selector` pill on the right, 16/0 of
/// row padding, a hairline separator under every row but the last (the
/// section strips the trailing one — see `GeneralSection.module.css`).
///
/// The pill is the one thing that most differs from this panel's other
/// controls: 36px tall, radius 18, NO border, the module fill — the shape
/// [text] on one line, at the ambient text step. Both narrow-form decisions in
/// this file read their room from these instead of a breakpoint table: the same
/// card is roomy in English at 1.0x and tight in Chinese at 2.2x.
double _oneLineWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}
