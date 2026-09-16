import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../utils/shad_theme_fallback.dart';

typedef OnHeaderAddButtonClick = void Function();
typedef OnHeaderMoreButtonClick = void Function();

class BoardPanelGroupHeader extends StatelessWidget {
  const BoardPanelGroupHeader({
    super.key,
    this.height,
    this.icon,
    this.title,
    this.addIcon,
    this.moreIcon,
    this.margin = EdgeInsets.zero,
    this.onAddButtonClick,
    this.onMoreButtonClick,
  });

  final double? height;
  final Widget? icon;
  final Widget? title;
  final Widget? addIcon;
  final Widget? moreIcon;
  final EdgeInsets margin;
  final OnHeaderAddButtonClick? onAddButtonClick;
  final OnHeaderMoreButtonClick? onMoreButtonClick;

  @override
  Widget build(BuildContext context) {
    return ShadThemeFallback(
      child: Container(
        height: height,
        padding: margin,
        child: Row(
          children: [
            if (icon != null) ...[icon!, _hSpace()],
            if (title != null) ...[title!, _hSpace()],
            if (moreIcon != null)
              ShadIconButton.ghost(
                icon: moreIcon!,
                onPressed: onMoreButtonClick,
                padding: const EdgeInsets.all(4),
              ),
            if (addIcon != null)
              ShadIconButton.ghost(
                icon: addIcon!,
                onPressed: onAddButtonClick,
                padding: const EdgeInsets.all(4),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hSpace() => const SizedBox(width: 6);
}
