// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Deprecated: Use [ShadIconButton.ghost] directly instead.
/// This wrapper is kept for backward compatibility with existing tests.
@Deprecated('Use ShadIconButton.ghost directly instead')
class CustomIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback onTap;
  final EdgeInsets margin;
  final EdgeInsets padding;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.margin = EdgeInsets.zero,
    this.padding = const EdgeInsets.all(8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ShadIconButton.raw(
        variant: ShadButtonVariant.ghost,
        icon: icon,
        onPressed: onTap,
        padding: padding,
      ),
    );
  }
}
