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

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';

import '../../model/app_settings.dart';
import '../../model/mcp_settings.dart';
import '../../model/model_settings.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';

/// Which section the rail is pointing at.
enum _Section { models, workspace, extensions }

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onSave,
    required this.onClose,
  });

  final AppSettings settings;

  /// Commits the edited document. Awaited, so the panel can report the outcome
  /// rather than closing on faith.
  final Future<void> Function(AppSettings next) onSave;

  final VoidCallback onClose;

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
  late final _skills = TextEditingController(text: widget.settings.skillsRoot ?? '');

  late LlmProvider _provider = widget.settings.model.provider;

  /// The editable copy of the MCP server list. Drafts hold their own
  /// controllers; an invalid draft is dropped at commit rather than refused
  /// at the field, the same repair-not-reject contract the model uses.
  late final List<_ServerDraft> _servers = [
    for (final server in widget.settings.mcpServers) _ServerDraft.of(server),
  ];

  _Section _section = _Section.models;

  /// A key is a secret in a shared-screen sense, so it starts masked; the reveal
  /// is there because a mistyped key fails with the same 401 as a wrong one.
  bool _revealed = false;

  bool _saving = false;
  bool _saved = false;

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
  }

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
    super.dispose();
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
  /// retyping one field.
  void _selectProvider(LlmProvider provider) {
    final reset = widget.settings.model.forProvider(provider);
    setState(() {
      _provider = provider;
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
        children: [_nav(color), Expanded(child: _content(color))],
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
              'Settings',
              style: DswType.baseStrong16.copyWith(color: color.labelPrimary),
            ),
          ),
          const SizedBox(height: 18),
          _NavCell(
            label: 'Models',
            icon: LucideIcons.network,
            active: _section == _Section.models,
            onTap: () => setState(() => _section = _Section.models),
          ),
          const SizedBox(height: 4),
          _NavCell(
            label: 'Workspace',
            icon: LucideIcons.folder_open,
            active: _section == _Section.workspace,
            onTap: () => setState(() => _section = _Section.workspace),
          ),
          const SizedBox(height: 4),
          _NavCell(
            label: 'Extensions',
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
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_CloseButton(onTap: _close)],
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
                  _Section.models => _models(color),
                  _Section.workspace => _workspaceSection(color),
                  _Section.extensions => _extensionsSection(color),
                },
                const SizedBox(height: 16),
                _actions(color),
              ],
            ),
          ),
        ),
      ),
    ],
  );

  List<Widget> _models(DswAlias color) => [
    _heading(color, 'Models', 'Which endpoint this build talks to.'),
    const SizedBox(height: 12),
    _providerSelector(color),
    const SizedBox(height: 12),
    _credential(color),
    const SizedBox(height: 12),
    _Field(
      label: 'API key',
      controller: _key,
      hint: 'sk-…',
      obscured: !_revealed,
      autofocus: true,
      // The one field with an affordance of its own, so it carries the reveal
      // rather than the section growing a control that applies to nothing else.
      trailing: _RevealButton(
        revealed: _revealed,
        onTap: () => setState(() => _revealed = !_revealed),
      ),
    ),
    const SizedBox(height: 12),
    _Field(
      label: 'Base URL',
      controller: _baseUrl,
      // Empty means the provider's own endpoint — only the OpenAI-compatible
      // path has a default worth hinting.
      hint: _provider == LlmProvider.openai ? defaultBaseUrl : 'provider default',
    ),
    const SizedBox(height: 12),
    _Field(
      label: 'Model',
      controller: _model,
      hint: defaultModelFor(_provider),
      // The model id is a wire value, and reads as one.
      code: true,
    ),
  ];

  /// The three providers, as one 32px segmented row. Selecting one resets the
  /// connection fields — see `_selectProvider`.
  Widget _providerSelector(DswAlias color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Provider',
        style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          for (final provider in LlmProvider.values) ...[
            Expanded(
              child: _ProviderCell(
                provider: provider,
                selected: _provider == provider,
                onTap: () => _selectProvider(provider),
              ),
            ),
            if (provider != LlmProvider.values.last)
              const SizedBox(width: 8),
          ],
        ],
      ),
    ],
  );

  List<Widget> _workspaceSection(DswAlias color) => [
    _heading(
      color,
      'Workspace',
      'The one folder the file tools may read and write. They refuse every call '
          'while this is empty, and refuse any path that resolves outside it.',
    ),
    const SizedBox(height: 12),
    _Field(
      label: 'Folder',
      controller: _workspace,
      hint: '/Users/you/project',
      autofocus: true,
      code: true,
    ),
  ];

  List<Widget> _extensionsSection(DswAlias color) => [
    _heading(
      color,
      'MCP servers',
      'External tools the agent may call, named <server>/<tool>. A server is '
          'launched over stdio from a command, or reached over HTTP at a URL — '
          'fill in one or the other. Changes take effect after the runtime is '
          'rebuilt (Save), and a server that fails to connect simply '
          'contributes nothing.',
    ),
    const SizedBox(height: 12),
    for (final draft in List<_ServerDraft>.of(_servers)) ...[
      _serverCard(color, draft),
      const SizedBox(height: 8),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: CapsuleButton(label: 'Add server', onTap: _addServer),
    ),
    const SizedBox(height: 28),
    _heading(
      color,
      'Skills',
      'The folder whose sub-directories each hold a SKILL.md. The agent lists '
          'them in its system prompt and loads one with the use_skill tool. '
          'Empty means <application support>/skills.',
    ),
    const SizedBox(height: 12),
    _Field(
      label: 'Folder',
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
                label: 'Name',
                controller: draft.name,
                hint: 'fs',
                code: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _Field(
                label: 'Arguments',
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
          label: 'Command (stdio)',
          controller: draft.command,
          hint: 'npx',
          code: true,
        ),
        const SizedBox(height: 12),
        _Field(
          label: 'URL (HTTP)',
          controller: draft.url,
          hint: 'https://example.test/mcp',
          code: true,
        ),
      ],
    ),
  );

  Widget _heading(DswAlias color, String title, String intro) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: DswType.baseStrong16.copyWith(color: color.labelPrimary)),
      const SizedBox(height: 4),
      Text(intro, style: DswType.s14.copyWith(color: color.labelTertiary)),
    ],
  );

  /// `.credentialDot`: whether a key is on file at all, which is the question a
  /// user opening this panel most often came to answer.
  Widget _credential(DswAlias color) {
    final configured = _key.text.trim().isNotEmpty;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: configured
                ? color.stateSuccessPrimary
                : color.stateErrorPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          configured ? 'Key configured' : 'No key — the composer stays disabled',
          style: DswType.xxs12.copyWith(color: color.labelSecondary),
        ),
      ],
    );
  }

  Widget _actions(DswAlias color) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      if (_dirty && _edited.model.requiresRestart(widget.settings.model))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Saving reconnects the agent. The open conversation is cleared; it '
            'stays on disk and can be reopened from the sidebar.',
            style: DswType.xxs12.copyWith(color: color.stateWarnLabel),
          ),
        ),
      if (_saved)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Saved',
            style: DswType.xxs12.copyWith(color: color.stateSuccessPrimary),
          ),
        ),
      Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CapsuleButton(label: 'Close', enabled: !_saving, onTap: _close),
          const SizedBox(width: 8),
          CapsuleButton(
            label: _saving ? 'Saving…' : 'Save',
            variant: CapsuleVariant.primary,
            enabled: _dirty && !_saving,
            onTap: _save,
          ),
        ],
      ),
    ],
  );
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
      message: 'Close settings',
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
      message: widget.revealed ? 'Hide key' : 'Show key',
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
              widget.revealed
                  ? LucideIcons.eye_off
                  : LucideIcons.eye,
              size: 16,
              color: _hovered ? color.labelPrimary : color.labelTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// One cell of the provider row: 32px to sit beside `_Field`'s inputs, radius
/// 8, `border-l2` resting, the brand colour once selected. Hovering an
/// unselected cell only brightens the label — the box is reserved for the
/// selection, so the row reads as one control rather than three buttons.
class _ProviderCell extends StatefulWidget {
  const _ProviderCell({
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final LlmProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ProviderCell> createState() => _ProviderCellState();
}

class _ProviderCellState extends State<_ProviderCell> {
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
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected ? color.bgLayer1 : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.selected ? color.brandPrimary : color.borderL2,
            ),
          ),
          child: Text(
            _label(widget.provider),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xxsStrong12.copyWith(
              color: widget.selected || _hovered
                  ? color.labelPrimary
                  : color.labelSecondary,
            ),
          ),
        ),
      ),
    );
  }

  static String _label(LlmProvider provider) => switch (provider) {
    // The OpenAI-compatible path is what a custom baseUrl is for, so the label
    // says what it accepts rather than which vendor it defaults to.
    LlmProvider.openai => 'OpenAI-compatible',
    LlmProvider.anthropic => 'Anthropic',
    LlmProvider.google => 'Google',
  };
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

  List<TextEditingController> get controllers =>
      [name, command, url, args];

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
      message: 'Remove server',
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
