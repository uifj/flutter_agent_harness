import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Wraps [child] with a default [ShadTheme] if no [ShadTheme] ancestor exists.
///
/// Ensures that shadcn_ui components (ShadButton, ShadIconButton, ShadCard, etc.)
/// can be used even when the consuming app uses MaterialApp instead of ShadApp.
class ShadThemeFallback extends StatelessWidget {
  const ShadThemeFallback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (ShadTheme.maybeOf(context) != null) {
      return child;
    }
    return ShadTheme(
      data: ShadThemeData(
        colorScheme: const ShadSlateColorScheme.light(),
        brightness: Brightness.light,
      ),
      child: child,
    );
  }
}
