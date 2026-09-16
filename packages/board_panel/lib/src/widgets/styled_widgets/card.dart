import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../utils/shad_theme_fallback.dart';

class BoardPanelGroupCard extends StatelessWidget {
  const BoardPanelGroupCard({
    super.key,
    this.child,
    this.margin = const EdgeInsets.all(4),
    this.decoration = const BoxDecoration(
      color: Color(0xFFFFFFFF),
      borderRadius: BorderRadius.zero,
    ),
    this.boxConstraints = const BoxConstraints(minHeight: 40),
  });

  final Widget? child;
  final EdgeInsets margin;
  final BoxDecoration decoration;
  final BoxConstraints boxConstraints;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    return ShadThemeFallback(
      child: Padding(
        padding: margin,
        child: ConstrainedBox(
          constraints: boxConstraints,
          child: ShadCard(
            padding: const EdgeInsets.all(12),
            backgroundColor: decoration.color ?? theme?.colorScheme.card,
            border: ShadBorder.all(
              color: theme?.colorScheme.border ?? const Color(0xFFE2E8F0),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
