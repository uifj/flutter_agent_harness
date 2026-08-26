// The copy control every code-ish surface carries.
//
// dsh spells this twice over: `use-copy-feedback.ts` owns the 1000ms
// confirmation window, and each block writes its own `<button
// className={css.copyButton}>` in the same borderless 13px label. Here the hook
// and that button are one widget, because a Flutter widget can hold the timer
// the hook exists to hold.
//
// Labels are `t('copy')` / `t('copied')` — the primitives package is
// cordis-free, so its own defaults are the Chinese pair, and every real call
// site passes the dictionary's values. `locale/src/locales/en.ts` has them as
// `Copy` and `Copied`, which is what this build uses throughout.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/dsw_typography.dart';

/// How long the control stays confirmed, from `use-copy-feedback.ts`'s
/// `setTimeout(..., 1000)`.
const copiedLinger = Duration(milliseconds: 1000);

class CopyButton extends StatefulWidget {
  const CopyButton({
    super.key,
    required this.text,
    required this.idleColor,
    required this.hoverColor,
    this.label = 'Copy',
    this.copiedLabel = 'Copied',
  });

  /// What lands on the clipboard. Every caller passes the surface's own content
  /// without its chrome — no gutter numbers, no banner, no status pill.
  final String text;

  /// Resolved by the caller, because the surfaces disagree: a banner control
  /// sits on `label-primary` while a block's floating one sits on
  /// `label-secondary`. The hover step is this port's own affordance, in the
  /// direction dsh dims its `.expand` control — one step brighter.
  final Color idleColor;
  final Color hoverColor;

  final String label;
  final String copiedLabel;

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;
  bool _hovered = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _copy() {
    // The source's `if (copied) return`: a second tap inside the window is not a
    // second copy, so the confirmation cannot be re-armed into a stutter.
    if (_copied) return;
    Clipboard.setData(ClipboardData(text: widget.text));
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(copiedLinger, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    onEnter: (_) => setState(() => _hovered = true),
    onExit: (_) => setState(() => _hovered = false),
    child: GestureDetector(
      onTap: _copy,
      behavior: HitTestBehavior.opaque,
      child: Text(
        _copied ? widget.copiedLabel : widget.label,
        style: DswType.xs13.copyWith(
          color: _hovered ? widget.hoverColor : widget.idleColor,
        ),
      ),
    ),
  );
}
