// Stand-ins for the tab types stages four to six fill in.
//
// A tab type registered with a body that says what it will be beats one that is
// absent: the workbench can already open, move, split and persist a terminal or a
// git tab, and those gestures are what stage three is for. An unregistered type
// would instead render as the registry's "unknown type" fallback, which is the
// same pixel area saying something untrue.
//
// Each of these is deleted, not edited, when its real tab lands.

import 'package:flutter/material.dart';

import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';

class PendingTab extends StatelessWidget {
  const PendingTab({super.key, required this.icon, required this.message});

  final IconData icon;

  /// What this tab will show, in the user's terms. Not "not implemented": that
  /// tells them about the codebase rather than about the app.
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgLayer2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color.labelTertiary),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
