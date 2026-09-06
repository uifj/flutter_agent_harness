// The code editor tab.
//
// A port of `DSH-better-sidebar/src/client/EditorHost.tsx` + `TextEditor.tsx`,
// with two structural differences forced by there being no host process:
//
//   * Reads and writes are `dart:io` calls behind the same [Workspace] guard the
//     file tools use, not `/sidebar/api/file` fetches. A tree row and a `read`
//     tool call must not disagree about what is reachable.
//   * Saving writes the file directly. Everywhere else in this app a write goes
//     through the approval interrupt, and that is right for a *model* write —
//     the user has not seen what is about to change. Here the user typed the
//     change and pressed the key; an approval sheet would be asking them to
//     confirm their own keystrokes.
//
// The dirty flag lives in this widget's State rather than in [SidebarState],
// which is the one thing that is not persisted with the layout. Unsaved text in
// a file the app is not writing is a lie waiting to be discovered: reopening the
// session would show content that is not on disk, with no indication of which.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/makefile.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../../l10n/locales.dart';
import '../../../model/workspace.dart';
import '../../../theme/dsw_alias.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../ui/conversation/assistant_markdown.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/workbench_controller.dart';
import '../tab_registry.dart';

/// The language modes this build compiles in.
///
/// Named imports rather than `languages/all.dart`: that file pulls all 197
/// grammars into the binary, and the editor only ever asks for the one
/// [highlightLanguage] named.
final _modes = {
  'dart': langDart,
  'typescript': langTypescript,
  'javascript': langJavascript,
  'json': langJson,
  'yaml': langYaml,
  'markdown': langMarkdown,
  'bash': langBash,
  'python': langPython,
  'rust': langRust,
  'xml': langXml,
  'css': langCss,
  'dockerfile': langDockerfile,
  'makefile': langMakefile,
};

/// Above this, the file opens read-only with a note saying why.
///
/// re_editor highlights and lays out the whole buffer; a few megabytes of one
/// language is a multi-second frame. The source caps at the same order of
/// magnitude (`EditorHost.tsx:88`).
const _maxEditableBytes = 2 * 1024 * 1024;

/// The gutter's type: the code stack at 11px, matching the editor's own metrics
/// so a line number sits on its line rather than near it.
const _gutter = TextStyle(
  fontSize: 11,
  height: 20 / 11,
  fontFamily: dswFontFamilyCode,
  fontFamilyFallback: dswFontFamilyCodeFallback,
);

class EditorTab extends StatefulWidget {
  const EditorTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<EditorTab> createState() => _EditorTabState();
}

/// What the tab is currently showing.
sealed class _Content {
  const _Content();
}

class _Loading extends _Content {
  const _Loading();
}

class _Failed extends _Content {
  const _Failed(this.reason);
  final String reason;
}

class _Text extends _Content {
  const _Text({required this.controller, required this.readOnlyReason});
  final CodeLineEditingController controller;

  /// Why editing is off, or null when it is on.
  final String? readOnlyReason;
}

class _Image extends _Content {
  const _Image(this.bytes);
  final Uint8List bytes;
}

class _EditorTabState extends State<EditorTab> {
  _Content _content = const _Loading();
  bool _dirty = false;
  bool _saving = false;

  /// Whether a markdown buffer shows the rendered pane instead of the source.
  /// Source is the default because that is what a save edits.
  bool _preview = false;

  /// Translation that is safe before the first build. [_load] starts in
  /// initState, where registering an inherited dependency is not allowed — so
  /// this reads the locale scope without depending on it. English, as ever,
  /// when no scope is mounted.
  String _tr(String key, [Map<String, Object>? params]) => translate(
    context.getInheritedWidgetOfExactType<AppLocaleScope>()?.locale ??
        AppLocaleId.en,
    key,
    params,
  );

  /// Whether this tab's file is markdown, and so can be previewed.
  bool get _isMarkdown {
    final path = widget.tab.path;
    if (path == null) return false;
    final ext = p.extension(path).toLowerCase();
    return ext == '.md' || ext == '.markdown';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(EditorTab old) {
    super.didUpdateWidget(old);
    // The path is part of the tab id, so a different path is a different tab and
    // this widget is never reused across one. Only the line hint can change under
    // us, which is what a model saying "line 40 of the file you have open" does.
    final line = widget.tab.meta?['line'];
    if (line is int && line != old.tab.meta?['line']) _goToLine(line);
  }

  @override
  void dispose() {
    final content = _content;
    if (content is _Text) content.controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // A refresh replaces the buffer wholesale, so the controller it is
    // replacing has to go here rather than in dispose — the widget survives.
    final previous = _content;
    if (previous is _Text) previous.controller.dispose();
    final path = widget.tab.path;
    if (path == null) {
      setState(() => _content = _Failed(_tr('tabHasNoFile')));
      return;
    }
    final workspace = widget.workbench.workspace;
    if (workspace == null) {
      setState(() => _content = _Failed(_tr('noWorkspaceNoFile')));
      return;
    }

    String resolved;
    try {
      resolved = workspace.resolve(path);
    } on WorkspaceDenied catch (denied) {
      setState(() => _content = _Failed(denied.message));
      return;
    }

    final file = File(resolved);
    if (!file.existsSync()) {
      setState(() => _content = _Failed(_tr('fileNoLongerExists')));
      return;
    }

    final length = file.lengthSync();
    if (matchFileViewer(path) == FileViewer.image) {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _content = _Image(bytes));
      return;
    }

    // Read bytes rather than a string: the extension is a guess, and decoding a
    // binary as UTF-8 with `allowMalformed` produces a screenful of replacement
    // characters that looks like a corrupt file rather than the wrong viewer.
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (!readsAsText(bytes)) {
      setState(() => _content = _Failed(_tr('looksLikeBinary')));
      return;
    }

    final controller = CodeLineEditingController.fromText(
      const Utf8Decoder(allowMalformed: true).convert(bytes),
    );
    setState(() {
      _content = _Text(
        controller: controller,
        readOnlyReason: length > _maxEditableBytes
            ? _tr('readOnlyTooLarge', {
                'mb': _maxEditableBytes ~/ (1024 * 1024),
              })
            : null,
      );
      _dirty = false;
    });
    final line = widget.tab.meta?['line'];
    if (line is int) _goToLine(line);
  }

  /// Puts the caret on [line] (1-based, as every tool and compiler counts).
  void _goToLine(int line) {
    final content = _content;
    if (content is! _Text) return;
    final index = (line - 1).clamp(0, content.controller.codeLines.length - 1);
    content.controller.selection = CodeLineSelection.collapsed(
      index: index,
      offset: 0,
    );
    content.controller.makeCursorCenterIfInvisible();
  }

  /// Reloads the file from disk. A dirty buffer is a possible loss of work, so
  /// it is confirmed before the reload rather than after.
  Future<void> _refresh() async {
    if (_dirty) {
      final title = _tr('reloadDirtyTitle');
      final description = _tr('reloadDirtyDesc', {'path': _shownPath()});
      final label = _tr('discardChanges');
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) {
          final color = context.dsw;
          return AlertDialog(
            title: Text(title, style: DswType.sStrong14),
            content: Text(description, style: DswType.xs13),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.tr('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  label,
                  style: DswType.xs13.copyWith(color: color.stateErrorPrimary),
                ),
              ),
            ],
          );
        },
      );
      if (discard != true) return;
    }
    await _load();
  }

  Future<void> _save() async {
    final content = _content;
    if (content is! _Text || content.readOnlyReason != null) return;
    final path = widget.tab.path;
    final workspace = widget.workbench.workspace;
    if (path == null || workspace == null) return;

    setState(() => _saving = true);
    try {
      final resolved = workspace.resolve(path);
      await File(resolved).writeAsString(content.controller.text);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saving = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      // Kept on screen rather than swallowed: the buffer is still dirty, and a
      // save that silently failed is how work gets lost.
      setState(() => _saving = false);
      _report('$error');
    }
  }

  void _report(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(context.tr('couldNotSave', {'message': message}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Column(
      children: [
        _bar(color),
        Expanded(child: _body(color)),
      ],
    );
  }

  /// The path + actions row. Present even when the file failed to load, since
  /// the path is the only thing that explains which tab is complaining.
  Widget _bar(DswAlias color) {
    final content = _content;
    final readOnly = content is _Text ? content.readOnlyReason : null;
    final canPreview = _isMarkdown && content is _Text;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _shownPath(),
              style: DswType.xxs12.copyWith(color: color.labelTertiary),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          if (canPreview) ...[
            _BarIcon(
              icon: LucideIcons.eye,
              tooltip: context.tr('preview'),
              active: _preview,
              onTap: () => setState(() => _preview = !_preview),
            ),
            const SizedBox(width: 6),
          ],
          _BarIcon(
            icon: LucideIcons.refresh_cw,
            tooltip: context.tr('reload'),
            onTap: _refresh,
          ),
          const SizedBox(width: 6),
          if (readOnly != null)
            Tooltip(
              message: readOnly,
              child: Icon(
                LucideIcons.lock,
                size: 13,
                color: color.labelTertiary,
              ),
            ),
          if (content is _Text && readOnly == null) ...[
            if (_dirty)
              Text(
                context.tr('unsaved'),
                style: DswType.xxxs11.copyWith(color: color.stateWarnPrimary),
              ),
            const SizedBox(width: 6),
            _SaveButton(
              enabled: _dirty && !_saving,
              busy: _saving,
              onSave: _save,
            ),
          ],
        ],
      ),
    );
  }

  /// The path relative to the workspace when it is inside one — an absolute path
  /// in a 300px column is all prefix and no file name.
  String _shownPath() {
    final path = widget.tab.path ?? '';
    final root = widget.workbench.workspaceRoot;
    if (root == null || !path.startsWith(root)) return path;
    final relative = path.substring(root.length);
    return relative.startsWith('/') ? relative.substring(1) : relative;
  }

  Widget _body(DswAlias color) => switch (_content) {
    _Loading() => const SizedBox.shrink(),
    _Failed(:final reason) => _Notice(message: reason),
    _Image(:final bytes) => ColoredBox(
      color: color.bgLayer2,
      child: InteractiveViewer(
        maxScale: 8,
        child: Center(child: Image.memory(bytes)),
      ),
    ),
    _Text(:final controller, :final readOnlyReason) =>
      _preview && _isMarkdown
      ? _Preview(text: controller.text)
      : _editor(color, controller, readOnlyReason != null),
  };

  Widget _editor(
    DswAlias color,
    CodeLineEditingController controller,
    bool readOnly,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final language = highlightLanguage(widget.tab.path ?? '');
    final mode = language == null ? null : _modes[language];
    return CallbackShortcuts(
      bindings: {
        // Cmd/Ctrl-S. re_editor owns the rest of the editing keymap; this is the
        // one binding it has no opinion about, since it does not know what a file
        // is.
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      // The dirty flag rides here rather than on a controller listener added
      // in _load: see _DirtyBridge for why.
      child: _DirtyBridge(
        controller: controller,
        onDirty: _onBufferEdited,
        child: CodeEditor(
        controller: controller,
        readOnly: readOnly,
        wordWrap: false,
        padding: const EdgeInsets.symmetric(vertical: 6),
        style: CodeEditorStyle(
          fontSize: 12,
          fontHeight: 20 / 12,
          fontFamily: dswFontFamilyCode,
          fontFamilyFallback: dswFontFamilyCodeFallback,
          textColor: color.labelPrimary,
          backgroundColor: color.bgLayer2,
          selectionColor: color.bubbleHighlight,
          cursorColor: color.labelPrimary,
          cursorLineColor: color.interactiveBgHover,
          chunkIndicatorColor: color.labelTertiary,
          codeTheme: mode == null
              ? null
              : CodeHighlightTheme(
                  languages: {language!: CodeHighlightThemeMode(mode: mode)},
                  theme: dark ? atomOneDarkTheme : atomOneLightTheme,
                ),
        ),
        indicatorBuilder:
            (context, editingController, chunkController, notifier) => Row(
              children: [
                DefaultCodeLineNumber(
                  controller: editingController,
                  notifier: notifier,
                  textStyle: _gutter.copyWith(color: color.labelTertiary),
                  focusedTextStyle: _gutter.copyWith(
                    color: color.labelSecondary,
                  ),
                ),
                DefaultCodeChunkIndicator(
                  width: 16,
                  controller: chunkController,
                  notifier: notifier,
                  painter: DefaultCodeChunkIndicatorPainter(
                    color: color.labelTertiary,
                  ),
                ),
              ],
            ),
        ),
      ),
    );
  }

  /// A real edit arrived (not a mount — see [_DirtyBridge]).
  void _onBufferEdited() {
    if (_dirty || _saving) return;
    setState(() => _dirty = true);
  }
}

/// Centred prose for the cases where there is no editor to show.
class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgLayer2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
        ),
      ),
    );
  }
}

/// Bridges the buffer's change notifications to the tab's dirty flag, one
/// frame late.
///
/// re_editor assigns the controller's delegate in the editor's own initState,
/// which notifies the controller from inside build. A listener attached before
/// that moment would both false-positive the dirty flag on every open (and on
/// every return from preview, which mounts a fresh editor over the same
/// controller) and call setState mid-build, which asserts. Attaching after the
/// frame means the only notifications that arrive are real edits, which always
/// come from input events — outside build.
class _DirtyBridge extends StatefulWidget {
  const _DirtyBridge({
    required this.controller,
    required this.onDirty,
    required this.child,
  });

  final CodeLineEditingController controller;
  final VoidCallback onDirty;
  final Widget child;

  @override
  State<_DirtyBridge> createState() => _DirtyBridgeState();
}

class _DirtyBridgeState extends State<_DirtyBridge> {
  void _listen() => widget.onDirty();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.addListener(_listen);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The rendered markdown pane. Reuses the transcript's renderer so a preview
/// and a chat reply read identically — one markdown look per app, not per view.
class _Preview extends StatelessWidget {
  const _Preview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgLayer2,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: AssistantMarkdown(text),
      ),
    );
  }
}

/// A 20px square bar action. [active] tints the icon so a toggle's state is
/// readable without hover — the bar has no room for a pressed look.
class _BarIcon extends StatelessWidget {
  const _BarIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final tint = active ? color.labelPrimary : color.labelTertiary;
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.square(
            dimension: 20,
            child: Center(child: Icon(icon, size: 14, color: tint)),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.busy,
    required this.onSave,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final tint = enabled ? color.labelSecondary : color.labelTertiary;
    return Tooltip(
      message: context.tr('save'),
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onSave : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox.square(
            dimension: 20,
            child: Center(
              child: busy
                  ? SizedBox.square(
                      dimension: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: tint,
                      ),
                    )
                  : Icon(LucideIcons.save, size: 14, color: tint),
            ),
          ),
        ),
      ),
    );
  }
}
