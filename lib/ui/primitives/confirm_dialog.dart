// A destructive confirm dialog, shared by the two places that ask before
// throwing work away: the editor's reload-with-unsaved-edits prompt and the git
// tab's destructive actions (discard / reset).
//
// ADR-0002 Stage 5b: this replaces the two hand-rolled Material
// `showDialog`+`AlertDialog`+`TextButton` pairs with the shad dialog the audit's
// mapping table calls for (`showDialog/AlertDialog → ShadDialog`). The shell is
// `ShadDialog.alert`; the actions are `ShadButton.outline` (cancel) and
// `ShadButton.destructive` (confirm) — the destructive variant's fill is
// `stateErrorPrimary` through the theme bridge, so the "this throws work away"
// signal is a colour, exactly as the old red confirm text carried it.
//
// `showShadDialog` reads the theme off the *caller's* context, so the caller must
// sit under a `ShadTheme` ancestor — the app provides it via `main`'s
// `MaterialApp.builder` (which wraps pushed routes too); a bare-`MaterialApp`
// widget test has to mount it the same way.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../l10n/locales.dart';
import '../../theme/dsw_typography.dart';

/// Shows a Cancel / [confirmLabel] confirm and resolves true only when the
/// destructive button is tapped. Dismissing the barrier or pressing Cancel
/// resolves false — the same "innocent unless confirmed" default the two call
/// sites relied on.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String description,
  required String confirmLabel,
}) async {
  final result = await showShadDialog<bool>(
    context: context,
    builder: (context) => ShadDialog.alert(
      title: Text(title, style: DswType.sStrong14),
      description: Text(description, style: DswType.xs13),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('cancel')),
        ),
        ShadButton.destructive(
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
