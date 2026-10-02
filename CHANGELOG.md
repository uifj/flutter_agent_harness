# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are the
`pubspec.yaml` version at tag time.

## [0.1.0] - 2026-10-02

First development milestone of the desktop workbench.

### Added
- Two workspace modes over one shell: 代理 (agent conversations over Genkit
  with approvals, queueing, steering, checkpoints/rewind, MCP, sub-agents and
  a split-pane workbench) and 企划 (Anytype-style data views and a block
  editor, ADR-0037/0040/0044).
- `packages/plan_editor`: attributed-text editing core rendering styled marks
  live while the caret is inside the field (ADR-0044).
- Production groundwork (ADR-0045): API key in the OS keychain with a one-time
  plaintext migration, settings/prefs corruption quarantine plus a versioned
  migration table, a reset entry behind confirmation, a local crash archive,
  a 30-day local usage ledger with a settings panel, a shortcut registry as
  the single definition of key bindings, and ZCode-compatible backend
  parameter shapes (`lib/model/zcode_compat`).
- Engineering gates: architecture checker with a fingerprint baseline,
  i18n key-parity guard, theme-token guards, and an amplified-text two-step
  ruler across fifteen surfaces.
