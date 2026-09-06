// How the approval-gated tools (write / edit / bash) behave this turn.
//
// The modes dsh's PermissionSelect offers, narrowed to the three this app can
// honor end to end:
//
//   * ask  — interrupt and surface to the user (the default, and the only
//     mode that ever shows the approval panel).
//   * plan — read-only: the gated tools refuse without asking, which is what
//     makes "plan first, execute after approval" a real boundary rather than
//     a promise.
//   * auto — no prompt: every gated call runs as if approved.
//
// The runtime consults the mode through [ApprovalModeHolder] at tool-call
// time, so switching is live — the same pattern as the stop gate, and for the
// same reason: the tools are built once with the Genkit instance, but the
// decision must be readable per call.

/// How gated tool calls decide.
enum ApprovalMode {
  /// Interrupt and wait for the user's verdict (the default).
  ask,

  /// Refuse changes outright — plan mode is read-only.
  plan,

  /// Run gated calls without prompting.
  auto,
}

/// Shared mutable holder, so a mode chosen in the composer reaches tools built
/// at startup.
class ApprovalModeHolder {
  ApprovalMode value = ApprovalMode.ask;
}
