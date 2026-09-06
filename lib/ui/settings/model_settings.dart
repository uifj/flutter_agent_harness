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
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';

import '../../genkit/models_endpoint.dart';
import '../../l10n/locales.dart';
import '../../model/app_settings.dart' hide ThemeMode;
import '../../model/app_settings.dart' as settings;
import '../../model/mcp_settings.dart';
import '../../model/model_settings.dart';
import '../../model/workbench_prefs.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';

/// Which section the rail is pointing at.
enum _Section { general, models, workspace, workbench, extensions }

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSave,
    required this.onClose,
    required this.onPickFolder,
    this.workbenchPrefs = const WorkbenchPrefs(),
    this.onPrefsChange,
    this.modelsFetcher,
  });

  final AppSettings settings;

  /// Commits the edited document. Awaited, so the panel can report the outcome
  /// rather than closing on faith.
  final Future<void> Function(AppSettings next) onSave;

  final VoidCallback onClose;

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

  /// The "Customized" disclosure inside the editor card. Collapsed by
  /// default, like dsh's `<details>`: a key is the field that decides whether
  /// the connection works at all; the endpoint and the model id are the
  /// fields a working default already answers.
  bool _customizedOpen = false;

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

  /// The recents as the picker will edit them. Tracked here rather than derived
  /// from [widget.settings] so an "adopted" folder survives a later cancel: the
  /// recent list is a history, not a permission, and history does not roll
  /// back with the form.
  late List<String> _recent = List.of(widget.settings.recentWorkspaces);

  _Section _section = _Section.general;

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
    final controllers = [
      _key,
      _baseUrl,
      _model,
      _workspace,
      _skills,
      ..._servers.expand((draft) => draft.controllers),
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
    final baseUrl =
        _baseUrl.text.trim().isEmpty ? defaultBaseUrlFor(_provider)
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
      _customizedOpen = false;
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
    );
  }

  bool get _dirty => _edited != widget.settings;

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
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: _close,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: DswShadow.maskBlurSigma,
                  sigmaY: DswShadow.maskBlurSigma,
                ),
                child: ColoredBox(color: color.bgMask1),
              ),
            ),
            _panel(color),
          ],
        ),
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

  Widget _panel(DswAlias color) => LayoutBuilder(
    builder: (context, constraints) => Container(
      width: 800,
      height: constraints.maxHeight.clamp(0.0, 800.0) - 48,
      constraints: BoxConstraints(maxWidth: constraints.maxWidth - 48),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(24),
        boxShadow: DswShadow.lv3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _nav(color),
          Expanded(child: _content(color)),
        ],
      ),
    ),
  );

  Widget _nav(DswAlias color) => SizedBox(
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
          const SizedBox(height: 18),
          _NavCell(
            label: context.tr('settingsGeneral'),
            icon: LucideIcons.settings,
            active: _section == _Section.general,
            onTap: () => setState(() => _section = _Section.general),
          ),
          const SizedBox(height: 4),
          _NavCell(
            label: context.tr('settingsModels'),
            icon: LucideIcons.network,
            active: _section == _Section.models,
            onTap: () => setState(() => _section = _Section.models),
          ),
          const SizedBox(height: 4),
          _NavCell(
            label: context.tr('settingsWorkspace'),
            icon: LucideIcons.folder_open,
            active: _section == _Section.workspace,
            onTap: () => setState(() => _section = _Section.workspace),
          ),
          const SizedBox(height: 4),
          _NavCell(
            label: context.tr('settingsWorkbench'),
            icon: LucideIcons.columns_2,
            active: _section == _Section.workbench,
            onTap: () => setState(() => _section = _Section.workbench),
          ),
          const SizedBox(height: 4),
          _NavCell(
            label: context.tr('settingsExtensions'),
            icon: LucideIcons.puzzle,
            active: _section == _Section.extensions,
            onTap: () => setState(() => _section = _Section.extensions),
          ),
        ],
      ),
    ),
  );

  Widget _content(DswAlias color) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 54,
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
              _CloseButton(onTap: _close),
            ],
          ),
        ),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: ConstrainedBox(
            // `.section` caps at 720 so a 32px field never stretches to a width
            // no value in it would ever reach.
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...switch (_section) {
                  _Section.general => _general(color),
                  _Section.models => _models(color),
                  _Section.workspace => _workspaceSection(color),
                  _Section.workbench => _workbenchSection(color),
                  _Section.extensions => _extensionsSection(color),
                },
              ],
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
    _SettingCellRow(
      title: context.tr('theme'),
      description: context.tr('themeDesc'),
      labels: {
        settings.ThemeMode.system: context.tr('followSystem'),
        settings.ThemeMode.light: context.tr('light'),
        settings.ThemeMode.dark: context.tr('dark'),
      },
      value: _theme,
      onChanged: (mode) => setState(() => _theme = mode),
    ),
    _SettingCellRow(
      title: context.tr('language'),
      description: context.tr('languageDesc'),
      labels: {
        settings.LocaleMode.system: context.tr('followSystem'),
        settings.LocaleMode.en: 'English',
        settings.LocaleMode.zh: '中文',
      },
      value: _locale,
      onChanged: (mode) => setState(() => _locale = mode),
      last: true,
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
  ];

  /// `.rowCard`: outlined on the panel fill so the filled editor card it
  /// expands into reads as the nested object. dsh's `padding: 12px 14px`
  /// (vertical 12, horizontal 14), column gap 12.
  Widget _providerRowCard(DswAlias color, LlmProvider provider) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.borderL2),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    _providerName(context, provider),
                    style: DswType.s14.copyWith(
                      color: color.labelPrimary,
                      fontWeight: FontWeight.w500,
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
                    () => _expanded = _expanded == provider ? null : provider);
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
  Widget _editorCard(DswAlias color, LlmProvider provider) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: color.bgModulePlatform,
      borderRadius: BorderRadius.circular(12),
    ),
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
        _CustomizedDisclosure(
          open: _customizedOpen,
          onToggle: () => setState(() => _customizedOpen = !_customizedOpen),
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
            ],
          ),
        ),
        const SizedBox(height: 14),
        // The probe row: one button, one sentence of outcome, dsh's
        // `editorActions` + inline `error` shape. Absent entirely when no
        // fetcher was wired — a test control without a network is a lie.
        if (widget.modelsFetcher != null)
          Row(
            children: [
              Expanded(
                child: _ModelProbeStatus(
                  loading: _modelsLoading,
                  error: _probeError,
                  count: _probeCount,
                ),
              ),
              CapsuleButton(
                label: context.tr('testConnection'),
                size: CapsuleSize.sm,
                enabled: !_modelsLoading,
                onTap: _testConnection,
              ),
            ],
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
      hint: '/Users/you/project',
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
      hint: '/Users/you/.dsh/skills',
      code: true,
    ),
  ];

  /// One server, as a bordered card of four fields plus its remove button.
  /// Args are space-separated here and split at commit — the field is a
  /// single line either way.
  Widget _serverCard(DswAlias color, _ServerDraft draft) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    decoration: BoxDecoration(
      color: color.bgLayer1,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.borderL2),
    ),
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
            _RemoveButton(onTap: () => _removeServer(draft)),
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
/// dsh's own `LanguageRow`/`AppearanceRow` selectors take. A bordered box
/// here would read as one of the form inputs, which a preference is not.
class _SettingCellRow<T> extends StatefulWidget {
  const _SettingCellRow({
    required this.title,
    required this.description,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String description;

  /// The option labels, keyed by the value the menu commits.
  final Map<T, String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  /// Whether the hairline separator is drawn. The section sets it on its
  /// last row; dsh's column strips it there (`:last-child { border: none }`).
  final bool last;

  @override
  State<_SettingCellRow<T>> createState() => _SettingCellRowState<T>();
}

class _SettingCellRowState<T> extends State<_SettingCellRow<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: color.borderL2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: DswType.s14.copyWith(color: color.labelPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.description,
                  style: DswType.xxs12.copyWith(color: color.labelTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<T>(
            position: PopupMenuPosition.under,
            constraints: const BoxConstraints(minWidth: 160),
            initialValue: widget.value,
            onSelected: widget.onChanged,
            itemBuilder: (context) => [
              for (final entry in widget.labels.entries)
                PopupMenuItem(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    style: DswType.xs13.copyWith(color: color.labelPrimary),
                  ),
                ),
            ],
            child: MouseRegion(
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: AnimatedContainer(
                duration: DswMotion.respecting(context, DswMotion.fast),
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _hovered
                      ? color.interactiveBgHover
                      : color.bgModulePlatform,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.labels[widget.value]!,
                      style: DswType.s14.copyWith(color: color.labelPrimary),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      LucideIcons.chevron_down,
                      size: 14,
                      color: color.labelTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                size: 13,
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.missing ? null : widget.onAdopt,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 8, right: 4),
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            color: widget.current
                ? color.interactiveBgActive
                : _hovered
                ? color.interactiveBgHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.folder,
                size: 14,
                // A dead folder keeps its seat but wears the caption tint: the
                // row still explains where the user has been.
                color: widget.missing
                    ? color.labelCaption
                    : color.labelSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.xxs12.copyWith(
                    color: widget.missing
                        ? color.labelCaption
                        : color.labelPrimary,
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
              if (_hovered) _ForgetButton(onTap: widget.onForget),
            ],
          ),
        ),
      ),
    );
  }
}

/// The recents' trailing forget button: 20px square, hover fill, subdued ink —
/// a destructive-looking affordance for a non-destructive action.
class _ForgetButton extends StatefulWidget {
  const _ForgetButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ForgetButton> createState() => _ForgetButtonState();
}

class _ForgetButtonState extends State<_ForgetButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            LucideIcons.x,
            size: 11,
            color: _hovered ? color.labelPrimary : color.labelTertiary,
          ),
        ),
      ),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DswMotion.respecting(context, DswMotion.fast),
          height: 40,
          padding: const EdgeInsets.only(left: 12, right: 16),
          decoration: BoxDecoration(
            color: widget.active
                ? color.sidebarNavItemActive
                : _hovered
                ? color.sidebarNavItemHover
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 16, color: color.labelSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.s14.copyWith(color: color.labelPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.close`: a 28px circle with a 14px glyph.
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: context.tr('closeSettings'),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered ? color.interactiveBgHover : null,
            ),
            child: Icon(LucideIcons.x, size: 14, color: color.labelPrimary),
          ),
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
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: color.borderL2),
    );
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
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 32,
                child: TextField(
                  controller: controller,
                  autofocus: autofocus,
                  focusNode: focusNode,
                  onSubmitted: onSubmitted,
                  obscureText: obscured,
                  // A key and a path are both single-line values that must not be
                  // "helpfully" capitalised or corrected.
                  autocorrect: false,
                  enableSuggestions: false,
                  textAlignVertical: TextAlignVertical.center,
                  style: style,
                  cursorColor: color.labelPrimary,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    filled: true,
                    fillColor: color.bgLayer1,
                    hintText: hint,
                    hintStyle: style.copyWith(color: color.labelDimmed),
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border.copyWith(
                      borderSide: BorderSide(color: color.brandPrimary),
                    ),
                  ),
                ),
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ],
    );
  }
}

/// A label, a one-line description, and a switch — the side card's row shape.
///
/// The switch is drawn rather than Material's: the dsw pill has no ripple and
/// its own colours, and `Switch` would drag the whole Material theming into a
/// row that otherwise speaks only in aliases.
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
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
            _Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// The switch itself: a 36x20 pill, the thumb slides, the fill flips between
/// the border token and the brand — on is a colour, not a label.
class _Switch extends StatelessWidget {
  const _Switch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return AnimatedContainer(
      duration: DswMotion.respecting(context, DswMotion.fast),
      curve: DswMotion.easeInOut,
      width: 36,
      height: 20,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? color.brandPrimary : color.bgLayer1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: value ? color.brandPrimary : color.borderL2),
      ),
      child: AnimatedAlign(
        duration: DswMotion.respecting(context, DswMotion.fast),
        curve: DswMotion.easeInOut,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value ? color.labelPrimaryForeground : color.labelTertiary,
          ),
        ),
      ),
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
            _StepButton(
              icon: LucideIcons.minus,
              onTap: value > min ? () => onChanged(value - 1) : null,
            ),
            SizedBox(
              width: 40,
              height: 32,
              child: Center(
                child: Text(
                  '$value',
                  style: DswType.s14.copyWith(
                    color: color.labelPrimary,
                    fontFamily: dswFontFamilyCode,
                    fontFamilyFallback: dswFontFamilyCodeFallback,
                  ),
                ),
              ),
            ),
            _StepButton(
              icon: LucideIcons.plus,
              onTap: value < max ? () => onChanged(value + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// One stepper side: 28px square, radius 6, subdued until hovered — the
/// `_RevealButton` shape with the minus/plus glyphs the stepper asks for.
class _StepButton extends StatefulWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;

  /// Null at the range's end — the cap is visible, not silent.
  final VoidCallback? onTap;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? color.interactiveBgHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.borderL2),
          ),
          child: Icon(
            widget.icon,
            size: 14,
            color: enabled ? color.labelSecondary : color.labelCaption,
          ),
        ),
      ),
    );
  }
}

/// `.iconButton`: a 28px square, radius 6, tertiary glyph.
class _RevealButton extends StatefulWidget {
  const _RevealButton({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  State<_RevealButton> createState() => _RevealButtonState();
}

class _RevealButtonState extends State<_RevealButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: widget.revealed ? context.tr('hideKey') : context.tr('showKey'),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? color.interactiveBgHover : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              widget.revealed ? LucideIcons.eye_off : LucideIcons.eye,
              size: 16,
              color: _hovered ? color.labelPrimary : color.labelTertiary,
            ),
          ),
        ),
      ),
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
      waitDuration: const Duration(milliseconds: 500),
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

/// `.rowActions .secondaryButton`: the dense capsule — 28px, radius 14, hairline
/// border — that a provider row's Edit affordance takes, with the SOLID hover
/// wash dsh's row-action buttons use (`interactive-bg-hover-solid`). The label
/// flips to "Close" on the row whose card is open, since that is what the tap
/// then does.
class _RowEditButton extends StatefulWidget {
  const _RowEditButton({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_RowEditButton> createState() => _RowEditButtonState();
}

class _RowEditButtonState extends State<_RowEditButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DswMotion.respecting(context, DswMotion.fast),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHoverSolid : null,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.borderL2),
          ),
          child: Center(
            child: Text(
              widget.expanded ? context.tr('close') : context.tr('edit'),
              style: DswType.xxs12.copyWith(
                color: _hovered ? color.labelPrimary : color.labelSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.customized`: dsh's `<details>` — a hairline top border, a summary row
/// (pad 2/4, r6, hover to labelPrimary) with a rotating chevron, and the body
/// below when open with 12px of its own air. The endpoint and model fields
/// hide behind it because a working default already answers both; the key is
/// the field a user opening this card is actually here for.
class _CustomizedDisclosure extends StatefulWidget {
  const _CustomizedDisclosure({
    required this.open,
    required this.onToggle,
    required this.child,
  });

  final bool open;
  final VoidCallback onToggle;
  final Widget child;

  @override
  State<_CustomizedDisclosure> createState() => _CustomizedDisclosureState();
}

class _CustomizedDisclosureState extends State<_CustomizedDisclosure> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: color.borderL2)),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedRotation(
                      turns: widget.open ? 0.25 : 0,
                      duration: DswMotion.respecting(context, DswMotion.fast),
                      child: Icon(
                        LucideIcons.chevron_right,
                        size: 14,
                        color: _hovered
                            ? color.labelPrimary
                            : color.labelSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('customized'),
                      style: DswType.xxsStrong12.copyWith(
                        color: _hovered
                            ? color.labelPrimary
                            : color.labelSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.open)
          Padding(padding: const EdgeInsets.only(top: 12), child: widget.child),
      ],
    );
  }
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
    return Tooltip(
      message: enabled
          ? context.tr('chooseModel')
          : context.tr('noModelsFetched'),
      waitDuration: const Duration(milliseconds: 500),
      child: PopupMenuButton<String>(
        enabled: enabled,
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(minWidth: 260, maxHeight: 320),
        initialValue: null,
        onSelected: onPick,
        itemBuilder: (context) => [
          for (final id in models)
            PopupMenuItem(
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
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            LucideIcons.list,
            size: 16,
            color: enabled ? color.labelTertiary : color.labelDimmed,
          ),
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
            size: 13,
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
class _RemoveButton extends StatefulWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RemoveButton> createState() => _RemoveButtonState();
}

class _RemoveButtonState extends State<_RemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: context.tr('removeServer'),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? color.interactiveBgHover : null,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              LucideIcons.x,
              size: 16,
              color: _hovered ? color.stateErrorPrimary : color.labelTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
