// One slice of the settings page (ADR-0085 D7): the god-file split keeps
// every hand-written file under the 1,000-line budget. Part of the same
// library, so the page's state and private widgets are visible here.
part of 'model_settings.dart';

/// One row of the nav's filterable list — the section it points at, the label
/// the search matches against, and the icon the cell paints.
class _NavItem {
  const _NavItem(this.section, this.label, this.icon);
  final _Section section;
  final String label;
  final IconData icon;
}

/// The nav's search field — one `ShadInput`, whose frame is the one the bridge
/// gives every field and whose glyph sits in the library's own `leading` slot
/// (`input.dart:112`). It used to be a hand-drawn box around a borderless field,
/// which is the same question answered twice on one surface (§1B S5): the row
/// comment even said "the row's hairline is the frame", while a field is allowed
/// to have a frame of its own.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ShadInput(
      // Named, so a test can tell this field from the ones under it: it sits
      // above every section and is a `ShadInput` like they are.
      key: const ValueKey('settings-search'),
      controller: controller,
      style: DswType.s14.copyWith(color: color.labelPrimary),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8, right: 6),
        child: Icon(
          LucideIcons.search,
          size: DswShape.iconSm,
          color: color.labelTertiary,
        ),
      ),
      // The seat is the text line plus this gutter; the box then *is* 32 at the
      // designed step instead of being nailed to it, which is what let the old
      // hand-drawn frame hide a field that overflowed its own row.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      placeholder: dswInputHint(hint),
      placeholderStyle: DswType.s14.copyWith(color: color.labelDimmed),
    );
  }
}

/// `.navCell`: 40px, radius 12, asymmetric padding, the sidebar nav item's three
/// states.
class _NavCell extends StatefulWidget {
  const _NavCell({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavCell> createState() => _NavCellState();
}

class _NavCellState extends State<_NavCell> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // The nav's visible label is its accessible name, so excludeSemantics stays
    // off and the selected section is announced as a toggled state.
    return DswHoverTap(
      onTap: widget.onTap,
      toggled: widget.active ? true : null,
      builder: (context, hovered, _) => AnimatedContainer(
        duration: DswMotion.respecting(context, DswMotion.fast),
        // One line of nav, so the seat rides the text step: pinned at 40 the
        // label wanted 48.0 in it at the system's 1.8x and above.
        height: 40 * MediaQuery.textScalerOf(context).scale(1),
        padding: const EdgeInsets.only(left: 12, right: 16),
        decoration: BoxDecoration(
          color: widget.active
              ? color.sidebarNavItemActive
              : hovered
              ? color.sidebarNavItemHover
              : null,
          borderRadius: BorderRadius.circular(DswShape.shell),
          // The accent bar: a 3px pill on the leading edge when selected.
          border: widget.active
              ? Border(
                  left: BorderSide(color: color.stateBusinessPrimary, width: 3),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              widget.icon,
              size: DswShape.iconMd,
              color: widget.active ? color.brandPrimary : color.labelSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.s14.copyWith(
                  color: widget.active
                      ? color.labelPrimary
                      : color.labelPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
