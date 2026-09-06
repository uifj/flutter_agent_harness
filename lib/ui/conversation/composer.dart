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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../l10n/locales.dart';
import '../../model/approval_mode.dart';
import '../../model/attached_image.dart';
import '../../model/file_search_rank.dart';
import '../../model/workspace_index.dart';
import '../../state/model_directory.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'conversation_root.dart';

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
  });

  /// The centred empty-state variant: no bottom pad, and a two-line floor.
  final bool hero;

  /// A turn is running, so the primary action stops it instead of sending.
  final bool busy;

  /// Sending would be refused — a turn is running, or an approval is pending.
  final bool blocked;

  /// How gated tool calls will decide; the chip both reads and writes it.
  final ApprovalMode approvalMode;

  /// Sends [text] with any [images] the row is holding.
  final void Function(String text, List<AttachedImage> images) onSubmit;

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

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKeyEvent);

  /// The images riding the next send, in pick order.
  final _images = <AttachedImage>[];

  /// The `/`-token the menu was dismissed for, or null when it is open. Escape
  /// dismisses it for the current token only; a different token reopens it.
  String? _dismissedToken;

  // -------------------------------------------------------------------------
  // The @ mention menu (dsh-at-file)
  // -------------------------------------------------------------------------

  /// The workspace index the mention menu ranks against, refreshed when the
  /// token opens and dropped when the menu closes — the plugin's per-session
  /// cache, in miniature. Null while no fetch has landed.
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
    lookup().then((entries) {
      if (!mounted || generation != _indexGeneration) return;
      setState(() {
        _fileIndex = entries;
        _indexLoading = false;
      });
    }).catchError((_) {
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
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool _wasEmpty = true;

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

  /// Enter submits, Shift+Enter breaks the line.
  ///
  /// Returning `handled` is what suppresses the newline: a key event the focus
  /// chain claims is never forwarded to the text input connection.
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
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _submit();
    return KeyEventResult.handled;
  }

  void _submit() {
    if (widget.blocked) return;
    final text = _controller.text.trim();
    if (text.isEmpty && _images.isEmpty) return;
    _controller.clear();
    final images = List<AttachedImage>.of(_images);
    _images.clear();
    setState(() => _wasEmpty = true);
    widget.onSubmit(text, images);
  }

  void _onPrimary() {
    if (widget.busy) {
      widget.onStop();
      return;
    }
    _submit();
  }

  // ---------------------------------------------------------------------------
  // Image attachment
  // ---------------------------------------------------------------------------

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
      if (picked.isEmpty) return;
      setState(() => _images.addAll(picked));
    } on PlatformException {
      // The picker is unavailable (a test harness, a headless run): the menu
      // item simply does nothing rather than killing the card.
    }
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
    setState(() {
      _images.add(
        AttachedImage(
          name: 'pasted-${_images.length + 1}.png',
          bytes: bytes,
          mediaType: 'image/png',
        ),
      );
    });
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
          constraints: const BoxConstraints(maxWidth: composerCardMaxWidth),
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
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.inputMajor,
                  // One notch weaker than a button's stroke, per the darkmode
                  // note in the source: exactly the l2-darkmode-thin pair.
                  border: Border.all(color: color.borderL2DarkmodeThin),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: DswShadow.lv2,
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
                    const SizedBox(height: 12),
                    _row(color),
                  ],
                ),
              ),
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
        borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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
                    _MentionRow(entry: entry, onPick: () => _insertMention(entry)),
                ],
              ),
            ),
        ],
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
    child: TextField(
      controller: _controller,
      focusNode: _focus,
      autofocus: true,
      maxLines: null,
      // The card is the scroll surface; a field that scrolled itself would put
      // its own gutter inside the capsule.
      keyboardType: TextInputType.multiline,
      cursorColor: color.stateBusinessPrimary,
      style: DswType.base16.copyWith(color: color.labelPrimary),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        // figma .InputText 34:10434: pl 16 / pr 12 / pt 4.
        contentPadding: const EdgeInsets.only(left: 16, right: 12, top: 4),
        hintText: context.tr('askAnythingHint'),
        hintStyle: DswType.base16.copyWith(color: color.labelCaption),
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

  Widget _row(DswAlias color) => Padding(
    // 2px of the bottom pad moved to the top: the whole control row sits 2px
    // lower in the card without changing its height.
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // A re-expanded sidebar over a narrow window squeezes the centre
        // column to nearly the attach and send buttons' own width; past that
        // point the chip gives up its seat rather than overflowing the card.
        // The mode lives on in the transcript's mode chips, so nothing is
        // lost that the conversation was not already saying.
        final showChip = constraints.maxWidth >= 140;
        // dsh's `.row`: space-between — the tools (attach, mode) on the left,
        // the trailing group (model seat, send) on the right. The model seat
        // rides `conversation.input.model` beside the primary action, NOT in
        // the tools: it is a property of the next send, like the button, not
        // a modifier of the draft, like the attachments.
        return Row(
          children: [
            _AttachButton(onPick: _pickImages, onPaste: _pasteClipboardImage),
            const SizedBox(width: 4),
            if (showChip) ...[
              // Flexible rather than fixed: the chip's label ellipsizes
              // before the row ever gets this tight.
              Flexible(
                child: _ModeChip(
                  mode: widget.approvalMode,
                  onSelect:
                      widget.onApprovalMode == null
                          ? null
                          : (mode) => widget.onApprovalMode!(mode),
                ),
              ),
            ],
            const Spacer(),
            if (widget.modelDirectory != null && constraints.maxWidth >= 220)
              Flexible(
                child: _ModelChip(
                  directory: widget.modelDirectory!,
                  onSelect: widget.onModelSelected,
                ),
              ),
            if (widget.modelDirectory != null && constraints.maxWidth >= 220)
              const SizedBox(width: 12),
            _primary(color),
          ],
        );
      },
    ),
  );

  /// The 34px send / stop circle. Both states share the button, so the toggle is
  /// a glyph swap rather than a layout change.
  Widget _primary(DswAlias color) {
    final enabled = widget.busy || (!widget.blocked && !_wasEmpty);
    return Tooltip(
      message: widget.busy ? context.tr('stop') : context.tr('send'),
      waitDuration: const Duration(milliseconds: 500),
      child: _PrimaryButton(
        color: color,
        enabled: enabled,
        onTap: enabled ? _onPrimary : null,
        child: Icon(
          widget.busy ? LucideIcons.square : LucideIcons.arrow_up,
          size: 16,
          // Static white in both themes: the glyph sits on the blue fill.
          color: Colors.white,
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
class _MentionRow extends StatefulWidget {
  const _MentionRow({required this.entry, required this.onPick});

  final FileEntry entry;
  final VoidCallback onPick;

  @override
  State<_MentionRow> createState() => _MentionRowState();
}

class _MentionRowState extends State<_MentionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final entry = widget.entry;
    final name = basenameOf(entry.relative);
    final directory = dirnameOf(entry.relative);
    final isDir = entry.kind == 'dir';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPick,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: _hovered ? color.interactiveBgHover : null,
          child: Row(
            children: [
              Icon(
                isDir ? LucideIcons.folder : LucideIcons.file,
                size: 13,
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
                  size: 13,
                  color: color.labelTertiary,
                ),
            ],
          ),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onRun,
        behavior: HitTestBehavior.opaque,
        child: ColoredBox(
          color: _hovered ? color.interactiveBgHover : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                Icon(widget.entry.icon, size: 13, color: color.labelSecondary),
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
            borderRadius: BorderRadius.circular(8),
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
          child: GestureDetector(
            onTap: onRemove,
            behavior: HitTestBehavior.opaque,
            child: Tooltip(
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
                  size: 11,
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
  const _AttachButton({required this.onPick, required this.onPaste});

  final Future<void> Function() onPick;
  final Future<void> Function() onPaste;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return PopupMenuTheme(
      data: PopupMenuThemeData(
        color: color.bgLayer2,
        textStyle: DswType.xs13.copyWith(color: color.labelPrimary),
      ),
      child: PopupMenuButton<String>(
        tooltip: context.tr('attachImage'),
        position: PopupMenuPosition.over,
        constraints: const BoxConstraints(minWidth: 220),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'files',
            height: 36,
            child: Row(
              children: [
                Icon(
                  LucideIcons.image_up,
                  size: 14,
                  color: color.labelSecondary,
                ),
                const SizedBox(width: 8),
                Text(context.tr('chooseImages')),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'paste',
            height: 36,
            child: Row(
              children: [
                Icon(
                  LucideIcons.clipboard,
                  size: 14,
                  color: color.labelSecondary,
                ),
                const SizedBox(width: 8),
                Text(context.tr('pasteImage')),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'files') onPick();
          if (value == 'paste') onPaste();
        },
        child: Container(
          width: 28,
          height: 24,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: Center(
            child: Icon(
              LucideIcons.paperclip,
              size: 14,
              color: color.labelTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The model seat — dsh's `conversation.input.model`, in the `_ModeChip`'s
/// own 24px capsule shape. The trigger names the runtime's current model; the
/// menu offers the directory's list with the current one checked. A refresh
/// row rides at the menu's foot so the fetched catalog is one click away
/// without the seat depending on a host-side catalog load.
class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.directory, this.onSelect});

  final ModelDirectory directory;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ListenableBuilder(
      listenable: directory,
      builder: (context, _) => PopupMenuTheme(
        data: PopupMenuThemeData(
          color: color.bgLayer2,
          textStyle: DswType.xs13.copyWith(color: color.labelPrimary),
        ),
        child: PopupMenuButton<String>(
          tooltip: context.tr('model'),
          position: PopupMenuPosition.over,
          constraints: const BoxConstraints(minWidth: 260, maxHeight: 360),
          enabled: onSelect != null,
          initialValue: directory.selectedModel,
          itemBuilder: (context) => [
            for (final model in directory.models)
              PopupMenuItem(
                value: model.id,
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.xs13.copyWith(
                          color: color.labelPrimary,
                          fontFamily: dswFontFamilyCode,
                          fontFamilyFallback: dswFontFamilyCodeFallback,
                        ),
                      ),
                    ),
                    if (model.id == directory.selectedModel)
                      Icon(
                        LucideIcons.check,
                        size: 14,
                        color: color.stateBusinessPrimary,
                      ),
                  ],
                ),
              ),
            // The refresh row: the fetched catalog on demand, with the load's
            // own one-line outcome under it when there is one to say.
            PopupMenuItem(
              enabled: false,
              height: 36,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(height: 1, color: color.borderL2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
                                  size: 12,
                                  color: color.labelTertiary,
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            directory.loadError ??
                                context.tr('refreshModels'),
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
                          GestureDetector(
                            onTap: directory.refresh,
                            child: Text(
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
              ),
            ),
          ],
          onSelected: (id) {
            directory.select(id);
            onSelect?.call(id);
          },
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.borderL2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cpu, size: 13, color: color.labelSecondary),
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
                  size: 11,
                  color: color.labelTertiary,
                ),
              ],
            ),
          ),
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
    return PopupMenuTheme(
      data: PopupMenuThemeData(
        color: color.bgLayer2,
        textStyle: DswType.xs13.copyWith(color: color.labelPrimary),
      ),
      child: PopupMenuButton<ApprovalMode>(
        tooltip: context.tr('approvalMode'),
        position: PopupMenuPosition.over,
        constraints: const BoxConstraints(minWidth: 260),
        initialValue: mode,
        enabled: onSelect != null,
        itemBuilder: (context) => [
          for (final entry in const [
            (ApprovalMode.ask, LucideIcons.shield_question_mark, 'askEveryTime', 'askEveryTimeDesc'),
            (ApprovalMode.plan, LucideIcons.clipboard_list, 'planFirst', 'planFirstDesc'),
            (ApprovalMode.auto, LucideIcons.zap, 'autoRun', 'autoRunDesc'),
          ])
            PopupMenuItem(
              value: entry.$1,
              height: 44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(entry.$2, size: 14, color: color.labelSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (entry.$1 == mode)
                    Icon(
                      LucideIcons.check,
                      size: 14,
                      color: color.stateBusinessPrimary,
                    ),
                ],
              ),
            ),
        ],
        onSelected: onSelect,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Below this the chip sheds its label and chrome rather than
            // overflowing the card — a re-expanded sidebar over a narrow
            // window squeezes the centre column to almost nothing, and the
            // icon alone still names the mode to anyone who knows the menu.
            final tight = constraints.maxWidth < 64;
            return Container(
              height: 24,
              padding: EdgeInsets.symmetric(horizontal: tight ? 0 : 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tight ? Colors.transparent : color.borderL2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: color.labelSecondary),
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
                      size: 11,
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: widget.enabled
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: widget.enabled ? 1 : 0.4,
        // Opts out of the row's 2px downward shift: the send circle keeps its
        // original seat while smaller chips sit lower.
        child: Transform.translate(
          offset: const Offset(0, -2),
          child: AnimatedContainer(
            duration: DswMotion.respecting(context, DswMotion.fast),
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered && widget.enabled
                  ? widget.color.buttonInfoHover
                  : widget.color.buttonInfoFill,
              shape: BoxShape.circle,
            ),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}
