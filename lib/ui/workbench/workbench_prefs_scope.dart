// The workbench's preference seam.
//
// Same reason as [TerminalHost] and [HeroWorkspaceScope]: the tab strip, the
// empty pane's cards, and the terminal's font are built deep under the frame
// and cannot capture app-scoped objects without pinning whichever instance
// registered first. The scope is looked up from each consumer's own context.
//
// A missing scope means the defaults — unlike the hero picker's missing scope
// (which hides it), every consumer here has a behaviour worth keeping when no
// host is mounted, which is what the widget tests rely on: a bare workbench
// renders with every tab type enabled and the default terminal font.

import 'package:flutter/widgets.dart';

import '../../model/workbench_prefs.dart';

class WorkbenchPrefsScope extends InheritedWidget {
  const WorkbenchPrefsScope({
    super.key,
    required this.prefs,
    required super.child,
  });

  final WorkbenchPrefs prefs;

  /// The prefs below [context], or the defaults when no scope is mounted.
  static WorkbenchPrefs of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WorkbenchPrefsScope>()
          ?.prefs ??
      const WorkbenchPrefs();

  @override
  bool updateShouldNotify(WorkbenchPrefsScope oldWidget) =>
      prefs != oldWidget.prefs;
}
