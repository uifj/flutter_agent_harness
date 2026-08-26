// Which tool call the details column is showing.
//
// dsh keeps this in the shared chat store as `selection: SelectionTarget | null`
// with `openDetails(target)` / `closeDetails()` beside it, and the comment on
// `DetailsPanel` names the arrangement: "conversation writes, this panel reads".
// This is that seat.
//
// It is deliberately not part of [LayoutController]. dsh's layout store owns
// column widths and nothing else, and the two answer different questions — how
// wide the column is versus what is in it. Keeping them apart is why closing the
// column does not have to forget the selection.
//
// `SelectionTarget` also carries `turnSeq` and `stepSeq`, which address a record
// in dsh's trajectory store. This build has no trajectory, so a call id is the
// whole address.

import 'package:flutter/widgets.dart';

class DetailsSelection extends ChangeNotifier {
  DetailsSelection({this.onSelect});

  /// Run on every [select], including a re-select of the call already showing.
  /// `main` passes `LayoutController.openDetails` here, which is what composes
  /// dsh's `openDetails(target)` out of two independent pieces: pointing the
  /// panel at a call, and making sure the column it lives in is open.
  final VoidCallback? onSelect;

  String? get callId => _callId;
  String? _callId;

  /// The display title of the selected call, held so the header has something to
  /// say about a call the transcript no longer contains — dsh's
  /// `material?.name ?? selection.toolName` fallback.
  String? get toolName => _toolName;
  String? _toolName;

  bool isSelected(String callId) => _callId == callId;

  void select({required String callId, required String toolName}) {
    if (_callId != callId || _toolName != toolName) {
      _callId = callId;
      _toolName = toolName;
      notifyListeners();
    }
    // Outside the guard: clicking the row that is already selected while the
    // column is closed has to reopen it.
    onSelect?.call();
  }

  void clear() {
    if (_callId == null) return;
    _callId = null;
    _toolName = null;
    notifyListeners();
  }
}

/// Hands the selection down to the tool rows that write it.
///
/// dsh reaches the store through a cross-registered share; the nearest thing
/// here is an inherited notifier. [maybeOf] is nullable on purpose: a widget
/// test that mounts a transcript without this scope gets a tool card with no
/// Inspect affordance rather than a crash.
class DetailsSelectionScope extends InheritedNotifier<DetailsSelection> {
  const DetailsSelectionScope({
    super.key,
    required DetailsSelection selection,
    required super.child,
  }) : super(notifier: selection);

  static DetailsSelection? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DetailsSelectionScope>()
      ?.notifier;
}
