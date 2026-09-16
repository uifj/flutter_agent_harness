// The footer quick-menu (ADR-0006 S3).
//
// Fast preference changes without opening the full settings view: tap the footer
// avatar and a small anchored popup offers Theme / Language / Conversation width
// / Text size as inline chips, each writing the shared `AppSettings` immediately
// (none of these rebuild the runtime — see `AppSettings.requiresRuntimeRestart`),
// plus an "Open settings" row that hands off to the full view.
//
// It is an `OverlayEntry` anchored to a `LayerLink` with a tap-away scrim — the
// SAME mechanism the settings surface already uses, deliberately not a route (the
// no-`Navigator.push` invariant). The menu keeps a local mirror of the document
// so a chip's selection moves on the same tap that calls [onChanged], without
// waiting for the provider round-trip; the mirror and the document re-converge on
// the next open.

import 'package:flutter/material.dart';

import '../../../l10n/locales.dart';
import '../../../model/app_settings.dart' as settings;
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';

/// Shows the quick-menu anchored above [link]. [onChanged] receives the updated
/// document on every chip tap; [onOpenSettings] switches to the full view.
void showSettingsQuickMenu({
  required BuildContext context,
  required LayerLink link,
  required settings.AppSettings initial,
  required ValueChanged<settings.AppSettings> onChanged,
  required VoidCallback onOpenSettings,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _QuickMenuOverlay(
      link: link,
      initial: initial,
      onChanged: onChanged,
      onOpenSettings: () {
        entry.remove();
        onOpenSettings();
      },
      onDismiss: entry.remove,
    ),
  );
  overlay.insert(entry);
}

class _QuickMenuOverlay extends StatelessWidget {
  const _QuickMenuOverlay({
    required this.link,
    required this.initial,
    required this.onChanged,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final LayerLink link;
  final settings.AppSettings initial;
  final ValueChanged<settings.AppSettings> onChanged;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Stack(
      children: [
        // Tap-away scrim. Not a blur — this is a transient menu, not a modal.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          child: CompositedTransformFollower(
            link: link,
            // Menu sits above the footer trigger, left-aligned to it.
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -8),
            child: Material(
              elevation: 0,
              color: Colors.transparent,
              child: Container(
                width: 264,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: color.bgLayer2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.borderL2),
                ),
                clipBehavior: Clip.antiAlias,
                child: _QuickMenu(
                  initial: initial,
                  onChanged: onChanged,
                  onOpenSettings: onOpenSettings,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickMenu extends StatefulWidget {
  const _QuickMenu({
    required this.initial,
    required this.onChanged,
    required this.onOpenSettings,
  });

  final settings.AppSettings initial;
  final ValueChanged<settings.AppSettings> onChanged;
  final VoidCallback onOpenSettings;

  @override
  State<_QuickMenu> createState() => _QuickMenuState();
}

class _QuickMenuState extends State<_QuickMenu> {
  late settings.AppSettings _settings = widget.initial;

  void _apply(settings.AppSettings next) {
    setState(() => _settings = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Group<settings.ThemeMode>(
          label: context.tr('theme'),
          options: {
            settings.ThemeMode.system: context.tr('followSystem'),
            settings.ThemeMode.light: context.tr('light'),
            settings.ThemeMode.dark: context.tr('dark'),
          },
          value: _settings.theme,
          onChanged: (v) => _apply(_settings.copyWith(theme: v)),
        ),
        _Group<settings.LocaleMode>(
          label: context.tr('language'),
          options: {
            settings.LocaleMode.system: context.tr('followSystem'),
            settings.LocaleMode.en: 'English',
            settings.LocaleMode.zh: '中文',
          },
          value: _settings.locale,
          onChanged: (v) => _apply(_settings.copyWith(locale: v)),
        ),
        _Group<settings.AppConversationWidth>(
          label: context.tr('conversationWidth'),
          options: {
            settings.AppConversationWidth.normal: context.tr('widthNormal'),
            settings.AppConversationWidth.wide: context.tr('widthWide'),
          },
          value: _settings.conversationWidth,
          onChanged: (v) => _apply(_settings.copyWith(conversationWidth: v)),
        ),
        _Group<settings.AppFontSize>(
          label: context.tr('appearanceTextSize'),
          options: {
            settings.AppFontSize.small: context.tr('sizeSmall'),
            settings.AppFontSize.medium: context.tr('sizeMedium'),
            settings.AppFontSize.large: context.tr('sizeLarge'),
          },
          value: _settings.fontSize,
          onChanged: (v) => _apply(_settings.copyWith(fontSize: v)),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, thickness: 1, color: color.borderL2),
        _OpenSettingsRow(onTap: widget.onOpenSettings),
      ],
    );
  }
}

/// One preference: a label over a row of choice chips, the current one filled.
class _Group<T> extends StatelessWidget {
  const _Group({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Map<T, String> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: DswType.xxs12.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in options.entries)
                _Chip(
                  label: entry.value,
                  selected: entry.key == value,
                  onTap: () => onChanged(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.brandPrimary : color.bgLayer3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color.brandPrimary : color.borderL2,
          ),
        ),
        child: Text(
          label,
          style: DswType.xs13.copyWith(
            color: selected ? color.labelPrimaryForeground : color.labelPrimary,
          ),
        ),
      ),
    );
  }
}

class _OpenSettingsRow extends StatelessWidget {
  const _OpenSettingsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          context.tr('openSettings'),
          style: DswType.s14.copyWith(color: color.labelPrimary),
        ),
      ),
    );
  }
}
