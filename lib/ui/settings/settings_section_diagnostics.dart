// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

// Diagnostics — see the enum `_Section` for what points at it.
extension _DiagnosticsSection on _SettingsPanelState {
  /// Diagnostics (ADR-0058): the two local log toggles and a way to reach
  /// the files. Held as drafts and committed on Save like every other
  /// preference on this panel; the runtime reads them live per model call,
  /// so a save needs no restart.
  List<Widget> _diagnosticsSection(DswAlias color) => [
    _heading(
      color,
      AppLocalizations.of(context).settingsDiagnostics,
      AppLocalizations.of(context).settingsDiagnosticsIntro,
    ),
    const SizedBox(height: 12),
    SettingsCard(
      dividers: true,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: _SwitchRow(
            label: AppLocalizations.of(context).diagnosticRequestLog,
            description: AppLocalizations.of(context).diagnosticRequestLogDesc,
            value: _diagnosticRequestLog,
            onChanged: (value) => rebuild(() => _diagnosticRequestLog = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: _SwitchRow(
            label: AppLocalizations.of(context).diagnosticContextLog,
            description: AppLocalizations.of(context).diagnosticContextLogDesc,
            value: _diagnosticContextLog,
            onChanged: (value) => rebuild(() => _diagnosticContextLog = value),
          ),
        ),
        if (widget.onOpenDiagnosticsFolder != null)
          _ActionRow(
            title: AppLocalizations.of(context).diagnosticFolderTitle,
            description: AppLocalizations.of(context).diagnosticFolderDesc,
            button: CapsuleButton(
              label: AppLocalizations.of(context).revealInFiles,
              onTap: widget.onOpenDiagnosticsFolder!,
            ),
            last: true,
          ),
        _ActionRow(
          title: AppLocalizations.of(context).settingsFeedback,
          description: AppLocalizations.of(context).settingsFeedbackDesc,
          button: CapsuleButton(
            label: AppLocalizations.of(context).settingsFeedbackOpen,
            onTap: _openFeedbackForm,
          ),
          last: true,
        ),
      ],
    ),
  ];

  /// Send feedback (ADR-0084 D4 Tier A) — lib's first real consumption of
  /// `package:app_common`. PlanStar is single-machine with no feedback backend
  /// (that is ADR-0045 form ②), so the form is de-account-ised (`isPersonal`,
  /// which hides the legacy company-ID field) and submit composes a pre-filled
  /// GitHub issue draft — the same channel the help menu's "report an issue"
  /// uses — instead of pretending to POST to a server. The browser opens an
  /// editable draft, so the user reviews it (and can strip the optional
  /// contact) before submitting.
  Future<void> _openFeedbackForm() async {
    await showShadDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        child: FeedbackFormPanel(
          isPersonal: true,
          onCancel: () => Navigator.of(dialogContext).pop(),
          onSubmit: (data) {
            Navigator.of(dialogContext).pop();
            _sendFeedback(data);
          },
        ),
      ),
    );
  }

  /// Composes the submitted form into a GitHub new-issue draft and opens it in
  /// the external browser. The optional contact and the version/platform block
  /// land in the body only when the user supplied / opted into them; nothing is
  /// sent anywhere the user cannot see and edit first.
  Future<void> _sendFeedback(FeedbackFormData data) async {
    final l10n = AppLocalizations.of(context);
    // The type names live in app_common's own bundle now (ADR-0084 D4): the
    // feedback panel renders them, so lib reads the same source for the issue
    // title instead of keeping a second copy.
    final ac = AppCommonLocalizations.of(context);
    final type = data.fbType == 1
        ? ac.feedbackTypeIssue
        : ac.feedbackTypeAdvice;
    final body = StringBuffer(data.description.trim());
    final contact = data.contact.trim();
    if (contact.isNotEmpty) body.write('\n\nContact: $contact');
    if (data.uploadLog) {
      body.write(
        '\n\n---\n${AppMeta.productName} ${AppMeta.version} '
        '(${defaultTargetPlatform.name})',
      );
    }
    final uri = Uri.parse('${AppMeta.issuesUrl}/new').replace(
      queryParameters: {'title': '[Feedback] $type', 'body': body.toString()},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    showFeedback(
      context,
      opened ? l10n.feedbackIssueOpened : l10n.planLinkFailed,
      destructive: !opened,
    );
  }
}
