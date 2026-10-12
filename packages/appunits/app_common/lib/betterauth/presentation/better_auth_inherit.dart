import 'package:flutter/material.dart';
import 'package:flutter_better_auth/core/api/better_auth_client.dart';

class BetterAuthInherit extends InheritedWidget {
  final BetterAuthClient client;

  const BetterAuthInherit({
    super.key,
    required this.client,
    required super.child,
  });

  static BetterAuthClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<BetterAuthInherit>();
    if (provider == null) {
      throw StateError(
        'BetterAuthClient not found in context. '
        'Wrap the subtree with BetterAuthProvider.',
      );
    }
    return provider.client;
  }

  /// Returns null if no [BetterAuthProvider] ancestor is present (does not subscribe for rebuilds).
  static BetterAuthClient? maybeOf(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<BetterAuthInherit>();
    final inherited = element?.widget;
    return inherited is BetterAuthInherit ? inherited.client : null;
  }

  @override
  bool updateShouldNotify(covariant BetterAuthInherit oldWidget) {
    return client != oldWidget.client;
  }
}
