// The welcome / login screen (ADR-0045 PE), shaped after ZCode's
// WelcomeScreen (`WelcomeScreen.tsx:35-545`): a full-screen gate with the
// product mark, one button per auth provider (region-tagged), a waiting
// state while the browser flow polls, an error state with retry, and the
// API-key form with the only skip path. The self-built backend's web
// registration page opens from the provider card's register link — the
// client has no in-app registration form, exactly like the reference.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

import '../../l10n/app_localizations.dart';
import '../../model/zcode_compat/zcode_compat.dart';
import '../../state/auth_session.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_shad_bridge.dart' show dswEnsureShadTheme, dswInputHint;
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';
import '../primitives/tappable.dart';

/// Which surface of the gate is showing — providers (default), the waiting
/// state, the API-key form, or the register hand-off note.
enum _WelcomeFace { providers, waiting, apiKey }

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.reason,
    required this.origin,
    required this.auth,
    required this.onComplete,
    this.onOpenRegister,
    this.onApiKeyEnter,
  });

  final WelcomeReason reason;

  /// The self-built backend origin; empty disables the browser flow (the
  /// API-key and register-link paths degrade accordingly).
  final String origin;

  /// The session driving the browser flow; null disables provider buttons.
  final AuthSession? auth;

  /// Done for good this launch: `oauth` (signed in), `apiKey` (entered), or
  /// `skip` (deferred). Mirrors ZCode's `LoginCompleteReason`.
  final void Function(String reason) onComplete;

  /// Opens the backend's web registration page; null hides the link.
  final void Function(String url)? onOpenRegister;

  /// The API-key form's answer — the gate writes it through the settings
  /// store and completes with `apiKey`.
  final void Function(String key)? onApiKeyEnter;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  _WelcomeFace _face = _WelcomeFace.providers;
  String? _error;
  final bool _apiKeyObscured = true;
  final _apiKeyController = TextEditingController();

  bool get _flowEnabled =>
      widget.auth != null && (widget.origin).trim().isNotEmpty;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _startFlow(String provider) async {
    if (widget.auth == null) return;
    setState(() {
      _face = _WelcomeFace.waiting;
      _error = null;
    });
    final ok = await widget.auth!.startBrowserFlow(provider);
    if (!mounted) return;
    if (ok) {
      widget.onComplete('oauth');
      return;
    }
    setState(() {
      _face = _WelcomeFace.providers;
      _error = AppLocalizations.of(context).welcomeFlowFailed;
    });
  }

  void _submitApiKey() {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) return;
    widget.onApiKeyEnter?.call(key);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Scaffold(
      backgroundColor: color.bgBase,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _mark(color),
              const SizedBox(height: DswShape.lg),
              Text(
                AppLocalizations.of(context).welcomeTitle,
                textAlign: TextAlign.center,
                style: DswType.heroTitle26.copyWith(color: color.labelPrimary),
              ),
              const SizedBox(height: DswShape.xs),
              Text(
                _face == _WelcomeFace.apiKey
                    ? AppLocalizations.of(context).welcomeApiKeyIntro
                    : AppLocalizations.of(context).welcomeIntro,
                textAlign: TextAlign.center,
                style: DswType.s14.copyWith(color: color.labelSecondary),
              ),
              const SizedBox(height: DswShape.lg),
              switch (_face) {
                _WelcomeFace.providers => _providersCard(color),
                _WelcomeFace.waiting => _waitingCard(color),
                _WelcomeFace.apiKey => _apiKeyCard(color),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark(DswAlias color) => Center(
    child: Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color.brandPrimary,
        borderRadius: BorderRadius.circular(DswShape.control),
      ),
      child: Icon(
        LucideIcons.bot,
        size: DswShape.iconLg + 4,
        color: color.labelPrimaryForeground,
      ),
    ),
  );

  Widget _providersCard(DswAlias color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_flowEnabled) ...[
          _providerButton(
            color,
            provider: ZcodeOAuth.providerZai,
            label: AppLocalizations.of(context).welcomeProviderZai,
            region: AppLocalizations.of(context).welcomeRegionGlobal,
          ),
          const SizedBox(height: DswShape.sm),
          _providerButton(
            color,
            provider: ZcodeOAuth.providerBigmodel,
            label: AppLocalizations.of(context).welcomeProviderBigmodel,
            region: AppLocalizations.of(context).welcomeRegionCn,
          ),
        ] else
          _note(color, AppLocalizations.of(context).welcomeFlowUnavailable),
        if (_error != null) ...[
          const SizedBox(height: DswShape.sm),
          _note(color, _error!, warning: true),
        ],
        const SizedBox(height: DswShape.md),
        CapsuleButton(
          label: AppLocalizations.of(context).welcomeUseApiKey,
          onTap: () => setState(() => _face = _WelcomeFace.apiKey),
        ),
        const SizedBox(height: DswShape.sm),
        if (widget.onOpenRegister != null && widget.origin.trim().isNotEmpty)
          _textLink(
            color,
            AppLocalizations.of(context).welcomeRegister,
            () => widget.onOpenRegister!(
              ZcodeAuthEndpoints.registerUrl(widget.origin),
            ),
          ),
        if (widget.reason == WelcomeReason.manualLogin)
          _textLink(
            color,
            AppLocalizations.of(context).welcomeLater,
            () => widget.onComplete('skip'),
          ),
      ],
    );
  }

  Widget _providerButton(
    DswAlias color, {
    required String provider,
    required String label,
    required String region,
  }) => DswHoverTap(
    onTap: () => _startFlow(provider),
    semanticLabel: label,
    builder: (context, hovered, focused) => Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DswShape.md,
        vertical: DswShape.sm + 2,
      ),
      decoration: BoxDecoration(
        color: hovered ? color.interactiveBgHover : color.bgLayer1,
        borderRadius: BorderRadius.circular(DswShape.controlMd),
        border: Border.all(color: color.borderL2),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.globe,
            size: DswShape.iconSm,
            color: color.labelSecondary,
          ),
          const SizedBox(width: DswShape.sm),
          Expanded(
            child: Text(
              label,
              style: DswType.sStrong14.copyWith(color: color.labelPrimary),
            ),
          ),
          Text(
            region,
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(width: DswShape.sm),
          Icon(
            LucideIcons.chevron_right,
            size: DswShape.iconTiny,
            color: color.labelTertiary,
          ),
        ],
      ),
    ),
  );

  Widget _waitingCard(DswAlias color) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(DswShape.md),
        decoration: BoxDecoration(
          color: color.bgLayer1,
          borderRadius: BorderRadius.circular(DswShape.controlMd),
          border: Border.all(color: color.borderL2),
        ),
        child: Column(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: DswShape.sm),
            Text(
              AppLocalizations.of(context).welcomeWaiting,
              textAlign: TextAlign.center,
              style: DswType.s14.copyWith(color: color.labelSecondary),
            ),
          ],
        ),
      ),
      const SizedBox(height: DswShape.md),
      CapsuleButton(
        label: AppLocalizations.of(context).welcomeCancelWait,
        onTap: () => setState(() {
          _face = _WelcomeFace.providers;
        }),
      ),
    ],
  );

  Widget _apiKeyCard(DswAlias color) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      dswEnsureShadTheme(
        context,
        ShadInput(
          controller: _apiKeyController,
          obscureText: _apiKeyObscured,
          placeholder: dswInputHint(
            AppLocalizations.of(context).welcomeApiKeyHint,
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
          style: DswType.s14,
          onSubmitted: (_) => _submitApiKey(),
        ),
      ),
      const SizedBox(height: DswShape.sm),
      Row(
        children: [
          Expanded(
            child: CapsuleButton(
              label: AppLocalizations.of(context).welcomeApiKeySave,
              onTap: _submitApiKey,
            ),
          ),
          const SizedBox(width: DswShape.sm),
          Expanded(
            child: CapsuleButton(
              label: AppLocalizations.of(context).welcomeSkip,
              onTap: () {
                widget.auth?.ackWelcome();
                widget.onComplete('skip');
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: DswShape.sm),
      _textLink(
        color,
        AppLocalizations.of(context).welcomeBackToProviders,
        () => setState(() => _face = _WelcomeFace.providers),
      ),
    ],
  );

  Widget _note(DswAlias color, String text, {bool warning = false}) =>
      Container(
        padding: const EdgeInsets.all(DswShape.sm),
        decoration: BoxDecoration(
          color: color.bgLayer2,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Text(
          text,
          style: DswType.xs13.copyWith(
            color: warning ? color.stateErrorPrimary : color.labelTertiary,
          ),
        ),
      );

  Widget _textLink(DswAlias color, String label, VoidCallback onTap) =>
      DswHoverTap(
        onTap: onTap,
        semanticLabel: label,
        builder: (context, hovered, focused) => Padding(
          padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DswType.xs13.copyWith(
              color: hovered ? color.brandPrimary : color.labelSecondary,
              decoration: TextDecoration.underline,
              decorationColor: hovered ? color.brandPrimary : color.borderL2,
            ),
          ),
        ),
      );
}
