import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../utils/shad_theme_fallback.dart';

typedef OnFooterAddButtonClick = void Function();

class BoardPanelGroupFooter extends StatelessWidget {
  const BoardPanelGroupFooter({
    super.key,
    this.icon,
    this.title,
    this.margin = const EdgeInsets.symmetric(horizontal: 12),
    this.height,
    this.onAddButtonClick,
  });

  final Widget? icon;
  final Widget? title;
  final EdgeInsets margin;
  final double? height;
  final OnFooterAddButtonClick? onAddButtonClick;

  @override
  Widget build(BuildContext context) {
    return ShadThemeFallback(
      child: SizedBox(
        height: height,
        child: ShadButton.ghost(
          onPressed: onAddButtonClick,
          width: double.infinity,
          padding: margin,
          leading: icon != null
              ? Padding(padding: const EdgeInsets.only(right: 8), child: icon)
              : null,
          child: title,
        ),
      ),
    );
  }
}
