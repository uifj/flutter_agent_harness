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
        ShadCard,
        ShadInput,
        ShadOption,
        ShadSeparator,
        ShadSwitch;

import '../../genkit/models_endpoint.dart';

import '../../l10n/locales.dart';
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

/// Which section the rail is pointing at.
enum _Section {
  general,
  appearance,
  models,
  workspace,
  workbench,
  extensions,
  shortcuts,
  usage,
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

  /// Drops the fetch state — the list, and whatever the last probe said —
  /// because both describe an endpoint that is no longer the one on screen.
  void _onBaseUrlChanged() {
    if (_endpointModels.isEmpty && _probeError == null && _probeCount == null) {
      return;
    }
    // Bumped so an in-flight fetch for the abandoned endpoint cannot land.
    _modelsFetchGeneration++;
    setState(() {
      _endpointModels = const [];
      _probeError = null;
      _probeCount = null;
    });
  }

  /// The connection test: one fetch against the DRAFT's endpoint and key,
  /// reported beside the button that caused it rather than in a dialog.
  /// Success is the list itself — a 200 with model ids proves the URL, the
  /// auth, and the response shape at once, and the ids are what the model
  /// field's quick select then offers.
  Future<void> _testConnection() async {
    final fetcher = widget.modelsFetcher;
    if (fetcher == null || _modelsLoading) return;
    final generation = ++_modelsFetchGeneration;
    final provider = _provider;
    final baseUrl = _baseUrl.text.trim().isEmpty
        ? defaultBaseUrlFor(_provider)
        : _baseUrl.text.trim();
    final apiKey = _key.text.trim();
    setState(() {
      _modelsLoading = true;
      _probeError = null;
      _probeCount = null;
    });
    try {
      final models = await fetcher.listModels(
        provider: provider,
        baseUrl: baseUrl,
        apiKey: apiKey,
      );
      if (!mounted || generation != _modelsFetchGeneration) return;
      setState(() {
        _modelsLoading = false;
        _endpointModels = models;
        _probeCount = models.length;
      });
    } catch (error) {
      if (!mounted || generation != _modelsFetchGeneration) return;
      setState(() {
        _modelsLoading = false;
        _probeError = _probeMessage(error);
      });
    }
  }

  /// The shortest sentence an error earns. A status code is the most useful
  /// thing a 401 says; a timeout says so by name; anything else falls back to
  /// its own toString, trimmed to one line.
  String _probeMessage(Object error) => switch (error) {
    HttpException e => e.message,
    TimeoutException _ => context.tr('probeTimeout'),
    FormatException e => e.message,
    SocketException _ => context.tr('connectionFailed'),
    _ => error.toString(),
  };

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

  void _onEdited() {
    if (!_saved) {
      setState(() {});
      return;
    }
    // The saved notice describes the document on disk; editing invalidates it.
    setState(() => _saved = false);
  }

  void _addServer() {
    setState(() {
      final draft = _ServerDraft();
      for (final controller in draft.controllers) {
        controller.addListener(_onEdited);
      }
      _servers.add(draft);
    });
  }

  void _removeServer(_ServerDraft draft) {
    setState(() {
      _servers.remove(draft);
      for (final controller in draft.controllers) {
        controller
          ..removeListener(_onEdited)
          ..dispose();
      }
    });
  }

  /// Switches provider, resetting the connection fields to the new provider's
  /// defaults — a DeepSeek URL leaking into an Anthropic client is worse than
  /// retyping one field — and moves the editor card to the new provider's row.
  /// The fetch state goes with the old endpoint: a fetched list describes the
  /// provider it was asked about, not the seat it happened to sit in.
  void _selectProvider(LlmProvider provider) {
    final reset = widget.settings.model.forProvider(provider);
    _modelsFetchGeneration++;
    setState(() {
      _provider = provider;
      _expanded = provider;
      _disclosure.value = const <String>[];
      _endpointModels = const [];
      _probeError = null;
      _probeCount = null;
      _key.text = reset.apiKey;
      _baseUrl.text = reset.baseUrl;
      _model.text = reset.model;
      _revealed = false;
    });
  }

  /// The document as the fields currently read it.
  ///
  /// Trimmed: a pasted key or path routinely arrives with a trailing newline, and
  /// every one of these fields is compared or concatenated somewhere downstream.
  AppSettings get _edited {
    final model = ModelSettings(
      provider: _provider,
      apiKey: _key.text.trim(),
      baseUrl: _baseUrl.text.trim().isEmpty
          ? defaultBaseUrlFor(_provider)
          : _baseUrl.text.trim(),
      model: _model.text.trim().isEmpty
          ? defaultModelFor(_provider)
          : _model.text.trim(),
      // The manual model list is not a form field; it rides the document the
      // panel was last given (ADR-0045 PG), and the book rides with it — a
      // form-only rebuild would silently drop both (caught by the hardening
      // test's panel-save guard).
      manualModels: widget.settings.model.manualModels,
    );
    final workspace = _workspace.text.trim();
    final skills = _skills.text.trim();
    return AppSettings(
      model: model,
      workspaceRoot: workspace.isEmpty ? null : workspace,
      mcpServers: [for (final draft in _servers) ?draft.asConfig()],
      skillsRoot: skills.isEmpty ? null : skills,
      theme: _theme,
      locale: _locale,
      recentWorkspaces: _recent,
      fontSize: _textSize,
      conversationWidth: _conversationWidth,
      expandToolCalls: _expandToolCalls,
      notificationsOn: _notificationsOn,
      savedProviders: widget.settings.savedProviders,
      activeProviderId: widget.settings.activeProviderId,
    );
  }

  bool get _dirty => _edited != widget.settings;

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
        context.tr('settingsGeneral'),
        LucideIcons.settings,
      ),
      _NavItem(
        _Section.appearance,
        context.tr('settingsAppearance'),
        LucideIcons.sparkles,
      ),
      _NavItem(
        _Section.models,
        context.tr('settingsModels'),
        LucideIcons.network,
      ),
      _NavItem(
        _Section.workspace,
        context.tr('settingsWorkspace'),
        LucideIcons.folder_open,
      ),
      _NavItem(
        _Section.workbench,
        context.tr('settingsWorkbench'),
        LucideIcons.columns_2,
      ),
      _NavItem(
        _Section.extensions,
        context.tr('settingsExtensions'),
        LucideIcons.puzzle,
      ),
      _NavItem(
        _Section.shortcuts,
        context.tr('settingsShortcuts'),
        LucideIcons.keyboard,
      ),
      _NavItem(
        _Section.usage,
        context.tr('settingsUsage'),
        LucideIcons.chart_column,
      ),
      _NavItem(
        _Section.backup,
        context.tr('settingsBackup'),
        LucideIcons.database_backup,
      ),
      if (widget.approvals != null)
        _NavItem(
          _Section.approvals,
          context.tr('approvalsTitle'),
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
                context.tr('settings'),
                style: DswType.baseStrong16.copyWith(color: color.labelPrimary),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _SearchField(
                controller: _search,
                hint: context.tr('searchSettings'),
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
                        context.tr('saved'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.xxs12.copyWith(
                          color: color.stateSuccessPrimary,
                        ),
                      )
                    else if (_dirty &&
                        _edited.model.requiresRestart(widget.settings.model))
                      Text(
                        context.tr('restartWarning'),
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
                label: _saving ? context.tr('saving') : context.tr('save'),
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
                tooltip: context.tr('closeSettings'),
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
                    _Section.usage => _usageSection(color),
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

  /// General: the preferences with no home of their own — dsh's General
  /// section is the `settings.general.item` list of Setting-Cell rows
  /// (pad 16/0, hairline separator between, none after the last), of which
  /// this build has the appearance and language rows. Each selector is the
  /// figma `Selector` pill — a 36px r18 capsule on the module fill, no border
  /// — because that is dsh's language row's own shape (`LanguageRow.module.css`).
  List<Widget> _general(DswAlias color) => [
    _heading(
      color,
      context.tr('settingsGeneral'),
      context.tr('settingsGeneralIntro'),
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        _SettingCellRow(
          title: context.tr('theme'),
          description: context.tr('themeDesc'),
          leading: LucideIcons.palette,
          labels: {
            settings.ThemeMode.system: context.tr('followSystem'),
            settings.ThemeMode.light: context.tr('light'),
            settings.ThemeMode.dark: context.tr('dark'),
          },
          value: _theme,
          onChanged: (mode) => setState(() => _theme = mode),
          last: true,
        ),
        _SettingCellRow(
          title: context.tr('language'),
          description: context.tr('languageDesc'),
          leading: LucideIcons.languages,
          labels: {
            settings.LocaleMode.system: context.tr('followSystem'),
            settings.LocaleMode.en: 'English',
            settings.LocaleMode.zh: '中文',
          },
          value: _locale,
          onChanged: (mode) => setState(() => _locale = mode),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: _SwitchRow(
            label: context.tr('notificationsOn'),
            description: context.tr('notificationsOnDesc'),
            value: _notificationsOn,
            onChanged: (value) => setState(() => _notificationsOn = value),
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
      context.tr('settingsAppearance'),
      context.tr('settingsAppearanceIntro'),
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        _SettingCellRow<settings.AppFontSize>(
          title: context.tr('appearanceTextSize'),
          description: context.tr('appearanceTextSizeDesc'),
          labels: {
            settings.AppFontSize.small: context.tr('sizeSmall'),
            settings.AppFontSize.medium: context.tr('sizeMedium'),
            settings.AppFontSize.large: context.tr('sizeLarge'),
          },
          value: _textSize,
          onChanged: (v) => setState(() => _textSize = v),
          last: true,
        ),
        _SettingCellRow<settings.AppConversationWidth>(
          title: context.tr('conversationWidth'),
          description: context.tr('conversationWidthDesc'),
          leading: LucideIcons.move_horizontal,
          labels: {
            settings.AppConversationWidth.normal: context.tr('widthNormal'),
            settings.AppConversationWidth.wide: context.tr('widthWide'),
          },
          value: _conversationWidth,
          onChanged: (v) => setState(() => _conversationWidth = v),
          last: true,
        ),
        // `_SwitchRow` is a bare row (the workbench section lays it out by
        // hand), so it carries the padding the selector rows get from a cell.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _SwitchRow(
            label: context.tr('expandToolCalls'),
            description: context.tr('expandToolCallsDesc'),
            value: _expandToolCalls,
            onChanged: (v) => setState(() => _expandToolCalls = v),
          ),
        ),
      ],
    ),
  ];

  /// Models, as dsh's provider rows: one outlined card per provider, the
  /// saved provider's dot telling whether its key is on file, and one editor
  /// card at a time — the draft provider's row starts expanded, and Edit on
  /// another row adopts that provider (resetting the connection fields, see
  /// [_selectProvider]) and moves the card there.
  List<Widget> _models(DswAlias color) => [
    _heading(
      color,
      context.tr('settingsModels'),
      context.tr('settingsModelsIntro'),
    ),
    // `.rows` carries its own `margin-top: 12` on top of the section gap —
    // dsh calls this "extra air between the title/intro block and the first
    // provider card", 24px all told.
    const SizedBox(height: 24),
    for (final provider in LlmProvider.values) ...[
      _providerRowCard(color, provider),
      if (provider != LlmProvider.values.last) const SizedBox(height: 8),
    ],
    const SizedBox(height: 8),
    ..._savedConnectionsCard(color),
  ];

  /// The saved-provider book (ADR-0045 PF-2): the active connection can be
  /// saved into the book, and every entry can be activated (its connection
  /// becomes the active one) or deleted. Keys never render — each row shows
  /// whether one is on file.
  List<Widget> _savedConnectionsCard(DswAlias color) {
    final book = widget.settings.savedProviders;
    return [
      SettingsCard(
        dividers: true,
        children: [
          _ActionRow(
            title: context.tr('providersSaveCurrent'),
            description: context.tr('providersSaveCurrentDesc'),
            button: CapsuleButton(
              label: context.tr('providersSaveCurrent'),
              onTap: widget.onSaveCurrentToBook,
            ),
          ),
          if (book.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Text(
                context.tr('providersBookEmpty'),
                style: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
            )
          else
            for (final (index, entry) in book.indexed) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    _CredentialDot(configured: entry.isConfigured),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_providerName(context, entry.provider)} · ${entry.model}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.s14.copyWith(
                          color: color.labelPrimary,
                          fontWeight:
                              entry.id == widget.settings.activeProviderId
                              ? FontWeight.w600
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CapsuleButton(
                      label: context.tr('providersActivate'),
                      onTap: () => widget.onActivateSavedProvider(entry.id!),
                    ),
                    const SizedBox(width: 6),
                    DswIconButton(
                      icon: LucideIcons.trash,
                      tooltip: context.tr('providersDelete'),
                      onTap: () => widget.onDeleteSavedProvider(entry.id!),
                    ),
                  ],
                ),
              ),
              if (index != book.length - 1)
                dswEnsureShadTheme(
                  context,
                  ShadSeparator.horizontal(thickness: 1, color: color.borderL2),
                ),
            ],
        ],
      ),
    ];
  }

  /// `.rowCard`: outlined on the panel fill so the filled editor card it
  /// expands into reads as the nested object. dsh's `padding: 12px 14px`
  /// (vertical 12, horizontal 14), column gap 12.
  /// A `ShadCard` wearing the bridge's card skin (`borderL2` at `shell`, ADR-0029)
  /// with the page's own fill left showing through: this row is a container
  /// *inside* a section card, and a second fill would say two surfaces where
  /// there is one (§1B S6).
  Widget _providerRowCard(DswAlias color, LlmProvider provider) => ShadCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    backgroundColor: Colors.transparent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  // The dot keeps its seat, so the name is what yields: a bare
                  // Text here is handed the row's whole width and spills past it
                  // once the system amplifies text.
                  Flexible(
                    child: Text(
                      _providerName(context, provider),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.s14.copyWith(
                        color: color.labelPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_savedProvider == provider) ...[
                    const SizedBox(width: 6),
                    _CredentialDot(configured: _keyOnFile),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _RowEditButton(
              expanded: _expanded == provider,
              onTap: () {
                if (_provider != provider) {
                  _selectProvider(provider);
                  return;
                }
                // Toggling the one card the draft already edits: collapsing it
                // hides the fields, it does not throw the draft away.
                setState(
                  () => _expanded = _expanded == provider ? null : provider,
                );
              },
            ),
          ],
        ),
        if (_expanded == provider) ...[
          const SizedBox(height: 12),
          _editorCard(color, provider),
        ],
      ],
    ),
  );

  /// The provider whose connection the SAVED document carries — the row that
  /// earns a credential dot. Rows for the other providers are dormant: no
  /// dot, and Edit on them is dsh's "add" flow.
  LlmProvider get _savedProvider => widget.settings.model.provider;

  /// Whether the saved document's key field is non-empty — what the dot says.
  /// Read from the document, not the draft: the dot's question is "can this
  /// app talk to anyone yet?", and a half-typed key is not an answer to it.
  bool get _keyOnFile => widget.settings.model.apiKey.trim().isNotEmpty;

  /// The filled editor card inside the expanded row — `.editor` on
  /// `--dsw-alias-bg-module-platform`: radius 12, `padding: 14px 16px`, column
  /// gap 14, so the outlined row reads as the container and this as the
  /// object in it.
  /// The filled inner surface: `ShadCard` for the corner and the padding, and it
  /// says its own two differences from the bridge's card tier — the module fill,
  /// and no stroke, because a fill already ends where it begins (ADR-0029).
  Widget _editorCard(DswAlias color, LlmProvider provider) => ShadCard(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    backgroundColor: color.bgModulePlatform,
    border: ShadBorder.all(width: 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: context.tr('apiKey'),
          controller: _key,
          // The placeholder is the stored-state sentence dsh's editor shows:
          // a saved key needs no retyping, and the field says so instead of
          // sitting blank over a value the panel already holds.
          hint: _savedProvider == provider && _keyOnFile
              ? context.tr('keyStored')
              : 'sk-…',
          obscured: !_revealed,
          autofocus: true,
          // The one field with an affordance of its own, so it carries the
          // reveal rather than the card growing a control that applies to
          // nothing else.
          trailing: _RevealButton(
            revealed: _revealed,
            onTap: () => setState(() => _revealed = !_revealed),
          ),
        ),
        const SizedBox(height: 14),
        ShadAccordion<String>(
          controller: _disclosure,
          children: [
            ShadAccordionItem<String>(
              value: 'customized',
              // Named, because the library's own heading style is its
              // `textTheme.list` -- a second type ramp nobody mapped (ADR-0027).
              title: Text(
                context.tr('customized'),
                style: DswType.xxsStrong12.copyWith(
                  color: color.labelSecondary,
                ),
              ),
              padding: const EdgeInsets.only(top: 12, bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: context.tr('baseUrl'),
                    controller: _baseUrl,
                    // Empty means the provider's own endpoint — only the
                    // OpenAI-compatible path has a default worth hinting.
                    hint: provider == LlmProvider.openai
                        ? defaultBaseUrl
                        : context.tr('providerDefault'),
                  ),
                  const SizedBox(height: 12),
                  _Field(
                    label: context.tr('model'),
                    controller: _model,
                    hint: defaultModelFor(provider),
                    // The model id is a wire value, and reads as one.
                    code: true,
                    // The quick select over the fetched list — free text stays
                    // valid, the list is an offer, not a constraint.
                    trailing: widget.modelsFetcher == null
                        ? null
                        : _ModelPickButton(
                            models: _endpointModels,
                            onPick: (id) => setState(() => _model.text = id),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // The manual model list (ADR-0045 PG): ZCode's 模型列表 —
                  // ids the endpoint's catalog does not carry, registered by
                  // hand and persisted with the connection.
                  _ManualModelsField(
                    models: _edited.model.manualModels,
                    activeModel: _model.text.trim(),
                    onAdd: (id) async {
                      if (_edited.model.manualModels.contains(id)) return;
                      await _saveWith(
                        _edited.copyWith(
                          model: _edited.model.copyWith(
                            manualModels: [..._edited.model.manualModels, id],
                          ),
                        ),
                      );
                    },
                    onRemove: (id) async {
                      await _saveWith(
                        _edited.copyWith(
                          model: _edited.model.copyWith(
                            manualModels: [
                              for (final existing in _edited.model.manualModels)
                                if (existing != id) existing,
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // The probe row: one button, one sentence of outcome, dsh's
        // `editorActions` + inline `error` shape. Absent entirely when no
        // fetcher was wired — a test control without a network is a lie.
        if (widget.modelsFetcher != null)
          LayoutBuilder(
            builder: (context, box) {
              final status = _ModelProbeStatus(
                loading: _modelsLoading,
                error: _probeError,
                count: _probeCount,
              );
              final button = CapsuleButton(
                label: context.tr('testConnection'),
                size: CapsuleSize.sm,
                enabled: !_modelsLoading,
                onTap: _testConnection,
              );
              // The capsule is the unshrinkable half — its label is its name —
              // so the sentence keeps a floor beside it and the button drops
              // under the sentence when the card cannot hold both: measured at
              // 700px wide and 2.2x, the row spilled 16px past the card.
              final beside =
                  _oneLineWidth(context, button.label, DswType.xxs12) +
                  20 +
                  160;
              if (beside <= box.maxWidth) {
                return Row(
                  children: [
                    Expanded(child: status),
                    button,
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  status,
                  SizedBox(
                    height: 12 * MediaQuery.textScalerOf(context).scale(1),
                  ),
                  button,
                ],
              );
            },
          ),
      ],
    ),
  );

  static String _providerName(BuildContext context, LlmProvider provider) =>
      switch (provider) {
        // The OpenAI-compatible path is what a custom baseUrl is for, so the
        // label says what it accepts rather than which vendor it defaults to.
        LlmProvider.openai => context.tr('providerOpenAiCompatible'),
        LlmProvider.anthropic => context.tr('providerAnthropic'),
        LlmProvider.google => context.tr('providerGoogle'),
      };

  /// Opens the platform's directory picker and adopts whatever comes back: the
  /// field and the recent list move together, which is dsh's picker flow
  /// (picked/cancel/error) in the shape one field can carry. A dismissed picker
  /// changes nothing.
  Future<void> _pickFolder() async {
    final next = await widget.onPickFolder(_edited);
    if (next == null) return;
    setState(() {
      _workspace.text = next.workspaceRoot ?? '';
      _recent = List.of(next.recentWorkspaces);
    });
  }

  /// Adopts [path] from the recent list — the same move as picking, minus the
  /// picker.
  void _adoptRecent(String path) {
    setState(() {
      _workspace.text = path;
      _recent = [
        path,
        for (final other in _recent)
          if (other != path) other,
      ];
    });
  }

  /// Drops [path] from the recent list alone. The field keeps whatever it
  /// holds: forgetting where the user has been is not taking a permission
  /// back.
  void _forgetRecent(String path) => setState(
    () => _recent = [
      for (final other in _recent)
        if (other != path) other,
    ],
  );

  List<Widget> _workspaceSection(DswAlias color) => [
    _heading(
      color,
      context.tr('settingsWorkspace'),
      context.tr('settingsWorkspaceIntro'),
    ),
    const SizedBox(height: 12),
    _Field(
      label: context.tr('folder'),
      controller: _workspace,
      hint: '~/projects/my-app',
      autofocus: true,
      code: true,
      trailing: CapsuleButton(label: context.tr('choose'), onTap: _pickFolder),
    ),
    const SizedBox(height: 12),
    _RecentWorkspaces(
      paths: _recent,
      current: _workspace.text.trim(),
      missing: _workspaceMissing,
      onAdopt: _adoptRecent,
      onForget: _forgetRecent,
    ),
  ];

  /// Workbench: the side card's preferences — the terminal's own face, and
  /// which tab types the `+` menu offers. Committed on the spot; there is no
  /// Save for any of this, and none is needed.
  List<Widget> _workbenchSection(DswAlias color) {
    final prefs = widget.workbenchPrefs;
    return [
      _heading(
        color,
        context.tr('terminal'),
        context.tr('settingsTerminalIntro'),
      ),
      const SizedBox(height: 12),
      _Field(
        label: context.tr('fontFamily'),
        controller: _fontFamily,
        hint: context.tr('fontFamilyHint'),
        code: true,
        focusNode: _fontFamilyFocus,
        onSubmitted: (_) => _commitFontFamily(),
      ),
      const SizedBox(height: 12),
      _Stepper(
        label: context.tr('fontSize'),
        value: prefs.terminalFontSize,
        min: terminalFontSizeMin,
        max: terminalFontSizeMax,
        onChanged: (size) =>
            widget.onPrefsChange?.call(prefs.copyWith(terminalFontSize: size)),
      ),
      const SizedBox(height: 12),
      _SwitchRow(
        label: context.tr('seedBottomPanel'),
        description: context.tr('seedBottomPanelDesc'),
        value: prefs.bottomPanelAutoTerminal,
        onChanged: (value) => widget.onPrefsChange?.call(
          prefs.copyWith(bottomPanelAutoTerminal: value),
        ),
      ),
      const SizedBox(height: 28),
      _heading(color, context.tr('tabs'), context.tr('settingsTabsIntro')),
      const SizedBox(height: 12),
      _SwitchRow(
        label: context.tr('explorer'),
        description: context.tr('explorerDesc'),
        value: prefs.tabEnabled('explorer'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('explorer', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: context.tr('terminal'),
        description: context.tr('terminalDesc'),
        value: prefs.tabEnabled('terminal'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('terminal', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: context.tr('git'),
        description: context.tr('gitDesc'),
        value: prefs.tabEnabled('git'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('git', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: context.tr('subagents'),
        description: context.tr('subagentsDesc'),
        value: prefs.tabEnabled('subagent'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('subagent', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: context.tr('browser'),
        description: context.tr('browserDesc'),
        value: prefs.tabEnabled('browser'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('browser', value)),
      ),
      const SizedBox(height: 8),
      _SwitchRow(
        label: context.tr('sidechat'),
        description: context.tr('sideChatDesc'),
        value: prefs.tabEnabled('sidechat'),
        onChanged: (value) =>
            widget.onPrefsChange?.call(prefs.withTabEnabled('sidechat', value)),
      ),
    ];
  }

  List<Widget> _extensionsSection(DswAlias color) => [
    _heading(
      color,
      context.tr('settingsMcpServers'),
      context.tr('settingsMcpIntro'),
    ),
    const SizedBox(height: 12),
    for (final draft in List<_ServerDraft>.of(_servers)) ...[
      _serverCard(color, draft),
      const SizedBox(height: 8),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: CapsuleButton(label: context.tr('addServer'), onTap: _addServer),
    ),
    const SizedBox(height: 28),
    _heading(
      color,
      context.tr('settingsSkills'),
      context.tr('settingsSkillsIntro'),
    ),
    const SizedBox(height: 12),
    _Field(
      label: context.tr('folder'),
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
        context.tr('approvalsTitle'),
        context.tr('approvalsNote'),
      ),
      const SizedBox(height: 12),
      if (rules.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: Text(
            context.tr('approvalsEmpty'),
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
                    ? context.tr('approvalAllowed')
                    : context.tr('approvalDenied'),
                button: CapsuleButton(
                  label: context.tr('forget'),
                  onTap: () => store.forget(rule),
                ),
              ),
            _ActionRow(
              title: context.tr('forgetWorkspaceApprovals'),
              description: context.tr('approvalsNote'),
              button: CapsuleButton(
                label: context.tr('forget'),
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
        context.tr('settingsShortcuts'),
        context.tr('settingsShortcutsIntro'),
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
                      context.tr(command.labelKey),
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
        context.tr('settingsUsage'),
        context.tr('settingsUsageIntro'),
      ),
      const SizedBox(height: 12),
      SettingsCard(
        dividers: true,
        children: [
          _UsageStatRow(
            label: context.tr('usageTurns'),
            value: '${summary.turns}',
          ),
          _UsageStatRow(
            label: context.tr('usageTotalTokens'),
            value: '${summary.totalTokens}',
          ),
          _UsageStatRow(
            label: context.tr('usageErrorRate'),
            value: '${(summary.errorRate * 100).toStringAsFixed(1)}%',
          ),
          if (widget.crashFiles != null)
            _ActionRow(
              title: context.tr('usageCrashLogTitle'),
              description: context.tr('usageCrashLogDesc'),
              button: CapsuleButton(
                label: context.tr('usageCrashLogOpen'),
                onTap: widget.onOpenCrashLog ?? () {},
              ),
              last: true,
            ),
        ],
      ),
    ];
  }

  List<Widget> _backupSection(DswAlias color) => [
    _heading(
      color,
      context.tr('settingsBackup'),
      context.tr('settingsBackupIntro'),
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        _ActionRow(
          title: context.tr('backupCreate'),
          description: context.tr('backupCreateDesc'),
          button: CapsuleButton(
            label: context.tr('backupExport'),
            onTap: _createBackup,
          ),
        ),
        _ActionRow(
          title: context.tr('backupRestore'),
          description: context.tr('backupRestoreDesc'),
          button: CapsuleButton(
            label: context.tr('backupImport'),
            onTap: _restoreBackup,
          ),
        ),
        _ActionRow(
          title: context.tr('settingsReset'),
          description: context.tr('settingsResetDesc'),
          button: CapsuleButton(
            label: context.tr('settingsReset'),
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
      title: context.tr('settingsResetConfirmTitle'),
      description: context.tr('settingsResetConfirmBody'),
      confirmLabel: context.tr('settingsReset'),
    );
    if (!confirmed || !mounted) return;
    await widget.onReset();
    if (!mounted) return;
    showFeedback(context, context.tr('settingsResetDone'));
  }

  Future<void> _createBackup() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: context.tr('backupExport'),
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
        context.tr('backupCreated').replaceAll('{count}', '$count'),
      );
    } catch (e) {
      if (!mounted) return;
      showFeedback(
        context,
        '${context.tr('backupFailed')}: $e',
        destructive: true,
      );
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: context.tr('backupImport'),
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
        context.tr('backupRestored').replaceAll('{count}', '$count'),
      );
    } catch (e) {
      if (!mounted) return;
      showFeedback(
        context,
        '${context.tr('backupFailed')}: $e',
        destructive: true,
      );
    }
  }

  /// One server, as a bordered card of four fields plus its remove button.
  /// Args are space-separated here and split at commit — the field is a
  /// single line either way.
  /// Exactly the tier the bridge answers for a card, so nothing is restated here.
  Widget _serverCard(DswAlias color, _ServerDraft draft) => ShadCard(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Field(
                label: context.tr('serverName'),
                controller: draft.name,
                hint: 'fs',
                code: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: context.tr('arguments'),
                controller: draft.args,
                hint: '-y @modelcontextprotocol/server-filesystem',
                code: true,
              ),
            ),
            const SizedBox(width: 6),
            DswIconButton.destructive(
              icon: LucideIcons.x,
              tooltip: context.tr('removeServer'),
              onTap: () => _removeServer(draft),
              size: 28,
              iconSize: DswShape.iconMd,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Field(
          label: context.tr('commandStdio'),
          controller: draft.command,
          hint: 'npx',
          code: true,
        ),
        const SizedBox(height: 12),
        _Field(
          label: context.tr('urlHttp'),
          controller: draft.url,
          hint: 'https://example.test/mcp',
          code: true,
        ),
      ],
    ),
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

/// dsh's own `LanguageRow`/`AppearanceRow` selectors take. A bordered box
/// here would read as one of the form inputs, which a preference is not.
class _SettingCellRow<T> extends StatelessWidget {
  const _SettingCellRow({
    required this.title,
    required this.description,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.leading,
    this.last = false,
  });

  final String title;
  final String description;

  /// The option labels, keyed by the value the menu commits.
  final Map<T, String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  /// An optional icon painted in `labelTertiary` to the left of the text —
  /// echoes the nav's icon language so each row self-describes.
  final IconData? leading;

  /// Whether the hairline separator is drawn. The section sets it on its
  /// last row; dsh's column strips it there (`:last-child { border: none }`).
  final bool last;

  /// The hover wash used to be this widget's own `State` plus a `MouseRegion`;
  /// [DswSelect] reports the pointer instead, so the row is stateless again.
  Widget _menu(DswAlias color) => DswSelect<T>(
    value: value,
    onChanged: (picked) {
      if (picked != null) onChanged(picked);
    },
    popupMinWidth: 160,
    options: (context, close) => [
      for (final entry in labels.entries)
        ShadOption<T>(value: entry.key, child: Text(entry.value)),
    ],
    trigger: (context, selected, hovered) => AnimatedContainer(
      duration: DswMotion.respecting(context, DswMotion.fast),
      // One line of chrome, so the seat follows the text step: 36 gave
      // this row's 14/22 label 36.0 where 40.0 was needed at 1.8x. A floor
      // rather than a height because the label takes a second line only when
      // even the whole card cannot hold it on one (2.2x in a 430px card).
      constraints: BoxConstraints(
        minHeight: 36 * MediaQuery.textScalerOf(context).scale(1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: hovered ? color.interactiveBgHover : color.bgModulePlatform,
        borderRadius: BorderRadius.circular(DswShape.float),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              labels[value]!,
              style: DswType.s14.copyWith(color: color.labelPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            LucideIcons.chevron_down,
            size: DswShape.iconSm,
            color: color.labelTertiary,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final titleStyle = DswType.s14.copyWith(color: color.labelPrimary);
    final leadingCells = <Widget>[
      if (leading != null) ...[
        Icon(leading, size: DswShape.iconMd, color: color.labelTertiary),
        const SizedBox(width: 12),
      ],
    ];
    final text = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 4),
          Text(
            description,
            style: DswType.xxs12.copyWith(color: color.labelTertiary),
          ),
        ],
      ),
    );
    // The pill is the unshrinkable half: its one-word value is the preference
    // itself, and a squeezed pill reads as a form input. In a 700px window at
    // 2.2x the row form gave the title column 0.0px and spilled 64px past the
    // card, so under one line of room for title plus pill the pill moves
    // below the label instead.
    final beside =
        (leading == null ? 0.0 : 28.0) +
        _oneLineWidth(context, title, titleStyle) +
        8 +
        _oneLineWidth(context, labels[value]!, titleStyle) +
        12 +
        14 +
        28;
    // The line under every row but the last is the library's separator rather
    // than a border on the row's own box: a section is a column of rows with a
    // line *between* them, which is what `ShadSeparator` is for (§1B S7).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LayoutBuilder(
            builder: (context, box) {
              if (beside <= box.maxWidth) {
                return Row(
                  children: [
                    ...leadingCells,
                    text,
                    const SizedBox(width: 8),
                    _menu(color),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [...leadingCells, text]),
                  SizedBox(
                    height: 12 * MediaQuery.textScalerOf(context).scale(1),
                  ),
                  _menu(color),
                ],
              );
            },
          ),
        ),
        if (!last) ShadSeparator.horizontal(color: color.borderL2),
      ],
    );
  }
}

/// The recent-workspaces list — dsh's picker menu flattened into the section:
/// each row adopts on click, forgets on its trailing button, and says so when
/// its folder has gone missing on disk.
class _RecentWorkspaces extends StatelessWidget {
  const _RecentWorkspaces({
    required this.paths,
    required this.current,
    required this.missing,
    required this.onAdopt,
    required this.onForget,
  });

  final List<String> paths;
  final String current;
  final bool missing;
  final ValueChanged<String> onAdopt;
  final ValueChanged<String> onForget;

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();
    final color = context.dsw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('recent'),
          style: DswType.xxs12.copyWith(color: color.labelSecondary),
        ),
        const SizedBox(height: 6),
        for (final path in paths)
          _RecentRow(
            path: path,
            current: path == current,
            missing: !Directory(path).existsSync(),
            onAdopt: () => onAdopt(path),
            onForget: () => onForget(path),
          ),
        // The typed-path warning rides below the list rather than beside the
        // field: it describes the same document the recents do, and a field
        // with two trailing affordances reads as two decisions.
        if (missing) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                LucideIcons.circle_alert,
                size: DswShape.iconSm,
                color: color.stateWarnPrimary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  context.tr('folderNotOnDisk'),
                  style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One recent-workspace row: folder glyph, the path in the code face, adopt on
/// click, forget on the trailing button. The current workspace is marked with
/// the interactive wash rather than a check — the row IS the choice.
class _RecentRow extends StatefulWidget {
  const _RecentRow({
    required this.path,
    required this.current,
    required this.missing,
    required this.onAdopt,
    required this.onForget,
  });

  final String path;
  final bool current;
  final bool missing;
  final VoidCallback onAdopt;
  final VoidCallback onForget;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // The row adopts the folder; its accessible name is the path itself, so the
    // visible text is left as the label. The forget button is a nested action and
    // is kept out of the row's name.
    return DswHoverTap(
      onTap: widget.missing ? null : widget.onAdopt,
      toggled: widget.current ? true : null,
      builder: (context, hovered, _) => _body(color, hovered),
    );
  }

  Widget _body(DswAlias color, bool hovered) => Container(
    height: 32,
    padding: const EdgeInsets.only(left: 8, right: 4),
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      color: widget.current
          ? color.interactiveBgActive
          : hovered
          ? color.interactiveBgHover
          : Colors.transparent,
      borderRadius: BorderRadius.circular(DswShape.control),
    ),
    child: Row(
      children: [
        Icon(
          LucideIcons.folder,
          size: DswShape.iconSm,
          // A dead folder keeps its seat but wears the caption tint: the row
          // still explains where the user has been.
          color: widget.missing ? color.labelCaption : color.labelSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xxs12.copyWith(
              color: widget.missing ? color.labelCaption : color.labelPrimary,
              fontFamily: dswFontFamilyCode,
              fontFamilyFallback: dswFontFamilyCodeFallback,
            ),
          ),
        ),
        if (widget.missing)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              context.tr('missing'),
              style: DswType.xxxs11.copyWith(color: color.stateWarnLabel),
            ),
          ),
        if (hovered)
          DswIconButton(
            icon: LucideIcons.x,
            tooltip: context.tr('forget'),
            onTap: widget.onForget,
            size: 20,
            iconSize: DswShape.iconTiny,
          ),
      ],
    ),
  );
}

/// One row of the nav's filterable list — the section it points at, the label
/// the search matches against, and the icon the cell paints.
class _NavItem {
  const _NavItem(this.section, this.label, this.icon);
  final _Section section;
  final String label;
  final IconData icon;
}

/// The nav's search field — one `ShadInput`, whose frame is the one the bridge
/// gives every field and whose glyph sits in the library's own `leading` slot
/// (`input.dart:112`). It used to be a hand-drawn box around a borderless field,
/// which is the same question answered twice on one surface (§1B S5): the row
/// comment even said "the row's hairline is the frame", while a field is allowed
/// to have a frame of its own.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ShadInput(
      // Named, so a test can tell this field from the ones under it: it sits
      // above every section and is a `ShadInput` like they are.
      key: const ValueKey('settings-search'),
      controller: controller,
      style: DswType.s14.copyWith(color: color.labelPrimary),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8, right: 6),
        child: Icon(
          LucideIcons.search,
          size: DswShape.iconSm,
          color: color.labelTertiary,
        ),
      ),
      // The seat is the text line plus this gutter; the box then *is* 32 at the
      // designed step instead of being nailed to it, which is what let the old
      // hand-drawn frame hide a field that overflowed its own row.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      placeholder: dswInputHint(hint),
      placeholderStyle: DswType.s14.copyWith(color: color.labelDimmed),
    );
  }
}

/// `.navCell`: 40px, radius 12, asymmetric padding, the sidebar nav item's three
/// states.
class _NavCell extends StatefulWidget {
  const _NavCell({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // The nav's visible label is its accessible name, so excludeSemantics stays
    // off and the selected section is announced as a toggled state.
    return DswHoverTap(
      onTap: widget.onTap,
      toggled: widget.active ? true : null,
      builder: (context, hovered, _) => AnimatedContainer(
        duration: DswMotion.respecting(context, DswMotion.fast),
        // One line of nav, so the seat rides the text step: pinned at 40 the
        // label wanted 48.0 in it at the system's 1.8x and above.
        height: 40 * MediaQuery.textScalerOf(context).scale(1),
        padding: const EdgeInsets.only(left: 12, right: 16),
        decoration: BoxDecoration(
          color: widget.active
              ? color.sidebarNavItemActive
              : hovered
              ? color.sidebarNavItemHover
              : null,
          borderRadius: BorderRadius.circular(DswShape.shell),
          // The accent bar: a 3px pill on the leading edge when selected.
          border: widget.active
              ? Border(
                  left: BorderSide(color: color.stateBusinessPrimary, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: DswShape.iconMd,
              color: widget.active ? color.brandPrimary : color.labelSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.s14.copyWith(
                  color: widget.active
                      ? color.labelPrimary
                      : color.labelPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `.field` + `.input`: a 12/18 label over a 32px box, radius 8, `border-l2`
/// resting and the brand colour on focus.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscured = false,
    this.autofocus = false,
    this.code = false,
    this.trailing,
    this.focusNode,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscured;
  final bool autofocus;

  /// Renders the value in the code face, for fields holding a wire identifier or
  /// a path rather than prose.
  final bool code;

  final Widget? trailing;

  /// For fields that commit on their own cadence rather than the panel's Save.
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    var style = DswType.s14.copyWith(color: color.labelPrimary);
    if (code) {
      style = style.copyWith(
        fontFamily: dswFontFamilyCode,
        fontFamilyFallback: dswFontFamilyCodeFallback,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
        ),
        const SizedBox(height: 6),
        // ADR-0002 Stage 5c: the field box is shad's own input (coloured through
        // the dsw bridge) rather than a hand-rolled Material decoration, and the
        // trailing action rides ShadInput's own slot instead of a sibling in a
        // Row.
        ShadInput(
          controller: controller,
          autofocus: autofocus,
          focusNode: focusNode,
          onSubmitted: onSubmitted,
          obscureText: obscured,
          // A key and a path are both single-line values that must not be
          // "helpfully" capitalised or corrected.
          autocorrect: false,
          enableSuggestions: false,
          style: style,
          placeholder: Text(
            hint,
            // A placeholder is one line, as it is on the web: at the system's
            // larger text steps a wrapping hint either grew the field or was cut
            // mid-word, and neither says what the field wants.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: color.labelDimmed),
          ),
          trailing: trailing,
        ),
      ],
    );
  }
}

/// A label, a one-line description, and a switch — the side card's row shape.
///
/// The switch is shad's (ADR-0036 row 25), which settles the three things the
/// drawn one had to answer for itself: it takes Enter and Space, it announces
/// `toggled`, and a disabled one dims through `ShadDisabled` rather than a
/// hand-picked opacity. `direction: rtl` is what keeps the reading order this
/// panel has everywhere else — text first, control last.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ShadSwitch(
      value: value,
      onChanged: (_) => onChanged(!value),
      direction: TextDirection.rtl,
      label: Text(
        label,
        style: DswType.xxs12.copyWith(color: color.labelSecondary),
      ),
      sublabel: Text(
        description,
        style: DswType.xxxs11.copyWith(color: color.labelTertiary),
      ),
      // The only colour the theme cannot hold: shad has ONE thumb constant, and
      // this design says an off thumb is quiet (`labelTertiary`) and an on thumb
      // is the foreground (`labelPrimaryForeground`). A single value in the
      // bridge would answer the state question with one of the two, so the state
      // goes where the state is known — and the tracks stay themed.
      thumbColor: value ? color.labelPrimaryForeground : color.labelTertiary,
    );
  }
}

/// A label over a minus/plus stepper capped to [min]/[max] — the font size
/// control, whose whole range is 24 integers and deserves no free-form field.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            DswIconButton.outlined(
              icon: LucideIcons.minus,
              tooltip: context.tr('decrease'),
              onTap: value > min ? () => onChanged(value - 1) : null,
              size: 28,
              iconSize: DswShape.iconSm,
            ),
            SizedBox(
              // A one-line readout, so both of its dimensions ride the text
              // step: 40x32 wrapped "13" onto two clipped lines at 1.8x.
              width: 40 * MediaQuery.textScalerOf(context).scale(1),
              height: 32 * MediaQuery.textScalerOf(context).scale(1),
              child: Center(
                child: Text(
                  '$value',
                  maxLines: 1,
                  style: DswType.s14.copyWith(
                    color: color.labelPrimary,
                    fontFamily: dswFontFamilyCode,
                    fontFamilyFallback: dswFontFamilyCodeFallback,
                  ),
                ),
              ),
            ),
            DswIconButton.outlined(
              icon: LucideIcons.plus,
              tooltip: context.tr('increase'),
              onTap: value < max ? () => onChanged(value + 1) : null,
              size: 28,
              iconSize: DswShape.iconSm,
            ),
          ],
        ),
      ],
    );
  }
}

/// The key field's reveal. It is the one affordance that belongs to the field
/// rather than the card around it, so it rides `ShadInput.trailing` — and its
/// body is the shared icon control (ADR-0024), which is what says a press, a Tab
/// stop and the accessible name all arrive together.
class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DswIconButton(
      icon: revealed ? LucideIcons.eye_off : LucideIcons.eye,
      tooltip: revealed ? context.tr('hideKey') : context.tr('showKey'),
      onTap: onTap,
      size: 28,
      iconSize: DswShape.iconMd,
    );
  }
}

/// `.credentialDot` + its two fills: the row's stored-key state, as one 8px
/// circle. Unlabelled by design — the tooltip carries the sentence, the dot
/// carries only the colour, the way dsh's does.
class _CredentialDot extends StatelessWidget {
  const _CredentialDot({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: configured
          ? context.tr('keyConfigured')
          : context.tr('keyMissing'),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: configured
              ? color.stateSuccessPrimary
              : color.stateErrorPrimary,
        ),
      ),
    );
  }
}

/// The provider row's trailing control: the same small outline capsule the rest
/// of this page uses for a labelled action (保存, 添加服务器, 测试连接), because a
/// second spelling of "small bordered button" in the same panel is the
/// inconsistency the screenshot was filed for (ADR-0036 §1B S4). Its body is
/// shad's `ShadButton` already, so keyboard, focus and the disabled dimming come
/// from there. The label flips to "Close" on the row whose card is open, since
/// that is what the tap then does.
class _RowEditButton extends StatelessWidget {
  const _RowEditButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CapsuleButton(
    label: expanded ? context.tr('close') : context.tr('edit'),
    onTap: onTap,
    size: CapsuleSize.sm,
  );
}

/// The model field's quick-select: the `_RevealButton` box shape opening a
/// menu of the endpoint's fetched ids. Disabled until a fetch has landed — a
/// menu with nothing to offer is a control that lies about being one.
class _ModelPickButton extends StatelessWidget {
  const _ModelPickButton({required this.models, required this.onPick});

  final List<String> models;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = models.isNotEmpty;
    return DswSelect<String>(
      // Nothing is ever selected here: the box is a way in, not a value, so the
      // trigger is always the placeholder branch.
      value: null,
      onChanged: (id) {
        if (id != null) onPick(id);
      },
      enabled: enabled,
      label: enabled
          ? context.tr('chooseModel')
          : context.tr('noModelsFetched'),
      popupMinWidth: 260,
      maxHeight: 320,
      options: (context, close) => [
        for (final id in models)
          ShadOption<String>(
            value: id,
            child: Text(
              id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(
                color: color.labelPrimary,
                fontFamily: dswFontFamilyCode,
                fontFamilyFallback: dswFontFamilyCodeFallback,
              ),
            ),
          ),
      ],
      trigger: (context, selected, hovered) => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Icon(
          LucideIcons.list,
          size: DswShape.iconMd,
          color: enabled ? color.labelTertiary : color.labelDimmed,
        ),
      ),
    );
  }
}

/// The probe's one sentence: fetching, the count, or the failure — the
/// status line dsh's editor paints between its fields and its actions.
class _ModelProbeStatus extends StatelessWidget {
  const _ModelProbeStatus({
    required this.loading,
    required this.error,
    required this.count,
  });

  final bool loading;
  final String? error;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (loading) {
      return Text(
        context.tr('fetchingModels'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xxs12.copyWith(color: color.labelTertiary),
      );
    }
    if (error != null) {
      return Row(
        children: [
          Icon(
            LucideIcons.circle_alert,
            size: DswShape.iconSm,
            color: color.stateErrorPrimary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xxs12.copyWith(color: color.stateErrorPrimary),
            ),
          ),
        ],
      );
    }
    if (count != null) {
      return Text(
        context.tr('connectionOk').replaceAll('{n}', '$count'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xxs12.copyWith(color: color.stateSuccessPrimary),
      );
    }
    return const SizedBox.shrink();
  }
}

/// One MCP server row under edit. Holds its own controllers so rows can be
/// added and removed without rebuilding the others, and so dispose walks
/// exactly the rows that still exist.
class _ServerDraft {
  _ServerDraft();

  factory _ServerDraft.of(McpServerConfig server) {
    final draft = _ServerDraft();
    draft.name.text = server.name;
    draft.command.text = server.command ?? '';
    draft.url.text = server.url ?? '';
    draft.args.text = server.args.join(' ');
    return draft;
  }

  final name = TextEditingController();
  final command = TextEditingController();
  final url = TextEditingController();

  /// Space-separated on screen, since the common case is a short flag list;
  /// split at commit.
  final args = TextEditingController();

  List<TextEditingController> get controllers => [name, command, url, args];

  /// Null when the row cannot yield a server — no name, or neither a command
  /// nor a URL. Commit drops the row rather than the panel refusing the field,
  /// the same repair-not-reject contract a corrupt entry gets at load.
  McpServerConfig? asConfig() {
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) return null;
    final commandText = command.text.trim();
    final urlText = url.text.trim();
    if (commandText.isEmpty && urlText.isEmpty) return null;
    return McpServerConfig(
      name: trimmed,
      command: commandText.isEmpty ? null : commandText,
      args: [
        for (final arg in args.text.split(RegExp(r'\s+')))
          if (arg.isNotEmpty) arg,
      ],
      url: urlText.isEmpty ? null : urlText,
    );
  }
}

/// The trailing X on a server card: the `_RevealButton` shape with a
/// destructive glyph, since removing a row is the one destructive action the
/// panel can take.
/// A settings row with a title, description, and a trailing action button.
/// Used by the backup section for export/import actions.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.description,
    required this.button,
    this.last = false,
  });

  final String title;
  final String description;
  final Widget button;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DswType.xxs12.copyWith(color: color.labelSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          button,
        ],
      ),
    );
  }
}

/// One label/value row of the usage section — the twin of `_Field`-style
/// rows elsewhere in this file, kept separate so the usage data shape never
/// grows settings semantics.
class _UsageStatRow extends StatelessWidget {
  const _UsageStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DswType.s14.copyWith(color: color.labelSecondary),
            ),
          ),
          Text(
            value,
            style: DswType.sStrong14.copyWith(color: color.labelPrimary),
          ),
        ],
      ),
    );
  }
}

/// The manual model list (ADR-0045 PG): one input row to register an id and
/// one row per registered id with a remove affordance — ZCode's 模型列表
/// shape at its smallest honest size. The add input commits on submit; a
/// duplicate id is a silent no-op (the list already shows it).
class _ManualModelsField extends StatelessWidget {
  const _ManualModelsField({
    required this.models,
    required this.activeModel,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> models;
  final String activeModel;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final controller = TextEditingController();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr('modelsListLabel'),
                style: DswType.xs13.copyWith(color: color.labelSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final id in models)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DswShape.sm,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.bgLayer2,
                      borderRadius: BorderRadius.circular(DswShape.inner),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DswType.xs13.copyWith(
                              color: color.labelPrimary,
                            ),
                          ),
                        ),
                        if (id == activeModel) ...[
                          const SizedBox(width: 6),
                          Text(
                            context.tr('modelsActiveTag'),
                            style: DswType.xs13.copyWith(
                              color: color.labelTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                DswIconButton(
                  icon: LucideIcons.x,
                  tooltip: context.tr('modelsRemove'),
                  onTap: () => onRemove(id),
                ),
              ],
            ),
          ),
        dswEnsureShadTheme(
          context,
          ShadInput(
            controller: controller,
            placeholder: dswInputHint(
              context.tr('modelsAddHint'),
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            style: DswType.xs13,
            onSubmitted: (id) {
              final trimmed = id.trim();
              if (trimmed.isNotEmpty) onAdd(trimmed);
              controller.clear();
            },
          ),
        ),
      ],
    );
  }
}
