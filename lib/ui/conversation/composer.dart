// The input card.
//
// A port of `InputBar.module.css`: a floating capsule with the draft on top and
// a control row below, capped at the content width plus 32px — the one element in
// the column allowed to be wider than the transcript.
//
// The control row is dsh's toolbar: the attach (paperclip) and mode chips sit
// on the left of the primary action. The attach chip offers a file pick and a
// clipboard paste (via `pasteboard`); the picked images ride the send as
// data-URI media. The mode chip is the PermissionSelect — ask / plan / auto —
// and is live: it flips the [ApprovalMode] the gated tools consult per call.
//
// Typing `/` as the first character of the draft opens the command menu above
// the card: the three mode switches and "new session", filtered by the token.

import 'dart:io' show Platform, Process;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadBorder, ShadButton, ShadDecoration, ShadInput, ShadOption;

import '../../l10n/locales.dart';
import '../../model/approval_mode.dart';
import '../../model/attached_image.dart';
import '../../model/file_search_rank.dart';
import '../../model/known_models.dart';
import '../../model/queued_input.dart';
import '../../model/workspace_index.dart';
import '../../state/document_extractor.dart';
import '../../state/model_directory.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_shad_bridge.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../primitives/tappable.dart';
import '../primitives/feedback.dart';
import '../primitives/menu.dart';
import '../appearance_scope.dart';
import '../../theme/dsw_typography.dart';
import 'conversation_root.dart';

/// A draft put down when its conversation was: the text, and the attachments
/// that were riding it. In memory for this run only — a draft that outlived the
/// app would need a store, a slot in the backup zip, and a reason to survive a
/// restart that "I was typing this" does not give.
typedef _Draft = ({
  String text,
  List<AttachedImage> images,
  List<_AttachedDocument> docs,
});

class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.hero,
    required this.busy,
    required this.blocked,
    required this.approvalMode,
    required this.onSubmit,
    required this.onStop,
    this.onApprovalMode,
    this.onNewSession,
    this.modelDirectory,
    this.onModelSelected,
    this.onLookupFiles,
    this.workspaceRoot,
    this.onPickWorkspace,
    this.onOpenSettings,
    this.draftScope,
  });

  /// Which conversation the draft being typed belongs to — the session id, or
  /// null while the first send has not named it yet.
  ///
  /// The card is one widget that survives a session switch (the controller is
  /// reused, and the GlobalKey re-parents rather than rebuilds), so without a
  /// scope a half-typed message and its picked files simply walked into whatever
  /// conversation the user clicked next and sent there. Changing this parks the
  /// draft under the old scope and loads the new one's (ADR-0051).
  final String? draftScope;

  /// The centred empty-state variant: no bottom pad, and a two-line floor.
  final bool hero;

  /// A turn is running, so the primary action stops it instead of sending.
  final bool busy;

  /// Sending would be refused — a turn is running, or an approval is pending.
  final bool blocked;

  /// How gated tool calls will decide; the chip both reads and writes it.
  final ApprovalMode approvalMode;

  /// Sends [text] with any [images] the row is holding, at [delivery]'s pace:
  /// behind the running turn, or into it (ADR-0013). The row does not know
  /// whether a turn is running — it always hands the input over, and the
  /// controller decides whether that becomes a turn or a queue row.
  final void Function(
    String text,
    List<AttachedImage> images,
    InputDelivery delivery,
  )
  onSubmit;

  final VoidCallback onStop;

  /// Mode changes, live. Optional only because the tests that predate the
  /// selector do not exercise it.
  final ValueChanged<ApprovalMode>? onApprovalMode;

  /// The `/new` command's target. Absent means the menu does not offer it.
  final VoidCallback? onNewSession;

  /// The model seat's directory — dsh's `conversation.input.model`. Absent
  /// keeps the row as it was (tests, previews); the chip is the one control
  /// that needs it.
  final ModelDirectory? modelDirectory;

  /// Commits a model the seat picked. Absent leaves the chip inert — the
  /// same contract as [onApprovalMode].
  final ValueChanged<String>? onModelSelected;

  /// Supplies the workspace file index for the `@` mention menu — the
  /// host-owned seam dsh-at-file's Remote occupied. Absent disables the
  /// feature: an `@` types as plain text.
  final Future<List<FileEntry>> Function()? onLookupFiles;

  /// The current workspace root path. Shown in the status bar below the card;
  /// absent hides the bar entirely (no workspace picked yet).
  final String? workspaceRoot;

  /// Opens the workspace picker. The status bar is the second entry point
  /// alongside the hero picker — both lead to the same dialog.
  final VoidCallback? onPickWorkspace;

  /// Opens the full-screen settings view (ADR-0006). The model menu's footer
  /// links here — "模型管理" is the third entry point alongside the sidebar
  /// gear and the quick menu's bottom row.
  final VoidCallback? onOpenSettings;

  @override
  State<Composer> createState() => ComposerState();
}

class ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKeyEvent);

  /// The images riding the next send, in pick order.
  final _images = <AttachedImage>[];

  /// Documents picked for text extraction. Each entry holds the display name
  /// and the extracted text (null while extraction is in flight).
  final _documents = <_AttachedDocument>[];

  /// The `/`-token the menu was dismissed for, or null when it is open. Escape
  /// dismisses it for the current token only; a different token reopens it.
  String? _dismissedToken;

  // -------------------------------------------------------------------------
  // Workspace status bar
  // -------------------------------------------------------------------------

  /// The current git branch, or null when the workspace is not a repo or the
  /// query has not landed. Cached per workspace root — a root change invalidates
  /// it and triggers a fresh query.
  String? _gitBranch;

  /// Stale-response guard for the branch query.
  int _branchGeneration = 0;

  final Map<String, _Draft> _parked = {};

  String get _scope => widget.draftScope ?? '__new__';

  @override
  void didUpdateWidget(covariant Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workspaceRoot != oldWidget.workspaceRoot) {
      _gitBranch = null;
      _queryBranch();
      // The `@` menu indexes the folder, so it belongs to the folder that is
      // gone. Left alone, the card kept ranking the previous project's files
      // for the rest of its life — the card survives a folder change (it is the
      // same composer), and the generation bump stops a fetch that was already
      // in flight from landing on top of the new root.
      _fileIndex = null;
      _indexLoading = false;
      _indexGeneration++;
      // The fetch is otherwise fired by a keystroke (see [_onDraftChanged]), and
      // a folder switch is not one: with the `@` menu already open, the card
      // would sit on an empty index until the user typed again.
      if (widget.onLookupFiles != null && _activeMentionToken != null) {
        _ensureFileIndex();
      }
    }
    final previous = oldWidget.draftScope ?? '__new__';
    if (previous == _scope) return;
    // Swap, do not merge: the draft on screen is the outgoing conversation's,
    // and the incoming one's is whatever was left here last time.
    _parked[previous] = (
      text: _controller.text,
      images: List.of(_images),
      docs: List.of(_documents),
    );
    final restored = _parked[_scope];
    _controller.text = restored?.text ?? '';
    _images
      ..clear()
      ..addAll(restored?.images ?? const []);
    _documents
      ..clear()
      ..addAll(restored?.docs ?? const []);
    // The menus' dismissal is per-draft: a token dismissed in one conversation
    // says nothing about this one.
    _dismissedToken = null;
    _dismissedMentionToken = null;
    _wasEmpty = _controller.text.trim().isEmpty;
    setState(() {});
  }

  /// Queries the current branch for [workspaceRoot]. A single `git rev-parse`
  /// call — the lightest possible probe, and it fails silently when the folder
  /// is not a repo (the bar just shows the workspace name).
  Future<void> _queryBranch() async {
    final root = widget.workspaceRoot;
    if (root == null) return;
    final generation = ++_branchGeneration;
    try {
      final result = await Process.run('git', [
        'rev-parse',
        '--abbrev-ref',
        'HEAD',
      ], workingDirectory: root);
      if (!mounted || generation != _branchGeneration) return;
      if (result.exitCode == 0) {
        setState(() => _gitBranch = (result.stdout as String).trim());
      }
    } catch (_) {
      // Not a repo, git not installed, or any other failure — the bar degrades
      // to workspace-name-only, which is still useful.
    }
  }

  // -------------------------------------------------------------------------
  // The @ mention menu (dsh-at-file)
  // -------------------------------------------------------------------------

  /// The workspace index the mention menu ranks against: fetched on the token's
  /// first open and kept for the card's life, dropped when the folder changes.
  /// Null while no fetch has landed.
  List<FileEntry>? _fileIndex;

  /// Whether the index fetch is in flight.
  bool _indexLoading = false;

  /// Stale-response guard: a fetch the token outlived cannot land.
  int _indexGeneration = 0;

  /// The `@`-token the mention menu was dismissed for (Escape), or null.
  String? _dismissedMentionToken;

  /// The workspace entries matching the draft's active `@` token, in the
  /// plugin's ranked order. Empty when the menu should not show.
  List<FileEntry> get _mentionMatches {
    final lookup = widget.onLookupFiles;
    if (lookup == null || _fileIndex == null) return const [];
    final token = _activeMentionToken;
    if (token == null) return const [];
    // Dismissal is per-QUERY: retyping the same `@token` stays closed until
    // the token changes, the command menu's own dismissal rule.
    if (_dismissedMentionToken == token.query) return const [];
    return rankFiles(_fileIndex!, token.query, _mentionMenuCap);
  }

  /// The menu's candidate cap — the plugin's `MAX_CANDIDATES`.
  static const _mentionMenuCap = 50;

  /// The draft's active `@` token: the last `@`-run in the text that has not
  /// been closed by a space. A cursor-position version of the plugin's
  /// trigger pipeline — the whole token is the query, and finishing it (a
  /// space) is what closes the menu.
  _ActiveMention? get _activeMentionToken {
    final text = _controller.text;
    if (text.isEmpty) return null;
    final lastAt = text.lastIndexOf('@');
    if (lastAt < 0) return null;
    final token = text.substring(lastAt + 1);
    // A closed token — anything after the `@` contains whitespace or another
    // `@` — is prose, not a lookup.
    if (token.contains(RegExp(r'[\s@]'))) return null;
    return _ActiveMention(start: lastAt, query: token);
  }

  /// Loads the index when the token first opens. The plugin fetches once per
  /// session with a TTL; this build refetches per menu-open because the
  /// fsRevision counter already covers the staleness in between.
  void _ensureFileIndex() {
    final lookup = widget.onLookupFiles;
    if (lookup == null || _indexLoading || _fileIndex != null) return;
    final generation = ++_indexGeneration;
    _indexLoading = true;
    lookup()
        .then((entries) {
          if (!mounted || generation != _indexGeneration) return;
          setState(() {
            _fileIndex = entries;
            _indexLoading = false;
          });
        })
        .catchError((_) {
          if (!mounted || generation != _indexGeneration) return;
          // An index that cannot be read offers nothing; the `@` types as text
          // rather than showing an error menu.
          setState(() => _indexLoading = false);
        });
  }

  /// Inserts the picked entry: the token becomes the readable `@path` and the
  /// cursor lands after it. A directory pick ends in `/` with NO space — the
  /// query stays open, so the menu keeps offering the directory's children
  /// (the plugin's continuation flow); a file pick ends in a space, which
  /// closes the token and with it the menu.
  void _insertMention(FileEntry entry) {
    final token = _activeMentionToken;
    if (token == null) return;
    final suffix = entry.kind == 'dir' ? '/' : ' ';
    final replacement = '@${entry.relative}$suffix';
    _controller.value = TextEditingValue(
      text:
          '${_controller.text.substring(0, token.start)}$replacement'
          '${_controller.text.substring(token.start + 1 + token.query.length)}',
      selection: TextSelection.collapsed(
        offset: token.start + replacement.length,
      ),
    );
    _dismissedMentionToken = null;
    // A directory pick keeps the menu open (the query is now the path's
    // prefix); a file pick closes it — the trailing space closed the token.
    if (entry.kind != 'dir') {
      setState(() => _wasEmpty = false);
    } else {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    // Drives the primary action's enabled state; the draft itself repaints
    // through the field.
    _controller.addListener(_onDraftChanged);
    // And the card's stroke needs a repaint the field never asks for: focus is
    // the container's state, not the text's.
    _focus.addListener(_onFocusChanged);
    if (widget.workspaceRoot != null) _queryBranch();
  }

  void _onFocusChanged() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _wasEmpty = true;

  /// Whether the pointer is over the input card — the middle of the card's three
  /// strokes, see [_card].
  bool _cardHovered = false;

  void _onDraftChanged() {
    final text = _controller.text;
    final empty = text.trim().isEmpty;
    // An `@`-token being typed must repaint this state too: the mention
    // menu's candidates — and the index fetch the token's first `@` fires —
    // are functions of the text the same way the command menu's are.
    final mention = widget.onLookupFiles != null && _activeMentionToken != null;
    if (mention) _ensureFileIndex();
    // The empty transition drives the send button. A `/`-prefixed draft must
    // repaint on EVERY keystroke: the command menu's filter — and its
    // open/closed edge, when a dismissed token is retyped past — are functions
    // of the text, and the field repaints itself, not this state.
    if (!text.startsWith('/') && !mention && empty == _wasEmpty) return;
    setState(() => _wasEmpty = empty);
  }

  /// Enter leaves the draft, Shift+Enter breaks the line — and Enter *while an
  /// input method is composing* belongs to the input method.
  ///
  /// The last clause is the one that decides whether a Chinese user can type
  /// here at all: in a pinyin candidate list Enter picks the word, and this
  /// handler used to read it as "send", handing the model the half of the
  /// sentence that had already landed. The reference gates the same keystroke
  /// twice (`LexicalChatInput.tsx:548-550`, `:140`); Flutter's equivalent fact is
  /// a non-collapsed `composing` range (ADR-0050).
  ///
  /// While a turn runs, Enter queues the draft and Cmd/Ctrl+Enter steers it —
  /// the reversed delivery the reference ships (`followupModeSettings.ts:18-24`),
  /// so choosing where a draft goes never costs a hand off the keyboard.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      // Escape dismisses the command menu for the current token. Handled HERE
      // rather than in a CallbackShortcuts around the menu: the menu is a
      // sibling of the field in the tree, so a shortcut inside it never sees
      // a key the focused field is the origin of.
      if (_commandMatches.isNotEmpty) {
        setState(() => _dismissedToken = _controller.text.substring(1));
        return KeyEventResult.handled;
      }
      // The mention menu dismisses the same way, for its own token.
      final mentionToken = _activeMentionToken;
      if (mentionToken != null && _mentionMatches.isNotEmpty) {
        setState(() => _dismissedMentionToken = mentionToken.query);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      // Cmd/Ctrl-V while an image sits on the clipboard: the field's own paste
      // would insert nothing, so the paste is claimed here instead. Left
      // unhandled when the clipboard has no image — the async check cannot
      // decide in time, so the text paste proceeds and a found image simply
      // lands a beat later.
      if (key == LogicalKeyboardKey.keyV &&
          (HardwareKeyboard.instance.isMetaPressed ||
              HardwareKeyboard.instance.isControlPressed)) {
        _pasteClipboardImage();
      }
      return KeyEventResult.ignored;
    }
    if (_isComposing || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final steer =
        widget.busy &&
        (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed);
    _submit(delivery: steer ? InputDelivery.guide : InputDelivery.queue);
    return KeyEventResult.handled;
  }

  /// Whether an input method holds the caret right now — a candidate list open,
  /// a stroke not yet committed to the text.
  bool get _isComposing => !_controller.value.composing.isCollapsed;

  void _submit({InputDelivery delivery = InputDelivery.queue}) {
    var text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty && _documents.isEmpty) return;
    _controller.clear();
    final images = List<AttachedImage>.of(_images);
    _images.clear();
    final docs = List<_AttachedDocument>.of(_documents);
    _documents.clear();
    setState(() => _wasEmpty = true);
    // Prepend extracted document text as context ahead of the user's words.
    final docBlocks = docs
        .where((d) => d.text != null && d.text!.isNotEmpty)
        .map((d) => '[${d.name}]\n${d.text!.trim()}')
        .join('\n\n');
    if (docBlocks.isNotEmpty) {
      text = text.isEmpty ? docBlocks : '$docBlocks\n\n$text';
    }
    widget.onSubmit(text, images, delivery);
  }

  void _onPrimary() {
    if (_showsStop) {
      widget.onStop();
      return;
    }
    _submit();
  }

  /// The button follows the draft, not the transcript (ADR-0050). A user who has
  /// typed something is saying "send this" — and while a turn holds the
  /// transcript, sending means queueing, which is exactly what ADR-0013 built.
  /// The old rule made `busy` win, so writing a follow-up turned the primary
  /// action into "stop the run" and the draft you were looking at had a button
  /// that did not speak of it. Stop keeps two other doors: this button on an
  /// empty box, and Escape.
  bool get _showsStop => widget.busy && !_hasPayload;

  // ---------------------------------------------------------------------------
  // Image attachment
  // ---------------------------------------------------------------------------

  /// The one door images come in through: the picker, the clipboard, a drop.
  ///
  /// An image the selected model cannot be sent is refused here, with the
  /// reason, while the user still has the file — instead of vanishing at the
  /// provider after the send already cleared the chips (ADR-0010). No model
  /// directory (tests, previews) means no gate.
  void _attachImages(List<AttachedImage> incoming) {
    if (incoming.isEmpty) return;
    final directory = widget.modelDirectory;
    if (directory == null || directory.acceptsImages) {
      setState(() => _images.addAll(incoming));
      return;
    }
    showFeedback(
      context,
      context.tr('imagesUnsupportedByModel', {
        'model': directory.selectedModel,
      }),
      destructive: true,
    );
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || !mounted) return;
      final picked = <AttachedImage>[];
      for (final file in result.files) {
        final path = file.path;
        if (path == null) continue;
        final image = AttachedImage.fromFile(path);
        if (image != null) picked.add(image);
      }
      _attachImages(picked);
    } on PlatformException {
      // The picker is unavailable (a test harness, a headless run): the menu
      // item simply does nothing rather than killing the card.
    }
  }

  Future<void> _pickDocuments() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (result == null || !mounted) return;
      for (final file in result.files) {
        final path = file.path;
        if (path == null) continue;
        if (!isExtractable(path)) continue;
        _addDocument(path);
      }
    } on PlatformException {
      // Picker unavailable; nothing to do.
    }
  }

  void _addDocument(String path) {
    final name = path.split(Platform.pathSeparator).last;
    final doc = _AttachedDocument(name: name, text: null);
    setState(() => _documents.add(doc));
    extractText(path).then((text) {
      if (!mounted) return;
      setState(() => doc.text = text ?? '');
    });
  }

  Future<void> _pasteClipboardImage() async {
    try {
      final bytes = await Pasteboard.image;
      if (bytes == null || bytes.isEmpty) return;
      _addPaste(bytes);
    } on PlatformException {
      // No platform channel (tests); nothing to paste.
    }
  }

  void _addPaste(Uint8List bytes) {
    if (!mounted) return;
    _attachImages([
      AttachedImage(
        name: 'pasted-${_images.length + 1}.png',
        bytes: bytes,
        mediaType: 'image/png',
      ),
    ]);
  }

  /// Adds files from a drag-and-drop event. Images become visual attachments;
  /// extractable documents (text files, PDFs) become text attachments; other
  /// files are silently skipped.
  void addDroppedFiles(List<String> paths) {
    if (!mounted || paths.isEmpty) return;
    final picked = <AttachedImage>[];
    for (final path in paths) {
      final image = AttachedImage.fromFile(path);
      if (image != null) {
        picked.add(image);
      } else if (isExtractable(path)) {
        _addDocument(path);
      }
    }
    _attachImages(picked);
  }

  // ---------------------------------------------------------------------------
  // The command menu
  // ---------------------------------------------------------------------------

  /// The commands on offer, as (command, label, description, icon, action).
  ///
  /// Rebuilt per build rather than cached: the `/new` entry depends on the
  /// callback being present, and the list is three entries long.
  List<_CommandEntry> get _commands => [
    _CommandEntry(
      command: '/ask',
      label: 'commandAskMode',
      description: 'commandAskModeDesc',
      icon: LucideIcons.shield_question_mark,
      action: () => widget.onApprovalMode?.call(ApprovalMode.ask),
    ),
    _CommandEntry(
      command: '/plan',
      label: 'commandPlanMode',
      description: 'commandPlanModeDesc',
      icon: LucideIcons.clipboard_list,
      action: () => widget.onApprovalMode?.call(ApprovalMode.plan),
    ),
    _CommandEntry(
      command: '/auto',
      label: 'commandAutoMode',
      description: 'commandAutoModeDesc',
      icon: LucideIcons.zap,
      action: () => widget.onApprovalMode?.call(ApprovalMode.auto),
    ),
    if (widget.onNewSession != null)
      _CommandEntry(
        command: '/new',
        label: 'commandNewSession',
        description: 'commandNewSessionDesc',
        icon: LucideIcons.plus,
        action: widget.onNewSession!,
      ),
  ];

  /// The commands matching the draft's leading `/`-token, or empty when the
  /// menu should not show.
  List<(_CommandEntry, String)> get _commandMatches {
    final text = _controller.text;
    if (!text.startsWith('/')) return const [];
    final token = text.substring(1);
    if (token.contains(' ')) return const [];
    if (_dismissedToken == token) return const [];
    final lower = token.toLowerCase();
    return [
      for (final entry in _commands)
        if (lower.isEmpty || entry.command.substring(1).startsWith(lower))
          (entry, entry.command),
    ];
  }

  void _runCommand(_CommandEntry entry) {
    _controller.clear();
    setState(() {
      _wasEmpty = true;
      _dismissedToken = null;
    });
    entry.action();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      // Sides ride the shared clearance; the docked variant also clears 8px of
      // the window edge.
      padding: EdgeInsets.only(
        left: composerSideClearance,
        right: composerSideClearance,
        bottom: widget.hero ? 0 : 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                AppearanceScope.widthOf(context, chatContentWidth) +
                composerCardWidthInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The command menu floats above the card while the draft's
              // leading token is a `/`-command. Growing the column upward is
              // what "above" means here: the seat measures whatever this
              // stack is, and the transcript pays for it in padding either
              // way. The mention menu shares the seat — dsh's
              // `conversation.input.overlay` — and the two never show at once:
              // a token starts with either `/` or `@`, not both.
              if (_commandMatches.isNotEmpty) ...[
                _commandMenu(color),
                const SizedBox(height: 6),
              ] else if (_mentionMatches.isNotEmpty || _indexLoading) ...[
                _mentionMenu(color),
                const SizedBox(height: 6),
              ],
              _card(color),
              // The workspace status bar: sits below the card, shows the
              // workspace name and (when available) the git branch. Clicking
              // it opens the same picker the hero uses.
              if (widget.workspaceRoot != null && !widget.hero)
                _workspaceStatusBar(color),
            ],
          ),
        ),
      ),
    );
  }

  /// The `/`-command list, filtered by the draft's token. Escape (handled by
  /// the draft's focus node, where the keys actually arrive) dismisses it for
  /// the current token; any draft change brings it back.
  Widget _commandMenu(DswAlias color) {
    final matches = _commandMatches;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.bgLayer2,
        border: Border.all(color: color.borderL2),
        borderRadius: BorderRadius.circular(DswShape.shell),
        boxShadow: DswShadow.lv2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Text(
              context.tr('commands'),
              style: DswType.xxxsStrong11.copyWith(color: color.labelTertiary),
            ),
          ),
          for (final (entry, _) in matches)
            _CommandRow(entry: entry, onRun: () => _runCommand(entry)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// The `@` mention menu — dsh-at-file's picker: the command menu's chrome
  /// (its own card, 6px above the input) holding ranked file rows instead.
  /// While the index loads, the menu shows its loading seat rather than
  /// nothing, so the `@` that opened it visibly did something.
  Widget _mentionMenu(DswAlias color) {
    final matches = _mentionMatches;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.bgLayer2,
        border: Border.all(color: color.borderL2),
        borderRadius: BorderRadius.circular(DswShape.shell),
        boxShadow: DswShadow.lv2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Text(
              context.tr('files'),
              style: DswType.xxxsStrong11.copyWith(color: color.labelTertiary),
            ),
          ),
          if (_indexLoading && matches.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Text(
                context.tr('searchingFiles'),
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 264),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 4),
                children: [
                  for (final entry in matches)
                    _MentionRow(
                      entry: entry,
                      onPick: () => _insertMention(entry),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// The input card's stroke. It used to answer the keyboard with a third
  /// colour (`brandPrimary` on focus, ZCode's `focus-within:`); the 2026-10-01
  /// walkthrough judged the focus stroke noise — the caret already says where
  /// the keystrokes land — and reverted the card to a two-state border:
  /// rest at 6%, hover one notch brighter. ADR-0038 records the reversal.
  Widget _card(DswAlias color) {
    final stroke = _cardHovered ? color.borderL3 : color.borderL2DarkmodeThin;
    return MouseRegion(
      onEnter: (_) => setState(() => _cardHovered = true),
      onExit: (_) => setState(() => _cardHovered = false),
      child: AnimatedContainer(
        duration: DswMotion.respecting(context, DswMotion.fast),
        curve: DswMotion.easeInOut,
        decoration: BoxDecoration(
          color: color.inputMajor,
          // One notch weaker than a button's stroke at rest, per the darkmode
          // note in the source: exactly the l2-darkmode-thin pair.
          border: Border.all(color: stroke),
          borderRadius: BorderRadius.circular(DswShape.float),
          boxShadow: DswShadow.lv1,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            _draft(color),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 6),
              _imageChips(color),
            ],
            if (_documents.isNotEmpty) ...[
              const SizedBox(height: 6),
              _documentChips(color),
            ],
            const SizedBox(height: 12),
            _row(color),
          ],
        ),
      ),
    );
  }

  Widget _draft(DswAlias color) => ConstrainedBox(
    constraints: BoxConstraints(
      // Past the shared cap the draft scrolls rather than growing the card.
      maxHeight: composerTextMaxHeight,
      // The hero card keeps a two-line floor (~2 x 24 line + 4pt of pad).
      minHeight: widget.hero ? 52 : 0,
    ),
    child: dswEnsureShadTheme(
      context,
      ShadInput(
        controller: _controller,
        focusNode: _focus,
        autofocus: true,
        maxLines: null,
        // The card is the scroll surface; a field that scrolled itself would put
        // its own gutter inside the capsule.
        keyboardType: TextInputType.multiline,
        style: DswType.base16.copyWith(color: color.labelPrimary),
        // No frame and no fill of its own: the card's three-state stroke is the
        // one thing on screen that says the keystrokes land here (ADR-0017 S2b),
        // and a field that lit its own ring would answer that twice.
        decoration: dswBareInput,
        // figma .InputText 34:10434: pl 16 / pr 12 / pt 4.
        padding: const EdgeInsets.only(left: 16, right: 12, top: 4),
        // The hint says what a send would do *now*: while a turn holds the
        // transcript, typing here queues (ADR-0050) — and the idle sentence,
        // "ask anything", would be describing a different state.
        placeholder: dswInputHint(
          widget.busy
              ? context.tr('queueDraftHint')
              : context.tr('askAnythingHint'),
        ),
        placeholderStyle: DswType.base16.copyWith(color: color.labelCaption),
      ),
    ),
  );

  /// The picked images as a horizontal strip of thumbnails, each with its own
  /// remove affordance — the row the draft sends is the row on screen.
  Widget _imageChips(DswAlias color) => SizedBox(
    height: 56,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _images.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final image = _images[index];
        return _ImageChip(
          image: image,
          onRemove: () => setState(() => _images.removeAt(index)),
        );
      },
    ),
  );

  /// Document chips: a file icon + the name, with a remove affordance. While
  /// extraction is in flight the text is null and a small spinner replaces the
  /// icon — the chip stays interactive (remove works) throughout.
  Widget _documentChips(DswAlias color) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (var i = 0; i < _documents.length; i++)
        _DocumentChip(
          doc: _documents[i],
          onRemove: () => setState(() => _documents.removeAt(i)),
        ),
    ],
  );

  Widget _row(DswAlias color) => Padding(
    // 2px of the bottom pad moved to the top: the whole control row sits 2px
    // lower in the card without changing its height. Right pad is 4px (not 8)
    // so the send button sits at the card's edge — the model chip and button
    // are the trailing group and should feel anchored to the right.
    padding: const EdgeInsets.fromLTRB(8, 2, 4, 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // A re-expanded sidebar over a narrow window squeezes the centre
        // column to nearly the attach and send buttons' own width; past that
        // point the chip gives up its seat rather than overflowing the card.
        // The mode lives on in the transcript's mode chips, so nothing is
        // lost that the conversation was not already saying.
        //
        // One floor for both menus. They each shed their label and stroke on
        // their own well before this, so the model chip's second, earlier
        // ceiling only made it disappear while there was still room for it as
        // an icon — and a model you cannot change is not a degradation, it is
        // a missing control.
        final seatsFit = constraints.maxWidth >= 140;
        // The parked-draft pair is the widest fixed content on this line, so it
        // is the first to shed its labels: the icons already name the two
        // destinations a draft can go, and the tooltip carries the words.
        // Below this the row was overflowing by 67px with both menus and both
        // chips labelled — measured, not guessed.
        final actionsFit = constraints.maxWidth >= 360;
        // dsh's `.row`: space-between — the tools (attach, mode) on the left,
        // the trailing group (model seat, send) on the right. The model seat
        // rides `conversation.input.model` beside the primary action, NOT in
        // the tools: it is a property of the next send, like the button, not
        // a modifier of the draft, like the attachments.
        // Two clusters, and the slack belongs to the gap between them. A flat
        // list with a `Spacer` could not say that: the two chips' `Flexible`
        // each claimed a share of the slack and handed their unused parts back
        // at the END of the row, so the send sat 60px off the edge this row's
        // comment had been promising it was anchored to (measured at 900px, now
        // guarded). The trailing group is laid out first and keeps its floor;
        // the left cluster absorbs both the slack and the squeeze.
        //
        // 84px is the left cluster at its tightest — attach (34) + 4 + the mode
        // chip down to its glyph and a couple of characters — measured, not
        // guessed: at 94 the 260px case overflowed by 10. The bound only applies
        // while the chips are seated at all; below `seatsFit` the trailing group
        // is just the send, and squeezing it to a fraction of its own box is a
        // layout blowup, not a degradation.
        final trailingCeiling = seatsFit
            ? constraints.maxWidth - 84
            : double.infinity;
        return Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  _AttachButton(
                    onPick: _pickImages,
                    onPickDocuments: _pickDocuments,
                    onPaste: _pasteClipboardImage,
                  ),
                  const SizedBox(width: 4),
                  if (seatsFit) ...[
                    // Flexible rather than fixed: the chip's label ellipsizes
                    // before the row ever gets this tight.
                    Flexible(
                      child: _ModeChip(
                        mode: widget.approvalMode,
                        onSelect: widget.onApprovalMode == null
                            ? null
                            : (mode) => widget.onApprovalMode!(mode),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: trailingCeiling),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.modelDirectory != null && seatsFit) ...[
                    Flexible(
                      child: _ModelChip(
                        directory: widget.modelDirectory!,
                        onSelect: widget.onModelSelected,
                        onOpenSettings: widget.onOpenSettings,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _deliverChips(color, tight: !actionsFit),
                  _primary(color),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  /// The 34px send / stop circle. Both states share the button, so the toggle is
  /// a glyph swap rather than a layout change — and which glyph it is follows
  /// [_showsStop]: a draft wins over the stop sign, because a draft is what the
  /// user is looking at.
  Widget _primary(DswAlias color) {
    final stop = _showsStop;
    final enabled = stop || _hasPayload;
    return Tooltip(
      message: stop
          ? context.tr('stop')
          : widget.busy
          // While a turn runs this button queues — the same destination Enter
          // has, said in the tooltip so the two do not look like different
          // doors.
          ? context.tr('deliveryQueue')
          : context.tr('send'),
      child: _PrimaryButton(
        color: color,
        enabled: enabled,
        onTap: enabled ? _onPrimary : null,
        child: Icon(
          stop ? LucideIcons.square : LucideIcons.arrow_up,
          size: DswShape.iconMd,
          // Static white in both themes: the glyph sits on the blue fill.
          color: Colors.white,
        ),
      ),
    );
  }

  /// A draft is something to do with even while a turn holds the transcript.
  /// `_wasEmpty` tracks the text, but an image or document alone counts too —
  /// the same three-way guard `_submit` applies.
  bool get _hasPayload =>
      !_wasEmpty || _images.isNotEmpty || _documents.isNotEmpty;

  /// The two ways a draft leaves while the transcript is busy: park it behind
  /// the run, or steer the run with it. They show only then, because an idle
  /// composer already sends from its primary circle.
  ///
  /// [tight] sheds the labels, not the controls: the tooltip and the semantic
  /// label already carry the words, and a queue button that cannot be reached
  /// because the row overflowed is not a degradation.
  Widget _deliverChips(DswAlias color, {required bool tight}) {
    if (!widget.blocked || !_hasPayload) return const SizedBox.shrink();
    return Row(
      children: [
        _DeliverChip(
          color: color,
          icon: LucideIcons.list_end,
          label: context.tr('queueInput'),
          tip: context.tr('deliveryQueue'),
          tight: tight,
          onTap: () => _submit(delivery: InputDelivery.queue),
        ),
        const SizedBox(width: 6),
        _DeliverChip(
          color: color,
          icon: LucideIcons.route,
          label: context.tr('guideNow'),
          tip: context.tr('deliveryGuide'),
          tight: tight,
          onTap: () => _submit(delivery: InputDelivery.guide),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// The workspace status bar: a single line below the composer card showing
  /// the workspace name and (when the folder is a git repo) the current branch.
  /// Clicking it opens the workspace picker — the same entry point as the hero.
  ///
  /// Format: `flutter_agent_harness  本地  develop` (Qoder style).
  /// "本地" is the local-repo indicator; it is always shown because the bar
  /// only appears when a workspace is picked, and a picked workspace is by
  /// definition local.
  Widget _workspaceStatusBar(DswAlias color) {
    final root = widget.workspaceRoot!;
    // The folder name, not the full path — the bar is a hint, not a file browser.
    final name = root.split(Platform.pathSeparator).last;
    final branch = _gitBranch;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DswHoverTap(
        onTap: widget.onPickWorkspace,
        semanticLabel: context.tr('workspaceStatusBar'),
        builder: (context, hovered, _) => Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: hovered ? color.interactiveBgHover : null,
            borderRadius: BorderRadius.circular(DswShape.inner),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.folder_open,
                size: DswShape.iconSm,
                color: color.labelTertiary,
              ),
              const SizedBox(width: 6),
              // The two free-text parts share whatever the fixed parts leave,
              // and each ellipsizes on its own. Without this the bar overflowed
              // by 487px on a long folder name — the row would rather paint
              // outside the card than shorten a name.
              Flexible(
                flex: 2,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.xxs12.copyWith(color: color.labelSecondary),
                ),
              ),
              const SizedBox(width: 8),
              // The "本地" (local) indicator — Qoder shows it to distinguish
              // local repos from remote ones. This app only has local, so it
              // is always shown when a workspace is picked.
              Text(
                context.tr('localRepo'),
                style: DswType.xxs12.copyWith(color: color.labelTertiary),
              ),
              if (branch != null) ...[
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.git_branch,
                  size: DswShape.iconTiny,
                  color: color.labelTertiary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    branch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxs12.copyWith(color: color.labelTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The active `@` token: where it starts in the draft and its query — the
/// two facts an insertion needs besides the entry itself.
class _ActiveMention {
  const _ActiveMention({required this.start, required this.query});

  /// The index of the `@` itself.
  final int start;

  /// The text between the `@` and the token's end.
  final String query;

  @override
  bool operator ==(Object other) =>
      other is _ActiveMention && other.start == start && other.query == query;

  @override
  int get hashCode => Object.hash(start, query);
}

/// One file row of the `@` menu — the plugin's picker row: the basename as
/// the label (with the parent directory appended when the name collides),
/// the parent directory as the second line, and a kind glyph. A directory
/// pick keeps the menu open (`@src/` continues); a file pick closes it.
class _MentionRow extends StatelessWidget {
  const _MentionRow({required this.entry, required this.onPick});

  final FileEntry entry;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final entry = this.entry;
    final name = basenameOf(entry.relative);
    final directory = dirnameOf(entry.relative);
    final isDir = entry.kind == 'dir';
    // The row's own text is its accessible name; DswHoverTap makes the pick
    // reachable by keyboard, not just a pointer tap.
    return DswHoverTap(
      onTap: onPick,
      builder: (context, hovered, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        color: hovered ? color.interactiveBgHover : null,
        child: Row(
          children: [
            Icon(
              isDir ? LucideIcons.folder : LucideIcons.file,
              size: DswShape.iconSm,
              color: color.labelSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // The plugin's duplicate rule: a colliding basename
                    // names its parent, so two `main.dart`s stay apart.
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xs13.copyWith(color: color.labelPrimary),
                  ),
                  if (directory.isNotEmpty)
                    Text(
                      directory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xxxs11.copyWith(
                        color: color.labelTertiary,
                        fontFamily: dswFontFamilyCode,
                        fontFamilyFallback: dswFontFamilyCodeFallback,
                      ),
                    ),
                ],
              ),
            ),
            // A directory hints at the continuation a pick buys.
            if (isDir)
              Icon(
                LucideIcons.chevron_right,
                size: DswShape.iconSm,
                color: color.labelTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

/// One command the `/`-menu offers.
class _CommandEntry {
  const _CommandEntry({
    required this.command,
    required this.label,
    required this.description,
    required this.icon,
    required this.action,
  });

  final String command;
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback action;
}

/// One row of the command menu: command, label, description.
class _CommandRow extends StatefulWidget {
  const _CommandRow({required this.entry, required this.onRun});

  final _CommandEntry entry;
  final VoidCallback onRun;

  @override
  State<_CommandRow> createState() => _CommandRowState();
}

class _CommandRowState extends State<_CommandRow> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: widget.onRun,
      builder: (context, hovered, _) => ColoredBox(
        color: hovered ? color.interactiveBgHover : Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Row(
            children: [
              Icon(
                widget.entry.icon,
                size: DswShape.iconSm,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                widget.entry.command,
                style: DswType.xxs12.copyWith(
                  color: color.labelPrimary,
                  fontFamily: dswFontFamilyCode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr(widget.entry.label),
                  overflow: TextOverflow.ellipsis,
                  style: DswType.xxs12.copyWith(color: color.labelSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One picked image: a rounded thumbnail with a remove glyph riding its corner.
class _ImageChip extends StatelessWidget {
  const _ImageChip({required this.image, required this.onRemove});

  final AttachedImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DswShape.control),
            border: Border.all(color: color.borderL2),
            image: DecorationImage(
              image: MemoryImage(image.bytes),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: DswHoverTap(
            onTap: onRemove,
            semanticLabel: context.tr('removeAttachment'),
            excludeSemantics: true,
            builder: (context, _, _) => Tooltip(
              message: context.tr('removeAttachment'),
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color.bgOverlay,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.x,
                  size: DswShape.iconTiny,
                  color: color.labelPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The paperclip. A popup rather than a direct pick: the clipboard paste is the
/// other half of the affordance, and the only way to offer both is a menu.
class _AttachButton extends StatelessWidget {
  const _AttachButton({
    required this.onPick,
    required this.onPickDocuments,
    required this.onPaste,
  });

  final Future<void> Function() onPick;
  final Future<void> Function() onPickDocuments;
  final Future<void> Function() onPaste;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswMenu(
      label: context.tr('attach'),
      minWidth: 220,
      items: (context) => [
        DswMenuEntry(
          icon: LucideIcons.image_up,
          label: context.tr('chooseImages'),
          onTap: onPick,
        ),
        DswMenuEntry(
          icon: LucideIcons.file_text,
          label: context.tr('chooseDocuments'),
          onTap: onPickDocuments,
        ),
        DswMenuEntry(
          icon: LucideIcons.clipboard,
          label: context.tr('pasteImage'),
          onTap: onPaste,
        ),
      ],
      trigger: (context) => SizedBox(
        width: 28,
        height: 24,
        child: Center(
          child: Icon(
            LucideIcons.paperclip,
            size: DswShape.iconSm,
            color: color.labelTertiary,
          ),
        ),
      ),
    );
  }
}

/// The model seat — dsh's `conversation.input.model`, in the `_ModeChip`'s
/// own 24px capsule shape. The trigger names the runtime's current model; the
/// menu offers the directory's list with the current one checked. Each item
/// shows the model id on the first line and a one-line description below it
/// (from the local catalog, or a provider-family fallback for unknown ids).
/// A "模型管理" row at the foot opens settings; a refresh row below that lets
/// the user re-probe the endpoint without leaving the menu.
class _ModelChip extends StatelessWidget {
  const _ModelChip({
    required this.directory,
    this.onSelect,
    this.onOpenSettings,
  });

  final ModelDirectory directory;
  final ValueChanged<String>? onSelect;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) => DswSelect<String>(
        value: directory.selectedModel,
        onChanged: (id) {
          if (id == null) return;
          directory.select(id);
          onSelect?.call(id);
        },
        enabled: onSelect != null,
        label: context.tr('model'),
        popupMinWidth: 320,
        maxHeight: 420,
        options: (context, close) => [
          for (final model in directory.models)
            ShadOption<String>(
              value: model.id,
              // Two lines, so the row is intrinsic rather than nailed at 56: a
              // seat that carries its own second line has to be allowed to grow
              // (ADR-0017 S3). The check that says "this one is live" is
              // shad's, trailing, as it was.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    model.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xs13.copyWith(
                      color: color.labelPrimary,
                      fontFamily: dswFontFamilyCode,
                      fontFamilyFallback: dswFontFamilyCodeFallback,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description ?? providerFamilyLabel(model.provider),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                  ),
                ],
              ),
            ),
          // The "模型管理" row: opens the full-screen settings view so the user
          // can edit credentials, base URL, and provider — the things the menu
          // itself cannot change. A free row, so it closes the popup first.
          DswMenuRow(
            entry: DswMenuEntry(
              icon: LucideIcons.settings,
              label: context.tr('modelManagement'),
              onTap: onOpenSettings == null
                  ? null
                  : () {
                      close();
                      onOpenSettings!();
                    },
            ),
          ),
          const DswMenuDivider(),
          // The refresh row: the fetched catalog on demand, with the load's own
          // one-line outcome under it when there is one to say.
          Container(
            constraints: BoxConstraints(minHeight: dswMenuSeat(context)),
            padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: directory.isLoading
                      ? SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color.labelTertiary,
                          ),
                        )
                      : Icon(
                          LucideIcons.refresh_cw,
                          size: DswShape.iconTiny,
                          color: color.labelTertiary,
                        ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    directory.loadError ?? context.tr('refreshModels'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxxs11.copyWith(
                      color: directory.loadError != null
                          ? color.stateErrorPrimary
                          : color.labelTertiary,
                    ),
                  ),
                ),
                if (!directory.isLoading)
                  DswHoverTap(
                    onTap: directory.refresh,
                    builder: (context, _, _) => Text(
                      context.tr('retry'),
                      style: DswType.xxxs11.copyWith(
                        color: color.stateBusinessPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        trigger: (context, value, hovered) => LayoutBuilder(
          builder: (context, constraints) {
            // The mode chip's rule, applied here too: a chip that cannot fit
            // its label sheds the label and the stroke before the row gives
            // up on the control entirely. The model is named by the menu's
            // own checkmark, so an icon-only seat still says what it opens.
            final tight = constraints.maxWidth < 64;
            return Container(
              // The same one-line seat as the mode chip below it: pinned at 24
              // this cut the model's own name as soon as the system amplified
              // text (25.0 wanted at 1.8, 31.0 at 2.2).
              height: 24 * MediaQuery.textScalerOf(context).scale(1),
              padding: EdgeInsets.symmetric(horizontal: tight ? 0 : 8),
              decoration: BoxDecoration(
                // shad's select trigger answers the pointer with nothing —
                // `ShadDecoration` cannot express hover — so the chip paints
                // the house wash itself from the state [DswSelect] reports.
                color: hovered ? color.interactiveBgHover : Colors.transparent,
                borderRadius: BorderRadius.circular(DswShape.inner),
                border: Border.all(
                  color: tight ? Colors.transparent : color.borderL2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.cpu,
                    size: DswShape.iconSm,
                    color: color.labelSecondary,
                  ),
                  if (!tight) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        directory.selectedModel,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: DswType.xxxs11.copyWith(
                          color: color.labelSecondary,
                          fontFamily: dswFontFamilyCode,
                          fontFamilyFallback: dswFontFamilyCodeFallback,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.chevron_down,
                      size: DswShape.iconTiny,
                      color: color.labelTertiary,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The PermissionSelect: a chip naming the current mode that opens the
/// three-way picker. Selecting is live — there is no confirm step, because the
/// chip itself is the undo.
class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode, required this.onSelect});

  final ApprovalMode mode;
  final ValueChanged<ApprovalMode>? onSelect;

  (IconData, String) _visual(BuildContext context) => switch (mode) {
    ApprovalMode.ask => (LucideIcons.shield_question_mark, 'askEveryTime'),
    ApprovalMode.plan => (LucideIcons.clipboard_list, 'planFirst'),
    ApprovalMode.auto => (LucideIcons.zap, 'autoRun'),
  };

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final (icon, label) = _visual(context);
    return DswSelect<ApprovalMode>(
      value: mode,
      onChanged: onSelect == null
          ? null
          : (picked) {
              if (picked != null) onSelect!(picked);
            },
      enabled: onSelect != null,
      label: context.tr('approvalMode'),
      popupMinWidth: 260,
      options: (context, close) => [
        for (final entry in const [
          (
            ApprovalMode.ask,
            LucideIcons.shield_question_mark,
            'askEveryTime',
            'askEveryTimeDesc',
          ),
          (
            ApprovalMode.plan,
            LucideIcons.clipboard_list,
            'planFirst',
            'planFirstDesc',
          ),
          (ApprovalMode.auto, LucideIcons.zap, 'autoRun', 'autoRunDesc'),
        ])
          ShadOption<ApprovalMode>(
            value: entry.$1,
            // Two lines again, so again no nailed 44: the row grows with the
            // text step instead of cutting the description.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  entry.$2,
                  size: DswShape.iconSm,
                  color: color.labelSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.tr(entry.$3)),
                      Text(
                        context.tr(entry.$4),
                        style: DswType.xxxs11.copyWith(
                          color: color.labelTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
      trigger: (context, value, hovered) => LayoutBuilder(
        builder: (context, constraints) {
          // Below this the chip sheds its label and chrome rather than
          // overflowing the card — a re-expanded sidebar over a narrow
          // window squeezes the centre column to almost nothing, and the
          // icon alone still names the mode to anyone who knows the menu.
          final tight = constraints.maxWidth < 64;
          return Container(
            // One line of chrome: the label is 11/14, and a seat nailed to 24
            // cut it once the system amplified text (25.0 needed). At the
            // designed step this is still exactly 24.
            height: 24 * MediaQuery.textScalerOf(context).scale(1),
            padding: EdgeInsets.symmetric(horizontal: tight ? 0 : 8),
            decoration: BoxDecoration(
              color: hovered ? color.interactiveBgHover : Colors.transparent,
              borderRadius: BorderRadius.circular(DswShape.inner),
              border: Border.all(
                color: tight ? Colors.transparent : color.borderL2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: DswShape.iconSm, color: color.labelSecondary),
                if (!tight) ...[
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      context.tr(label),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: DswType.xxxs11.copyWith(
                        color: color.labelSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevron_down,
                    size: DswShape.iconTiny,
                    color: color.labelTertiary,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.color,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final DswAlias color;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  @override
  Widget build(BuildContext context) => dswEnsureShadTheme(
    context,
    ShadButton.ghost(
      // One way to say "off": shad dims through `ShadDisabled` and reads the
      // theme's 40%, so the button no longer carries an `enabled` flag beside
      // an `onTap` that could disagree with it (ADR-0024's rule).
      onPressed: widget.enabled ? widget.onTap : null,
      width: 34,
      // min AND max: `ShadButton.height` writes both, which is what a circle
      // wants and what ADR-0017 S3 warns about for anything holding a label.
      // This one holds a glyph, which does not grow with the text step.
      height: 34,
      padding: EdgeInsets.zero,
      backgroundColor: widget.color.buttonInfoFill,
      hoverBackgroundColor: widget.color.buttonInfoHover,
      // The corner is said here because shad's one radius knob answers for the
      // control tier and a send circle is not that (ADR-0029); the frame is
      // turned off so the fill is the only thing on the surface, while the
      // focus ring stays — the app's primary action used to have no keyboard
      // answer at all.
      decoration: const ShadDecoration(
        shape: BoxShape.circle,
        border: ShadBorder.none,
        focusedBorder: ShadBorder.none,
        secondaryBorder: ShadBorder.none,
      ),
      // Opts out of the row's 2px downward shift: the send circle keeps its
      // original seat while smaller chips sit lower.
      child: Transform.translate(
        offset: const Offset(0, -2),
        child: widget.child,
      ),
    ),
  );
}

/// The bordered pill the two busy-time deliveries use: a glyph, a word, and the
/// tooltip that says what the word means in this row.
class _DeliverChip extends StatelessWidget {
  const _DeliverChip({
    required this.color,
    required this.icon,
    required this.label,
    required this.tip,
    required this.onTap,
    this.tight = false,
  });

  final DswAlias color;
  final IconData icon;
  final String label;
  final String tip;
  final VoidCallback onTap;

  /// The narrow-column tier: the words go, the stroke and the 28px height stay
  /// so the two seats still read as the buttons on this line.
  final bool tight;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: DswHoverTap(
      onTap: onTap,
      semanticLabel: tip,
      builder: (context, hovered, _) => Transform.translate(
        // The same seat as the primary circle, two pixels up from the chip row.
        offset: const Offset(0, -2),
        child: Container(
          // 28 is the seat's floor, not its height: this row owns its one line,
          // and nailing it cut the word as soon as the system amplified text
          // (32.0 wanted at 1.8). At the designed step it stays exactly 28.
          constraints: const BoxConstraints(minHeight: 28),
          padding: EdgeInsets.symmetric(horizontal: tight ? 6 : 8),
          decoration: BoxDecoration(
            color: hovered ? color.interactiveBgHover : null,
            border: Border.all(color: color.borderL2),
            borderRadius: BorderRadius.circular(DswShape.control),
          ),
          child: Row(
            children: [
              Icon(icon, size: DswShape.iconSm, color: color.labelSecondary),
              if (!tight) ...[
                const SizedBox(width: 5),
                Text(
                  label,
                  style: DswType.xxs12.copyWith(color: color.labelPrimary),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// A document attached for text extraction. [text] starts null (extraction in
/// flight) and is filled once the extractor resolves.
class _AttachedDocument {
  _AttachedDocument({required this.name, required this.text});
  final String name;
  String? text;
}

/// A compact chip showing the document name and a remove button. While
/// extraction is in flight a small spinner replaces the file icon.
class _DocumentChip extends StatelessWidget {
  const _DocumentChip({required this.doc, required this.onRemove});

  final _AttachedDocument doc;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final loading = doc.text == null;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.bgLayer2,
        border: Border.all(color: color.borderL2),
        borderRadius: BorderRadius.circular(DswShape.control),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (loading)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: color.labelCaption,
              ),
            )
          else
            Icon(
              LucideIcons.file_text,
              size: DswShape.iconSm,
              color: color.labelSecondary,
            ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              doc.name,
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          DswHoverTap(
            onTap: onRemove,
            semanticLabel: context.tr('removeAttachment'),
            excludeSemantics: true,
            builder: (context, hovered, focused) => Icon(
              LucideIcons.x,
              size: DswShape.iconTiny,
              color: hovered || focused
                  ? color.labelPrimary
                  : color.labelTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
