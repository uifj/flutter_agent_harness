// The service a tool card offers to go back through (ADR-0014 S3).
//
// A scope rather than a constructor thread because the pill sits below the
// transcript's own widgets, and `DetailsSelectionScope`'s Inspect pill already
// established that shape: a deep widget receives its service as an ancestor.
// Riverpod stays confined to `main` + `app_providers` (AGENTS §3), so `main`
// hands the two closures in and this only re-exposes them.
//
// Both halves come from `AppScope`, which is where the workspace guard already
// lives: no folder open, no rewind. A card with no scope above it shows no pill
// at all — a dead affordance is worse than none, and it is what keeps a widget
// test that pumps a bare transcript rendering the row it always did.
//
// It lives beside the card that reads it rather than beside the column that
// mounts it, so the dependency arrow in the tree stays the one it already is:
// `conversation` knows about `tool`, never the other way round.

import 'package:flutter/widgets.dart';

import '../../state/checkpoint_store.dart';

class CheckpointScope extends InheritedWidget {
  const CheckpointScope({
    super.key,
    required this.preview,
    required this.rewind,
    required super.child,
  });

  /// What going back to a recorded change would touch, file by file, without
  /// touching it — the confirmation's content.
  final List<RewindFile> Function(String checkpointId) preview;

  /// Does it, and reports what actually happened.
  final RewindReport Function(String checkpointId) rewind;

  static CheckpointScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CheckpointScope>();

  /// The closures are tear-offs of the composition root, so their behaviour
  /// cannot change without the app's state changing too — and nothing rebuilds
  /// off them anyway: a card reads them when it is tapped.
  @override
  bool updateShouldNotify(covariant CheckpointScope old) => false;
}
