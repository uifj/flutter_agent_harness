// One voice for "show me this in the file browser" (ADR-0041).
//
// The action is two lines — ask the host, and if it refused, say so — and the
// sidecar history grew a second copy of them the week the first landed. Five
// surfaces want it (a workspace group, a conversation row, a tree row, a git
// change row, and whatever asks next), so the refusal copy lives here rather
// than being retyped per menu: two spellings of "could not open that folder" on
// two screens is the same defect ADR-0020 closed for the strip itself.
//
// This file does not touch `dart:io`. The host owns the process (`host/reveal.dart`),
// because architecture rule 5 keeps `lib/ui` away from the filesystem.

import 'package:flutter/widgets.dart';

import '../../host/reveal.dart';
import '../../l10n/app_localizations.dart';
import 'feedback.dart';

/// Reveals [path] — a file or a folder — in the operating system's file
/// browser, and reports a refusal through the app's one feedback strip.
Future<void> revealInFilesOrReport(BuildContext context, String path) async {
  if (await revealInFileManager(path)) return;
  if (!context.mounted) return;
  showFeedback(
    context,
    AppLocalizations.of(context).revealFailed,
    destructive: true,
  );
}
