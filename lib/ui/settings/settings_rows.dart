// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

/// dsh's own `LanguageRow`/`AppearanceRow` selectors take. A bordered box
/// here would read as one of the form inputs, which a preference is not.
class _SettingCellRow<T> extends StatelessWidget {
  const _SettingCellRow({
    required this.title,
    required this.description,
    required this.labels,
    required this.value,
    required this.onChanged,
    this.leading,
    this.last = false,
  });

  final String title;
  final String description;

  /// The option labels, keyed by the value the menu commits.
  final Map<T, String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  /// An optional icon painted in `labelTertiary` to the left of the text —
  /// echoes the nav's icon language so each row self-describes.
  final IconData? leading;

  /// Whether the hairline separator is drawn. The section sets it on its
  /// last row; dsh's column strips it there (`:last-child { border: none }`).
  final bool last;

  /// The hover wash used to be this widget's own `State` plus a `MouseRegion`;
  /// [DswSelect] reports the pointer instead, so the row is stateless again.
  Widget _menu(DswAlias color) => DswSelect<T>(
    value: value,
    onChanged: (picked) {
      if (picked != null) onChanged(picked);
    },
    popupMinWidth: 160,
    options: (context, close) => [
      for (final entry in labels.entries)
        ShadOption<T>(value: entry.key, child: Text(entry.value)),
    ],
    trigger: (context, selected, hovered) => AnimatedContainer(
      duration: DswMotion.respecting(context, DswMotion.fast),
      // One line of chrome, so the seat follows the text step: 36 gave
      // this row's 14/22 label 36.0 where 40.0 was needed at 1.8x. A floor
      // rather than a height because the label takes a second line only when
      // even the whole card cannot hold it on one (2.2x in a 430px card).
      constraints: BoxConstraints(
        minHeight: 36 * MediaQuery.textScalerOf(context).scale(1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: hovered ? color.interactiveBgHover : color.bgModulePlatform,
        borderRadius: BorderRadius.circular(DswShape.float),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              labels[value]!,
              style: DswType.s14.copyWith(color: color.labelPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            LucideIcons.chevron_down,
            size: DswShape.iconSm,
            color: color.labelTertiary,
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final titleStyle = DswType.s14.copyWith(color: color.labelPrimary);
    final leadingCells = <Widget>[
      if (leading != null) ...[
        Icon(leading, size: DswShape.iconMd, color: color.labelTertiary),
        const SizedBox(width: 12),
      ],
    ];
    final text = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 4),
          Text(
            description,
            style: DswType.xxs12.copyWith(color: color.labelTertiary),
          ),
        ],
      ),
    );
    // The pill is the unshrinkable half: its one-word value is the preference
    // itself, and a squeezed pill reads as a form input. In a 700px window at
    // 2.2x the row form gave the title column 0.0px and spilled 64px past the
    // card, so under one line of room for title plus pill the pill moves
    // below the label instead.
    final beside =
        (leading == null ? 0.0 : 28.0) +
        _oneLineWidth(context, title, titleStyle) +
        8 +
        _oneLineWidth(context, labels[value]!, titleStyle) +
        12 +
        14 +
        28;
    // The line under every row but the last is the library's separator rather
    // than a border on the row's own box: a section is a column of rows with a
    // line *between* them, which is what `ShadSeparator` is for (§1B S7).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: LayoutBuilder(
            builder: (context, box) {
              if (beside <= box.maxWidth) {
                return Row(
                  children: [
                    ...leadingCells,
                    text,
                    const SizedBox(width: 8),
                    _menu(color),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [...leadingCells, text]),
                  SizedBox(
                    height: 12 * MediaQuery.textScalerOf(context).scale(1),
                  ),
                  _menu(color),
                ],
              );
            },
          ),
        ),
        if (!last) ShadSeparator.horizontal(color: color.borderL2),
      ],
    );
  }
}

/// `.field` + `.input`: a 12/18 label over a 32px box, radius 8, `border-l2`
/// resting and the brand colour on focus.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscured = false,
    this.autofocus = false,
    this.code = false,
    this.trailing,
    this.focusNode,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscured;
  final bool autofocus;

  /// Renders the value in the code face, for fields holding a wire identifier or
  /// a path rather than prose.
  final bool code;

  final Widget? trailing;

  /// For fields that commit on their own cadence rather than the panel's Save.
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    var style = DswType.s14.copyWith(color: color.labelPrimary);
    if (code) {
      style = style.copyWith(
        fontFamily: dswFontFamilyCode,
        fontFamilyFallback: dswFontFamilyCodeFallback,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
        ),
        const SizedBox(height: 6),
        // ADR-0002 Stage 5c: the field box is shad's own input (coloured through
        // the dsw bridge) rather than a hand-rolled Material decoration, and the
        // trailing action rides ShadInput's own slot instead of a sibling in a
        // Row.
        ShadInput(
          controller: controller,
          autofocus: autofocus,
          focusNode: focusNode,
          onSubmitted: onSubmitted,
          obscureText: obscured,
          // A key and a path are both single-line values that must not be
          // "helpfully" capitalised or corrected.
          autocorrect: false,
          enableSuggestions: false,
          style: style,
          placeholder: Text(
            hint,
            // A placeholder is one line, as it is on the web: at the system's
            // larger text steps a wrapping hint either grew the field or was cut
            // mid-word, and neither says what the field wants.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style.copyWith(color: color.labelDimmed),
          ),
          trailing: trailing,
        ),
      ],
    );
  }
}

/// A label, a one-line description, and a switch — the side card's row shape.
///
/// The switch is shad's (ADR-0036 row 25), which settles the three things the
/// drawn one had to answer for itself: it takes Enter and Space, it announces
/// `toggled`, and a disabled one dims through `ShadDisabled` rather than a
/// hand-picked opacity. `direction: rtl` is what keeps the reading order this
/// panel has everywhere else — text first, control last.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ShadSwitch(
      value: value,
      onChanged: (_) => onChanged(!value),
      direction: TextDirection.rtl,
      label: Text(
        label,
        style: DswType.xxs12.copyWith(color: color.labelSecondary),
      ),
      sublabel: Text(
        description,
        style: DswType.xxxs11.copyWith(color: color.labelTertiary),
      ),
      // The only colour the theme cannot hold: shad has ONE thumb constant, and
      // this design says an off thumb is quiet (`labelTertiary`) and an on thumb
      // is the foreground (`labelPrimaryForeground`). A single value in the
      // bridge would answer the state question with one of the two, so the state
      // goes where the state is known — and the tracks stay themed.
      thumbColor: value ? color.labelPrimaryForeground : color.labelTertiary,
    );
  }
}

/// A label over a minus/plus stepper capped to [min]/[max] — the font size
/// control, whose whole range is 24 integers and deserves no free-form field.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            DswIconButton.outlined(
              icon: LucideIcons.minus,
              tooltip: AppLocalizations.of(context).decrease,
              onTap: value > min ? () => onChanged(value - 1) : null,
              size: 28,
              iconSize: DswShape.iconSm,
            ),
            SizedBox(
              // A one-line readout, so both of its dimensions ride the text
              // step: 40x32 wrapped "13" onto two clipped lines at 1.8x.
              width: 40 * MediaQuery.textScalerOf(context).scale(1),
              height: 32 * MediaQuery.textScalerOf(context).scale(1),
              child: Center(
                child: Text(
                  '$value',
                  maxLines: 1,
                  style: DswType.s14.copyWith(
                    color: color.labelPrimary,
                    fontFamily: dswFontFamilyCode,
                    fontFamilyFallback: dswFontFamilyCodeFallback,
                  ),
                ),
              ),
            ),
            DswIconButton.outlined(
              icon: LucideIcons.plus,
              tooltip: AppLocalizations.of(context).increase,
              onTap: value < max ? () => onChanged(value + 1) : null,
              size: 28,
              iconSize: DswShape.iconSm,
            ),
          ],
        ),
      ],
    );
  }
}

/// The key field's reveal. It is the one affordance that belongs to the field
/// rather than the card around it, so it rides `ShadInput.trailing` — and its
/// body is the shared icon control (ADR-0024), which is what says a press, a Tab
/// stop and the accessible name all arrive together.
class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DswIconButton(
      icon: revealed ? LucideIcons.eye_off : LucideIcons.eye,
      tooltip: revealed
          ? AppLocalizations.of(context).hideKey
          : AppLocalizations.of(context).showKey,
      onTap: onTap,
      size: 28,
      iconSize: DswShape.iconMd,
    );
  }
}

/// `.credentialDot` + its two fills: the row's stored-key state, as one 8px
/// circle. Unlabelled by design — the tooltip carries the sentence, the dot
/// carries only the colour, the way dsh's does.
class _CredentialDot extends StatelessWidget {
  const _CredentialDot({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: configured
          ? AppLocalizations.of(context).keyConfigured
          : AppLocalizations.of(context).keyMissing,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: configured
              ? color.stateSuccessPrimary
              : color.stateErrorPrimary,
        ),
      ),
    );
  }
}

/// The trailing X on a server card: the `_RevealButton` shape with a
/// destructive glyph, since removing a row is the one destructive action the
/// panel can take.
/// A settings row with a title, description, and a trailing action button.
/// Used by the backup section for export/import actions.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    required this.description,
    required this.button,
    this.last = false,
  });

  final String title;
  final String description;
  final Widget button;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: DswType.xxs12.copyWith(color: color.labelSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          button,
        ],
      ),
    );
  }
}

/// One label/value row of the usage section — the twin of `_Field`-style
/// rows elsewhere in this file, kept separate so the usage data shape never
/// grows settings semantics.
class _UsageStatRow extends StatelessWidget {
  const _UsageStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: DswType.s14.copyWith(color: color.labelSecondary),
            ),
          ),
          Text(
            value,
            style: DswType.sStrong14.copyWith(color: color.labelPrimary),
          ),
        ],
      ),
    );
  }
}
