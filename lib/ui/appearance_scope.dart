// The appearance preferences the rendered tree reads back (ADR-0005 S4).
//
// Same shape as `WorkbenchPrefsScope`: `main` mounts it from the saved document,
// and the conversation reads the values it lays out by. It stays an
// [InheritedWidget] rather than a provider read because riverpod is confined to
// `main` + `app_providers` (AGENTS §3) — the tree below receives data as
// ancestors, not by watching.
//
// It carries only the two preferences that actually change pixels today: the
// conversation column's content width, and whether a freshly-shown tool call
// starts open. The rest of the appearance set (text face, interface skin,
// preview mode) persists as intent in `AppSettings` and lands with later work;
// they are deliberately not here so a consumer never reads a value the renderer
// ignores.
//
// The `fallback` argument is what keeps the tree honest without a scope: every
// widget test pumps the conversation without mounting this widget, and must
// fall back to the pre-ADR-0005 default (748, collapsed) so those tests measure
// the same layout they always did. The app always mounts it, so the app never
// sees the fallback.

import 'package:flutter/widgets.dart';

/// Mounts the conversation-affecting appearance values above the tree.
class AppearanceScope extends InheritedWidget {
  const AppearanceScope({
    super.key,
    required this.contentWidth,
    required this.expandToolCalls,
    required super.child,
  });

  /// The transcript column's max content width, resolved from the saved
  /// [AppSettings.conversationWidth].
  final double contentWidth;

  /// Whether a newly-shown tool call starts expanded.
  final bool expandToolCalls;

  /// The current content width, or [fallback] when no scope is mounted above.
  static double widthOf(BuildContext context, double fallback) =>
      context
          .dependOnInheritedWidgetOfExactType<AppearanceScope>()
          ?.contentWidth ??
      fallback;

  /// The current expand-tool-calls preference, or [fallback] (collapsed, the
  /// pre-ADR default) when no scope is mounted above.
  static bool expandToolCallsOf(
    BuildContext context, {
    bool fallback = false,
  }) =>
      context
          .dependOnInheritedWidgetOfExactType<AppearanceScope>()
          ?.expandToolCalls ??
      fallback;

  @override
  bool updateShouldNotify(covariant AppearanceScope old) =>
      old.contentWidth != contentWidth ||
      old.expandToolCalls != expandToolCalls;
}
