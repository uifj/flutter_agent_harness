// The app's one feedback strip (ADR-0020).
//
// Nine call sites used to raise a Material `SnackBar`: a bar with the
// framework's own radius, typography and animation, shown by a
// `ScaffoldMessenger` that nothing else in this app uses — so the one message a
// user is most likely to see (a save that failed, a backup that finished) was
// the one surface outside the token system. shad's Sonner is already in the
// dependency (ADR-0002) and is coloured entirely by `DswAlias` through
// `theme/dsw_shad_bridge.dart`, so the strip now takes the same palette, the
// same shape tiers and the same text scaler as the card it reports on.
//
// `ShadSonner` has to be mounted above the Navigator; `main.dart` does it in
// `MaterialApp.builder`, the same seam that composes the user's font step, so
// a toast raised from a dialog or from the settings page still has a home.

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../theme/dsw_typography.dart';

/// Shows [message] in the app's feedback strip.
///
/// [destructive] picks the library's error variant — the one place the
/// difference between "saved" and "could not save" is said out loud, so a
/// caller that reports a failure must not leave it at the default.
///
/// No scope means no strip, the same way the optional messenger lookup behaved:
/// the previews and the widget harnesses that never mount a `ShadSonner` lose
/// the toast and nothing else. A test that wants the message painted has to
/// mount the strip, which is what makes "the user was told" testable at all.
void showFeedback(
  BuildContext context,
  String message, {
  bool destructive = false,
}) {
  final sonner = ShadSonner.maybeOf(context);
  if (sonner == null) return;
  sonner.show(
    destructive
        ? ShadToast.destructive(title: Text(message, style: DswType.s14))
        : ShadToast(title: Text(message, style: DswType.s14)),
  );
}
