// The terminal tab: an xterm emulator over a pty from the manager's pool.
//
// A port of `DSH-better-sidebar/src/client/TerminalView.tsx`, with the whole
// reconnect discipline replaced by the in-process seam in
// `lib/host/terminal_manager.dart`. There is no socket, so there is no park
// frame, no reconnect grace and no retry loop: a spawn failure is a banner
// over a retry button, and a shell that exited is a banner over a restart
// one. (The source's auto-reconnect respawns a dead shell unprompted, which
// is the right call for a webapp whose pty died of a page refresh and the
// wrong one here, where an exited shell means the user typed `exit`.)
//
// Two lifetimes meet in this file:
//
//   * The emulator's — one per attachment, recreated rather than reset
//     because xterm's [Terminal] has no reset, and the scrollback of the
//     previous shell is the previous shell's.
//   * The process's, which belongs to the manager's pool. Every mount
//     reattaches, so a tab moving between panes keeps its shell; `dispose`
//     closes the session only when the tab is gone from the layout (the user
//     closed it) or the layout itself was swapped for another conversation's
//     tree. That check reads the *current* state at unmount time, which is
//     the state that already explains why this body is going away — and
//     which, for a pane move, still lists the tab, because the element being
//     inflated in the tab's new home attaches to the session before this
//     element is finalized.
//
// Manager keys carry the conversation id (`<session>/<tabId>`): terminal tab
// ids restart at `terminal:1` for every conversation, so a pool keyed by tab
// id alone would hand conversation B the shell conversation A left running.
// The awkward half of that is that pane ids restart too, so a session swap
// can leave this very element in place under a new conversation's identical
// pane and tab ids — `didUpdateWidget` is where that is noticed and the old
// shell retired.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../../host/terminal_manager.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/workbench_controller.dart';
import '../workbench_prefs_scope.dart';

/// How much history the emulator keeps, matching the source's `scrollback:
/// 4000`.
const _scrollbackLines = 4000;

/// The glyphs at the code stack's own metrics, so a terminal line and an
/// editor line are the same height in the same column.
///
/// The prefs override the family and the size (the source's terminal card,
/// applied live); the line height follows the size at the source's own ratio
/// so a bigger font is a bigger line, not a tighter one.
TerminalStyle emulatorStyle(BuildContext context) {
  final prefs = WorkbenchPrefsScope.of(context);
  final family = prefs.terminalFontFamily.trim();
  return TerminalStyle(
    fontSize: prefs.terminalFontSize.toDouble(),
    height: 20 / 13,
    fontFamily: family.isEmpty ? dswFontFamilyCode : family,
    fontFamilyFallback:
        family.isEmpty ? dswFontFamilyCodeFallback : const <String>[],
  );
}

/// The workbench's pty pool, in reach of tab bodies.
///
/// An [InheritedWidget] rather than a constructor parameter on every tab
/// because bodies are built by the global registry in
/// `lib/ui/workbench/tab_registry.dart`, whose builders cannot capture an
/// app-scoped object without pinning whichever instance registered first.
/// The scope is looked up from each body's own context, so every [Workbench]
/// — the app's, or a test's — hands its own pool to its own tabs.
class TerminalHost extends InheritedWidget {
  const TerminalHost({
    super.key,
    required this.manager,
    required super.child,
  });

  final TerminalManager manager;

  /// The pool below [context]. Throws rather than defaulting: a terminal tab
  /// outside a [TerminalHost] is a wiring bug, and a silent fallback pool would
  /// hide it behind a shell that dies with the widget.
  static TerminalManager of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<TerminalHost>();
    if (host == null) {
      throw StateError('TerminalTab needs a TerminalHost ancestor');
    }
    return host.manager;
  }

  @override
  bool updateShouldNotify(TerminalHost oldWidget) =>
      manager != oldWidget.manager;
}

class TerminalTab extends StatefulWidget {
  const TerminalTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  TerminalManager? _manager;

  /// The attachment: emulator, session, and the subscriptions that make them
  /// one terminal. Null between detach and the next attach, which only the
  /// restart button and a conversation swap pass through.
  Terminal? _terminal;
  TerminalSession? _session;
  StreamSubscription<String>? _output;
  StreamSubscription<int?>? _done;

  /// The manager key and conversation the attached session was opened under.
  /// Both are needed at `dispose` time, when the controller may already be
  /// showing a different conversation's layout than the one this body was
  /// built for.
  String? _attachedKey;
  String? _attachedConversation;

  /// The conversation whose layout is showing, as the manager keys it.
  String get _conversation => widget.workbench.sessionId ?? '';

  /// The manager key for this tab under [conversation]: conversation and tab
  /// id both, because every conversation's terminal ids restart at
  /// `terminal:1` and a pool keyed by tab alone would hand one conversation
  /// the shell another left running.
  String _key() => '$_conversation/${widget.tab.id}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _manager ??= TerminalHost.of(context);
    // The first attach happens here rather than in initState because the
    // pool comes from the scope above, and depending on an inherited widget
    // is not allowed there.
    if (_attachedKey == null) _attach();
  }

  @override
  void didUpdateWidget(TerminalTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the conversation can change under a live body: the tab id is the
    // element's key, so a different tab is a different element. When it does
    // change there are two cases, told apart by the tab object itself —
    // adoption hands this body the very same [SidebarTab] instance (the
    // layout object carried over unchanged when the conversation got its
    // id), while a swap hands it another conversation's tab minted by that
    // conversation's own openTerminal.
    final attached = _attachedConversation;
    if (attached == null || attached == _conversation) return;
    if (identical(oldWidget.tab, widget.tab)) {
      // A first turn persisted the conversation this body was already showing
      // a shell for. Re-key the pool entry; killing the shell here would make
      // every conversation's first message close its terminals.
      _manager?.rename(_attachedKey!, _key());
      _attachedKey = _key();
      _attachedConversation = _conversation;
    } else {
      // A different conversation's tree took the column. Its shell is not
      // this conversation's to keep.
      setState(_swap);
    }
  }

  @override
  void dispose() {
    _subscriptionsCancel();
    final key = _attachedKey;
    if (key != null) {
      // The session outlives this body only when some other body is already
      // attached to it — a pane move — which is exactly "the tab is still in
      // this conversation's layout". Anything else (the tab was closed, or the
      // whole tree was swapped out from under it) takes the shell with it.
      final tabGone =
          widget.workbench.state.paneOf(widget.tab.id) == null ||
          _conversation != _attachedConversation;
      if (tabGone) _manager?.close(key);
    }
    _manager = null;
    super.dispose();
  }

  /// Spawns or reattaches, and wires the emulator to what came back.
  void _attach() {
    final key = _key();
    final session = _manager!.open(
      key,
      workingDirectory: widget.workbench.workspaceRoot,
    );
    final terminal = Terminal(maxLines: _scrollbackLines);
    terminal.onOutput = session.write;
    terminal.onResize = (cols, rows, _, _) => session.resize(cols, rows);
    // A chunked decoder, not utf8.decode per chunk: a pty emits output as
    // it is produced, and a multi-byte character split across two chunks
    // would otherwise arrive as two replacement characters. The cast first
    // because the decoder is a transformer of List<int>, and a stream of
    // Uint8List is a stream of List<int> the types cannot see.
    _output = session.output
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    // The exited shell's banner, and the failed spawn's. Both are the same
    // widget with different words, so one rebuild serves both.
    _done = session.done.asStream().listen((_) {
      if (mounted) setState(() {});
    });
    _terminal = terminal;
    _session = session;
    _attachedKey = key;
    _attachedConversation = _conversation;
  }

  /// Drops the current attachment, closing its session if [kill] — which is
  /// every caller: the restart button wants the dead entry gone so `open`
  /// spawns rather than reattaches, and a conversation swap wants the old
  /// conversation's shell gone entirely.
  void _detach() {
    _subscriptionsCancel();
    final key = _attachedKey;
    if (key != null) _manager?.close(key);
    _terminal = null;
    _session = null;
    _attachedKey = null;
    _attachedConversation = null;
  }

  void _subscriptionsCancel() {
    _output?.cancel();
    _output = null;
    _done?.cancel();
    _done = null;
  }

  /// Retires the current shell and attaches a fresh one: what the banner's
  /// button does, and what a conversation swap under a reused element does.
  void _swap() {
    _detach();
    _attach();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Column(
      children: [
        if (session?.error != null)
          _Banner(
            message: 'Could not start the shell: ${session!.error}',
            action: 'Retry',
            onTap: () => setState(_swap),
          )
        else if (session != null && !session.isAlive)
          _Banner(
            message: session.exitCode == 0 || session.exitCode == null
                ? 'The shell exited.'
                : 'The shell exited (${session.exitCode}).',
            action: 'Restart',
            onTap: () => setState(_swap),
          ),
        Expanded(
          child: TerminalView(
            _terminal!,
            theme: _theme(context),
            textStyle: emulatorStyle(context),
            // A dead session has nothing to send keystrokes to; leaving the
            // emulator live would silently eat them.
            readOnly: !(session?.isAlive ?? false),
          ),
        ),
      ],
    );
  }

  /// The emulator's palette: the app's surface tokens for background,
  /// foreground and selection so the terminal blends with the column, and
  /// the source's curated 16-color ANSI families (`TerminalView.tsx:69-83`)
  /// for everything programs color themselves. Those ride the brightness
  /// rather than the tokens because an ANSI palette is a tuned set, not
  /// sixteen shades of one.
  TerminalTheme _theme(BuildContext context) {
    final color = context.dsw;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ansi = dark ? _ansiDark : _ansiLight;
    return TerminalTheme(
      cursor: color.labelPrimary,
      selection: dark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.12),
      foreground: color.labelPrimary,
      background: color.bgLayer2,
      black: ansi[0],
      red: ansi[1],
      green: ansi[2],
      yellow: ansi[3],
      blue: ansi[4],
      magenta: ansi[5],
      cyan: ansi[6],
      white: ansi[7],
      brightBlack: ansi[8],
      brightRed: ansi[9],
      brightGreen: ansi[10],
      brightYellow: ansi[11],
      brightBlue: ansi[12],
      brightMagenta: ansi[13],
      brightCyan: ansi[14],
      brightWhite: ansi[15],
      searchHitBackground: const Color(0xFFFFFF2B),
      searchHitBackgroundCurrent: const Color(0xFF31FF26),
      searchHitForeground: Colors.black,
    );
  }
}

/// The one-dark family, exactly as the source ships it for dark scheme.
const _ansiDark = [
  Color(0xFF282C34), // black
  Color(0xFFE06C75), // red
  Color(0xFF98C379), // green
  Color(0xFFE5C07B), // yellow
  Color(0xFF61AFEF), // blue
  Color(0xFFC678DD), // magenta
  Color(0xFF56B6C2), // cyan
  Color(0xFFABB2BF), // white
  Color(0xFF5C6370), // bright black
  Color(0xFFE06C75), // bright red
  Color(0xFF98C379), // bright green
  Color(0xFFE5C07B), // bright yellow
  Color(0xFF61AFEF), // bright blue
  Color(0xFFC678DD), // bright magenta
  Color(0xFF56B6C2), // bright cyan
  Color(0xFFFFFFFF), // bright white
];

/// The one-light family, likewise.
const _ansiLight = [
  Color(0xFF383A42), // black
  Color(0xFFE45649), // red
  Color(0xFF50A14F), // green
  Color(0xFFC18401), // yellow
  Color(0xFF0184BC), // blue
  Color(0xFFA626A4), // magenta
  Color(0xFF0997B3), // cyan
  Color(0xFFA0A1A7), // white
  Color(0xFF4F525E), // bright black
  Color(0xFFE45649), // bright red
  Color(0xFF50A14F), // bright green
  Color(0xFFC18401), // bright yellow
  Color(0xFF0184BC), // bright blue
  Color(0xFFA626A4), // bright magenta
  Color(0xFF0997B3), // bright cyan
  Color(0xFFFAFAFA), // bright white
];

/// The slim strip above the emulator that says why there is no shell to talk
/// to, and offers the one gesture that fixes it.
class _Banner extends StatefulWidget {
  const _Banner({
    required this.message,
    required this.action,
    required this.onTap,
  });

  final String message;
  final String action;
  final VoidCallback onTap;

  @override
  State<_Banner> createState() => _BannerState();
}

class _BannerState extends State<_Banner> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: 28,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.message,
              style: DswType.xxs12.copyWith(color: color.labelSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _hovered
                      ? color.interactiveBgHover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.action,
                  style: DswType.xxs12.copyWith(color: color.labelSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
