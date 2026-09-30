// Menus: one family, one skin, three shapes.
//
// ADR-0036 decision 1 — where shadcn_ui has the component, the app uses it. It
// has all three shapes a menu here needs, and one skin for all of them:
// `popoverTheme.decoration`, which `ShadPopover` merges into a select's
// dropdown and a context menu alike. That replaces the `popupMenuTheme`
// ADR-0028 had to write to hold Material's defaults at bay.
//
// What shad does not supply is the two things this repo insists on, so they are
// supplied once here instead of thirteen times at call sites:
//
//   * A trigger that is only a trigger. `ShadPopover` uses its `child` as a
//     portal anchor and wires no gesture at all, so an action menu needs the
//     house click primitive under it (ADR-0021: pointer, keyboard, semantics,
//     right-click in one place).
//   * One row vocabulary. A right-click menu is built from
//     `ShadContextMenuItem`, an action menu cannot use that widget (it needs a
//     `ShadContextMenu` ancestor), and two row implementations drift — so
//     [DswMenuEntry] is the description and each shape renders it with its own
//     component, reading the same tokens.
//
// The popup is not a descendant of whatever wraps the trigger in the *layout*,
// but it is one in the *element* tree (`ShadPortal` → `OverlayPortal` builds
// its overlay child inside its own subtree), so a theme mounted here does reach
// the rows. That is what makes [dswEnsureShadTheme] enough for a widget test
// that pumps a bare `MaterialApp`. The app still mounts the real theme in
// `main`'s `MaterialApp.builder`, the seam ADR-0017 and ADR-0032 learned for
// `MediaQuery` and locale, because that is where the text step is composed.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../theme/dsw_shad_bridge.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'tappable.dart';

/// One row of a menu, described rather than drawn: [DswMenu] renders it inside a
/// popover, [DswContextMenu] renders it as a `ShadContextMenuItem`.
class DswMenuEntry {
  const DswMenuEntry({
    required this.label,
    this.icon,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  /// A row that separates rather than acts.
  const DswMenuEntry.divider()
    : label = '',
      icon = null,
      onTap = null,
      trailing = null,
      destructive = false;

  final String label;
  final IconData? icon;

  /// Null is the only way to say "nothing to do right now" — the row dims and
  /// stops answering, exactly as [DswIconButton] says it.
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Paints the label in the error colour. The label only: the row stays a row,
  /// because a filled red block would make "Discard changes" louder than the
  /// confirm dialog that follows it.
  final bool destructive;

  bool get isDivider => label.isEmpty && onTap == null && icon == null;
}

/// The row's seat. Both shapes read it, so an action menu and a right-click
/// menu are the same height; it scales with the text step because shad hands a
/// context item's height to `ShadButton.raw(height:)`, which clamps min AND max
/// (ADR-0017 S3).
double dswMenuSeat(BuildContext context) =>
    DswShape.rowMenu * MediaQuery.textScalerOf(context).scale(1);

/// An action menu: a trigger the caller draws, opened by click, Enter or Space,
/// listing [DswMenuEntry] rows.
class DswMenu extends StatefulWidget {
  const DswMenu({
    super.key,
    required this.label,
    required this.trigger,
    required this.items,
    this.minWidth,
  });

  /// The trigger's accessible name and its tooltip. A menu whose trigger is an
  /// icon has no other name to give.
  final String label;

  /// The trigger's visuals only — the tap, the cursor, the focus and the
  /// semantics all come from here.
  final WidgetBuilder trigger;

  final List<DswMenuEntry> Function(BuildContext context) items;

  /// The popup's floor. It is not the trigger's: `ShadSelect` shares one
  /// `minWidth` between the two, which is why a picker passes 0 and sizes its
  /// rows instead.
  final double? minWidth;

  @override
  State<DswMenu> createState() => _DswMenuState();
}

class _DswMenuState extends State<DswMenu> {
  final controller = ShadPopoverController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _run(VoidCallback? action) {
    controller.hide();
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final menu = Tooltip(
      message: widget.label,
      child: ShadPopover(
        controller: controller,
        padding: const EdgeInsets.all(DswShape.xs),
        popover: (context) => ConstrainedBox(
          constraints: BoxConstraints(minWidth: widget.minWidth ?? 0),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in widget.items(context))
                  if (entry.isDivider)
                    const DswMenuDivider()
                  else
                    DswMenuRow(entry: entry, onTap: () => _run(entry.onTap)),
              ],
            ),
          ),
        ),
        child: DswHoverTap(
          onTap: controller.toggle,
          semanticLabel: widget.label,
          builder: (context, active, focused) => widget.trigger(context),
        ),
      ),
    );
    return dswEnsureShadTheme(context, menu);
  }
}

/// A right-click menu over [child]. The child keeps its own primary action; this
/// only claims the secondary button, and opens at the pointer.
class DswContextMenu extends StatelessWidget {
  const DswContextMenu({
    super.key,
    required this.child,
    required this.items,
    this.minWidth,
  });

  final Widget child;
  final List<DswMenuEntry> Function(BuildContext context) items;
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      for (final entry in items(context))
        if (entry.isDivider)
          const DswMenuDivider()
        else
          ShadContextMenuItem(
            enabled: entry.onTap != null,
            height: dswMenuSeat(context),
            textStyle: entry.destructive
                ? DswType.s14.copyWith(color: context.dsw.stateErrorPrimary)
                : null,
            leading: entry.icon == null
                ? null
                : Icon(
                    entry.icon,
                    size: DswShape.iconSm,
                    color: context.dsw.labelSecondary,
                  ),
            trailing: entry.trailing,
            onPressed: entry.onTap,
            child: Text(entry.label),
          ),
    ];
    final region = ShadContextMenuRegion(
      constraints: BoxConstraints(minWidth: minWidth ?? 128),
      items: rows,
      child: child,
    );
    return dswEnsureShadTheme(context, region);
  }
}

/// The separator all three shapes use, so a divider is the same hairline whether
/// it sits in a popover, a right-click menu or a picker's dropdown.
class DswMenuDivider extends StatelessWidget {
  const DswMenuDivider({super.key});

  @override
  Widget build(BuildContext context) => const ShadSeparator.horizontal(
    margin: EdgeInsets.symmetric(vertical: DswShape.xs),
  );
}

/// One action row: a glyph, a label that yields, an optional trailing widget.
///
/// Public because a [DswSelect] popup can hold a free action row among its
/// options — the model menu's "Model management", the hero's "Choose a folder…"
/// — and a row drawn by a second implementation is a row that drifts.
class DswMenuRow extends StatelessWidget {
  /// [onTap] replaces the entry's own action. Only a popover host needs it: the
  /// popup has to close before the action runs, and only the host knows how.
  const DswMenuRow({super.key, required this.entry, this.onTap});

  final DswMenuEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final action = onTap ?? entry.onTap;
    // shad keeps its dimming widget private, so the row dims itself — from the
    // theme's `disabledOpacity`, which is where dsh's 40% already lives. (shad's
    // own disabled button hardcodes 50%, so a disabled right-click row and a
    // disabled action row differ by that much; the number is still said once.)
    final row = DswHoverTap(
      onTap: action,
      semanticLabel: entry.label,
      builder: (context, active, focused) => Container(
        // A floor, not a nail: a row that carries its own two lines has to be
        // allowed to grow (ADR-0017 S3).
        constraints: BoxConstraints(minHeight: dswMenuSeat(context)),
        padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
        decoration: BoxDecoration(
          color: active || focused ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Row(
          children: [
            if (entry.icon != null) ...[
              Icon(
                entry.icon,
                size: DswShape.iconSm,
                color: color.labelSecondary,
              ),
              const SizedBox(width: DswShape.sm),
            ],
            // The label is what yields, not the glyph: `Row` hands a non-flex
            // child the whole width it was given, so at the 2.2x text step
            // 'Attach documents (PDF, text)…' wanted 896.1 of the 760.0 the
            // screen left the menu and spilled 158.0.
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.s14.copyWith(
                  color: entry.destructive
                      ? color.stateErrorPrimary
                      : color.labelPrimary,
                ),
              ),
            ),
            if (entry.trailing != null) ...[
              const SizedBox(width: DswShape.sm),
              entry.trailing!,
            ],
          ],
        ),
      ),
    );
    return action == null
        ? Opacity(opacity: ShadTheme.of(context).disabledOpacity, child: row)
        : row;
  }
}

/// A value picker whose trigger the caller draws: shad owns the popup, the
/// keyboard, the selection state and the chevron; this owns nothing but the
/// trigger's neutrality, so a chip stays a chip.
///
/// Two things shad does not give, and this adds once rather than per call site:
///
///   * A hover wash. `ShadSelect`'s trigger has none — `ShadDecoration` cannot
///     express hover at all — and a clickable row that does not answer the
///     pointer is the complaint ADR-0017 S2 closed for containers. So the
///     trigger builder is handed `hovered` and a `MouseRegion` here feeds it.
///   * A way for a free row to dismiss. Only shad's own `ShadOption` closes on
///     selection, so [options] is handed the popup's `close` — that is what lets
///     one dropdown hold both the choices and the action that opens their
///     settings.
class DswSelect<T> extends StatefulWidget {
  const DswSelect({
    super.key,
    required this.value,
    required this.onChanged,
    required this.trigger,
    required this.options,
    this.label,
    this.enabled = true,
    this.popupMinWidth,
    this.maxHeight,
  });

  final T? value;
  final ValueChanged<T?>? onChanged;

  /// What the closed control shows. It is also the placeholder, because a
  /// picker with nothing selected still has to draw its own trigger.
  final Widget Function(BuildContext context, T? value, bool hovered) trigger;

  /// Rows for the popup. A `ShadOption` selects; any other widget is free to be
  /// an action, a footer or a divider.
  final List<Widget> Function(BuildContext context, VoidCallback close) options;

  /// The accessible name and tooltip, when the trigger's own text is not enough
  /// (an icon-only chip in a narrow column).
  final String? label;

  /// False both dims the control to the theme's `disabledOpacity` and takes it
  /// out of the focus order — shad's own `ShadDisabled`, the same mechanism a
  /// disabled [DswMenuEntry] row uses.
  final bool enabled;

  /// A floor for the popup's rows, and only for them: `ShadSelect` shares one
  /// `minWidth` between the trigger and the dropdown, so a chip that wants a
  /// wide popup has to size its rows instead of sizing itself.
  final double? popupMinWidth;

  final double? maxHeight;

  @override
  State<DswSelect<T>> createState() => _DswSelectState<T>();
}

class _DswSelectState<T> extends State<DswSelect<T>> {
  final controller = ShadPopoverController();
  bool hovered = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _hover(bool value) {
    if (hovered == value) return;
    setState(() => hovered = value);
  }

  Widget _trigger(BuildContext context, T? value) => MouseRegion(
    onEnter: (_) => _hover(true),
    onExit: (_) => _hover(false),
    child: widget.trigger(context, value, hovered),
  );

  @override
  Widget build(BuildContext context) {
    Widget select = ShadSelect<T>(
      initialValue: widget.value,
      onChanged: widget.onChanged,
      enabled: widget.enabled,
      popoverController: controller,
      // Zero, not the popup's floor: this one number is the trigger's minimum
      // width too, and a chip that must be 320 wide is not a chip.
      minWidth: 0,
      maxWidth: double.infinity,
      maxHeight: widget.maxHeight,
      padding: EdgeInsets.zero,
      // No chevron of shad's own — every trigger here draws its own affordance,
      // and two of them would be two answers to "can I open this".
      trailing: const SizedBox.shrink(),
      showScrollToTopChevron: false,
      showScrollToBottomChevron: false,
      placeholder: Builder(builder: (context) => _trigger(context, null)),
      selectedOptionBuilder: (context, value) => _trigger(context, value),
      options: [
        for (final option in widget.options(context, controller.hide))
          if (widget.popupMinWidth == null)
            option
          else
            ConstrainedBox(
              constraints: BoxConstraints(minWidth: widget.popupMinWidth!),
              child: option,
            ),
      ],
    );
    if (widget.label != null) {
      select = Tooltip(
        message: widget.label!,
        child: Semantics(button: true, label: widget.label!, child: select),
      );
    }
    return dswEnsureShadTheme(context, select);
  }
}
