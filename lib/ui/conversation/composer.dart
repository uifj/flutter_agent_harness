// The input card.
//
// A port of `InputBar.module.css`: a floating capsule with the draft on top and
// a control row below, capped at the content width plus 32px — the one element in
// the column allowed to be wider than the transcript.
//
// The dsh original carries a toolbar of attach / mode / permission chips on the
// left of the control row. None of them exist in this build, so the row holds the
// primary action alone; the geometry is unchanged so they have a seat to arrive
// into.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';

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
    required this.onSubmit,
    required this.onStop,
  });

  /// The centred empty-state variant: no bottom pad, and a two-line floor.
  final bool hero;

  /// A turn is running, so the primary action stops it instead of sending.
  final bool busy;

  /// Sending would be refused — a turn is running, or an approval is pending.
  final bool blocked;

  final void Function(String text) onSubmit;
  final VoidCallback onStop;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKeyEvent);

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
    final empty = _controller.text.trim().isEmpty;
    if (empty == _wasEmpty) return;
    setState(() => _wasEmpty = empty);
  }

  /// Enter submits, Shift+Enter breaks the line.
  ///
  /// Returning `handled` is what suppresses the newline: a key event the focus
  /// chain claims is never forwarded to the text input connection.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _submit();
    return KeyEventResult.handled;
  }

  void _submit() {
    if (widget.blocked) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSubmit(text);
  }

  void _onPrimary() {
    if (widget.busy) {
      widget.onStop();
      return;
    }
    _submit();
  }

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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color.inputMajor,
              // One notch weaker than a button's stroke, per the darkmode note
              // in the source: exactly the l2-darkmode-thin pair.
              border: Border.all(color: color.borderL2DarkmodeThin),
              borderRadius: BorderRadius.circular(22),
              boxShadow: DswShadow.lv2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                _draft(color),
                const SizedBox(height: 12),
                _row(color),
              ],
            ),
          ),
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
        hintText: 'Ask anything, or describe a task',
        hintStyle: DswType.base16.copyWith(color: color.labelCaption),
      ),
    ),
  );

  Widget _row(DswAlias color) => Padding(
    // 2px of the bottom pad moved to the top: the whole control row sits 2px
    // lower in the card without changing its height.
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
    child: Row(
      children: [
        const Spacer(),
        _primary(color),
      ],
    ),
  );

  /// The 34px send / stop circle. Both states share the button, so the toggle is
  /// a glyph swap rather than a layout change.
  Widget _primary(DswAlias color) {
    final enabled = widget.busy || (!widget.blocked && !_wasEmpty);
    return Tooltip(
      message: widget.busy ? 'Stop' : 'Send',
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
