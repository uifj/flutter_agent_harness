// The update-available dialog (ADR-0079 ④).
//
// Three actions, never more: download (the release's own page, opened in the
// browser — the menu's old destination lives on HERE, not as a second menu
// row), skip this version (records the version; the automatic check goes
// quiet about it until the next one), and the barrier (same as skip-less
// close — the automatic check will ask again tomorrow). The manual check
// from the app menu ignores the skip, so skipping never hides an update the
// user explicitly asked about.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, showShadDialog;
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/locales.dart';
import '../../model/update_check.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_typography.dart';

/// Shows the available update. [onSkip] records the version the user
/// declined; the caller owns the persistence, the dialog owns the wording.
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateCheckResult result, {
  required Future<void> Function(String version) onSkip,
}) async {
  final remote = result.remote;
  if (remote == null) return;
  await showShadDialog<void>(
    context: context,
    builder: (dialogContext) => ShadDialog.alert(
      radius: BorderRadius.circular(DswShape.float),
      title: Row(
        children: [
          const Icon(LucideIcons.refresh_cw, size: 18),
          const SizedBox(width: 8),
          Text(
            dialogContext.tr('updateAvailableTitle', {
              'version': remote.version,
            }),
            style: DswType.sStrong14,
          ),
        ],
      ),
      description: Text(
        dialogContext.tr('updateBody', {
          'current': result.current,
          'new': remote.version,
        }),
        style: DswType.xs13,
      ),
      actions: [
        ShadButton.outline(
          onPressed: () async {
            Navigator.pop(dialogContext);
            await onSkip(remote.version);
          },
          child: Text(dialogContext.tr('updateSkip')),
        ),
        ShadButton.destructive(
          onPressed: () async {
            Navigator.pop(dialogContext);
            final url = Uri.parse(remote.url);
            if (await canLaunchUrl(url)) {
              await launchUrl(url, mode: LaunchMode.externalApplication);
            }
          },
          child: Text(dialogContext.tr('updateDownload')),
        ),
      ],
    ),
  );
}
