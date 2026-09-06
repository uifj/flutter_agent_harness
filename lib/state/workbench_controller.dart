// The one mutable thing in the workbench.
//
// Everything interesting about the layout is a pure function in
// `lib/model/`; this holds the current value of it, tells listeners when
// it changed, and hands it to the store. Keeping it that thin is what makes the
// reducers testable and this file mostly plumbing.
//
// Two responsibilities that are not plumbing, and are the reason this class
// exists at all rather than a `ValueNotifier<SidebarState>`:
//
//   * One layout per session. Switching sessions swaps the whole state, so
//     reopening a conversation restores the files it was about. The map is a
//     cache in front of the store, not the source of truth.
//   * Surviving the moment a session gets its id. A conversation has no id until
//     its first turn persists, but the user can open files before that. Binding
//     from unsaved to a brand-new id therefore *carries the layout over* instead
//     of loading the empty one that is on disk — see [bindSession].
//
// It is also the [WorkbenchSink] the `sidebar_open` tool writes into. No queue
// sits between them (see `lib/model/workbench.dart` for why better-sidebar needs
// one and this does not), but a tool call arrives from a stream callback, so
// every sink method must be safe to call at any point in a frame — which is why
// they all end in `notifyListeners` and nothing more.

import 'package:flutter/foundation.dart';

import '../model/workbench.dart';
import '../model/workspace.dart';
import '../model/sidebar_state.dart';
import '../model/sidebar_tab.dart';
import '../model/split_node.dart';
import 'workbench_store.dart';

class WorkbenchController extends ChangeNotifier implements WorkbenchSink {
  WorkbenchController({required WorkbenchStore store, String? workspaceRoot})
    : _store = store,
      _workspaceRoot = workspaceRoot;

  /// The key an unsaved conversation's layout is cached under. Not a file name:
  /// nothing is written until the session has an id, because a layout with no
  /// session to belong to would be restored by whichever session happened next.
  static const _unsaved = '';

  final WorkbenchStore _store;

  final _layouts = <String, SidebarState>{};

  String _session = _unsaved;
  SidebarState _state = SidebarState.initial();
  String? _workspaceRoot;

  SidebarState get state => _state;

  /// The session whose layout is showing, or null for an unsaved conversation.
  String? get sessionId => _session == _unsaved ? null : _session;

  /// The folder the file tree is rooted at and the guard every path goes
  /// through, or null when no workspace has been granted.
  String? get workspaceRoot => _workspaceRoot;

  set workspaceRoot(String? next) {
    if (_workspaceRoot == next) return;
    _workspaceRoot = next;
    notifyListeners();
  }

  /// The escape guard for [workspaceRoot], or null when there is no workspace.
  ///
  /// The same guard the file tools use, for the same reason: a tree row and a
  /// `read` call must not disagree about what is reachable.
  Workspace? get workspace {
    final root = _workspaceRoot;
    return root == null ? null : Workspace.of(root);
  }

  /// Shows [id]'s layout, restoring it from disk on first use.
  ///
  /// Passing null shows the unsaved conversation's layout. Binding to an id that
  /// has nothing stored *while the unsaved layout is showing* adopts that layout
  /// rather than starting empty: that is precisely the transition a first turn
  /// makes, and the files opened while composing it belong to the session it
  /// became.
  Future<void> bindSession(String? id) async {
    final key = id ?? _unsaved;
    if (key == _session) return;
    _layouts[_session] = _state;
    // The outgoing layout may still be inside its debounce window; a bind is a
    // point where losing it would be visible.
    await _store.flush();
    final adopting =
        _session == _unsaved &&
        key != _unsaved &&
        !_layouts.containsKey(key) &&
        _store.load(key) == null;
    if (adopting) {
      _layouts.remove(_unsaved);
      _session = key;
      // Written straight away rather than waiting for the next change: the state
      // is now the session's, and nothing on disk says so yet.
      _store.save(key, _state);
      notifyListeners();
      return;
    }
    _session = key;
    _state =
        _layouts[key] ??
        (key == _unsaved ? null : _store.load(key)) ??
        SidebarState.initial();
    // A session bound while narrow gets the same merge a breakpoint-crossing
    // performs: its bottom-panel tabs arrive in the one visible panel. The
    // reducer's idempotence makes this safe even when the layout was already
    // migrated before the bind.
    if (mobileMerge) _state = _state.migrateBottomTabs();
    notifyListeners();
  }

  /// Drops a deleted session's layout, on disk and in the cache.
  void forgetSession(String id) {
    _layouts.remove(id);
    _store.delete(id);
    if (_session == id) {
      _session = _unsaved;
      _state = _layouts[_unsaved] ?? SidebarState.initial();
      notifyListeners();
    }
  }

  /// Writes any pending layout now. For app teardown.
  Future<void> flush() => _store.flush();

  /// Writes any pending layout, then tears down.
  ///
  /// One method rather than leaving the caller to do both, because the order has
  /// to be awaited and `State.dispose` cannot: `flush(); dispose();` from a
  /// synchronous teardown clears the store's queue while the first write is still
  /// suspended, and every session after the first loses its layout.
  Future<void> shutdown() async {
    await _store.flush();
    dispose();
  }

  // --- Opens ---

  /// The tab types the user has switched off. Fed from the workbench prefs by
  /// the app entry; kept as a set of the disabled rather than the full map
  /// because the opens below ask one question — "may this type open?" — and
  /// nothing else.
  ///
  /// A disabled type refuses every open here but never closes a tab already on
  /// screen: a conversation's saved layout is its own record, and editing it
  /// behind the user's back is the one thing the source's switch never does.
  Set<String> disabledTabs = const {};

  /// Replaces [disabledTabs]. The controller does not own the prefs document,
  /// so the app entry pushes the change in — this is the one seam, called
  /// whenever the prefs store notifies.
  void setDisabledTabs(Set<String> next) {
    if (setEquals(disabledTabs, next)) return;
    disabledTabs = next;
  }

  /// Whether the mobile merge is in force: one panel, the bottom tabs folded
  /// into it. Fed by the app entry from the layout controller's breakpoint
  /// reading — the controller cannot see the viewport, only the consequence.
  ///
  /// Turning it ON runs the migration immediately, so a desktop→narrow
  /// crossing moves the tabs in the same notification the drawer appears in.
  /// Turning it OFF does nothing: the merge is permanent by design, and the
  /// bottom panel returns as the empty welcome.
  bool mobileMerge = false;

  void setMobileMerge(bool value) {
    if (mobileMerge == value) return;
    mobileMerge = value;
    if (value) _apply(_state.migrateBottomTabs());
  }

  /// Opens [absolutePath] in an editor tab, optionally scrolled to [line].
  ///
  /// A file already open is focused rather than opened twice; when a [line] came
  /// with the request the tab's meta is rewritten first, so focusing an open
  /// editor still moves the caret. That is the difference between "the model
  /// pointed at line 40" being useful and being a no-op.
  void openFile(String absolutePath, {int? line}) {
    final tab = SidebarTab.editor(absolutePath);
    var next = line == null
        ? _state
        : _state.patchTab(tab.id, meta: {'line': line});
    next = next.openTab(line == null ? tab : tab.copyWith(meta: {'line': line}));
    _apply(next);
  }

  /// Opens [absolutePath] as a file tree root, already expanded — a collapsed
  /// root is a tab showing one row.
  void openFolder(String absolutePath) {
    if (disabledTabs.contains(BuiltinTabType.explorer)) return;
    _apply(
      _state.openTab(SidebarTab.explorer(absolutePath)).expand(absolutePath),
    );
  }

  /// Opens a fresh terminal tab.
  void openTerminal() {
    if (disabledTabs.contains(BuiltinTabType.terminal)) return;
    _apply(_state.openTerminal());
  }

  /// Opens a fresh terminal tab in the bottom panel's first pane — the
  /// bottomPanelAutoTerminal behaviour. The type switch still gates it, as the
  /// source says ("the terminal quota/type still gates the attempt"): a
  /// disabled terminal type means no terminal anywhere, including the seed.
  void openTerminalInBottom() {
    if (disabledTabs.contains(BuiltinTabType.terminal)) return;
    final panes = _state.bottomPanes;
    if (panes.isEmpty) {
      openTerminal();
      return;
    }
    _apply(_state.openTerminalIn(panes.first.id));
  }

  /// Opens the single git tab, or focuses it.
  void openGit() {
    if (disabledTabs.contains(BuiltinTabType.git)) return;
    _apply(_state.openTab(SidebarTab.git));
  }

  /// Opens the single sub-agent tab, or focuses it.
  void openSubagents() {
    if (disabledTabs.contains(BuiltinTabType.subagent)) return;
    _apply(_state.openTab(SidebarTab.subagent));
  }

  /// Opens the single side-chat tab, or focuses it.
  void openSideChat() {
    if (disabledTabs.contains(BuiltinTabType.sidechat)) return;
    _apply(_state.openSideChat());
  }

  /// Opens a browser tab at [url], or focuses the one already on it.
  void openBrowser(String url) {
    if (disabledTabs.contains(BuiltinTabType.browser)) return;
    _apply(_state.openBrowser(url));
  }

  /// Opens a fresh browser tab with no address yet — the `+` menu's entry.
  void openBrowserUntitled() {
    if (disabledTabs.contains(BuiltinTabType.browser)) return;
    _apply(_state.openBrowserUntitled());
  }

  /// Opens a diff for [ref] the sticky way — see [SidebarState.openDiffTab].
  void openDiff(SidebarDiffRef ref) {
    _apply(_state.openDiffTab(_state.activePane, SidebarTab.diff(ref)));
  }

  // --- Free windows ---

  /// Floats [tabId] at [x],[y] (overlay coordinates), with [vw]/[vh] as the
  /// viewport the geometry clamps against — the caller has the layer's size,
  /// the state does not.
  void floatTab(String tabId, double x, double y, double vw, double vh) =>
      _apply(_state.floatTab(tabId, x, y, vw, vh));

  /// Moves a free window; the commit on drag release, not per frame.
  void moveFloat(String floatId, double x, double y, double vw, double vh) =>
      _apply(_state.moveFloat(floatId, x, y, vw, vh));

  /// Resizes a free window from its SE corner; the commit on release.
  void resizeFloat(String floatId, double w, double h, double vw, double vh) =>
      _apply(_state.resizeFloat(floatId, w, h, vw, vh));

  /// Brings a free window to the top of the stack.
  void raiseFloat(String floatId) => _apply(_state.raiseFloat(floatId));

  /// Docks a free window back, into [toPane] or the active pane.
  void dockFloat(String floatId, [String? toPane]) =>
      _apply(_state.dockFloat(floatId, toPane));

  /// Closes the free window holding [tabId] — the tab goes with it.
  void closeFloatByTab(String tabId) => _apply(_state.closeFloatByTab(tabId));

  // --- Tab and pane gestures ---

  void closeTab(String paneId, String tabId) =>
      _apply(_state.closeTab(paneId, tabId));

  /// The strip's right-click pair: close everything but [keepId], or everything.
  void closeOtherTabs(String paneId, String keepId) =>
      _apply(_state.closeOtherTabs(paneId, keepId));

  void closeAllTabs(String paneId) => _apply(_state.closeAllTabs(paneId));

  void activateTab(String paneId, String tabId) =>
      _apply(_state.activateTab(paneId, tabId));

  void focusPane(String paneId) => _apply(_state.focusPane(paneId));

  void patchTab(
    String tabId, {
    String? title,
    String? path,
    Map<String, Object?>? meta,
  }) => _apply(_state.patchTab(tabId, title: title, path: path, meta: meta));

  void splitPane(SplitDirection dir) => _apply(_state.splitPane(dir));

  void moveTab(String fromPane, String tabId, String toPane, [int index = -1]) =>
      _apply(_state.moveTab(fromPane, tabId, toPane, index));

  void moveTabToEdge(
    String fromPane,
    String tabId,
    String toPane,
    DropZone zone,
  ) => _apply(_state.moveTabToEdge(fromPane, tabId, toPane, zone));

  /// Sends [tabId] of [fromPane] to the other panel — the header button that
  /// stands in for dragging the tab there, so a tab can change panels without a
  /// pointer.
  void sendTabToOtherPanel(String fromPane, String tabId) =>
      _apply(_state.moveTabToOtherTree(fromPane, tabId));

  void resize(String splitId, int index, double delta) =>
      _apply(_state.resize(splitId, index, delta));

  void toggleExpanded(String path) => _apply(_state.toggleExpanded(path));

  // --- WorkbenchSink ---

  @override
  String? open(OpenTarget target) {
    switch (target.kind) {
      case OpenKind.file:
        openFile(target.target, line: target.line);
        return null;
      case OpenKind.folder:
        openFolder(target.target);
        return null;
      case OpenKind.url:
        // The browser tab is where a URL goes — the model's `sidebar_open`
        // link clicks land here, same as a typed address.
        openBrowser(target.target);
        return null;
    }
  }

  @override
  void reveal(Iterable<String> paths) {
    final root = _workspaceRoot;
    if (root == null) return;
    _apply(_state.reveal(root, paths));
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  /// The single write path: keep it, persist it, announce it.
  ///
  /// Identity-checked, because most reducers return the receiver when the gesture
  /// was a no-op and a notification for one would rebuild the whole workbench.
  void _apply(SidebarState next) {
    if (identical(next, _state)) return;
    _state = next;
    if (_session != _unsaved) _store.save(_session, next);
    notifyListeners();
  }
}
