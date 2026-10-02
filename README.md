# agent_harness

A Flutter desktop AI agent workbench: two workspace modes over one shell.

- **代理 (Agent)** — a conversation surface over a Google Genkit runtime with
  tool-call projection, approval gates, input queueing and steering, file
  checkpoints with rewind, MCP servers, and a split-pane workbench (file tree,
  editor, terminal, git, diff, browser, sub-agents).
- **企划 (Plan)** — a local markdown workbench that replicates Anytype's
  data-view kernel: records as `Struct` views, Table/List/Gallery/Board/Calendar
  viewers, an object library, and a block editor with live styled marks
  (`packages/plan_editor`).

Three desktop targets (macOS / Windows / Linux). No mobile, no web. The agent
runtime is in-process Google Genkit (Dart); provider keys are BYOK and live in
the OS keychain, never in the settings file.

## Documentation

- [`AGENTS.md`](AGENTS.md) — the entry point for AI coding agents and the
  rules/conventions index.
- [`docs/README.md`](docs/README.md) — the documentation system (ADR classes,
  priorities, state machine) and [`docs/debt-register.md`](docs/debt-register.md)
  is the single status source for known issues.
- [`docs/production-readiness-gap-2026-10-02.md`](docs/production-readiness-gap-2026-10-02.md)
  — the commercial-readiness gap register (form ②: self-built backend with
  ZCode-compatible client parameters, ADR-0045).

## Build & gates

```sh
flutter pub get
dart format --set-exit-if-changed lib test tool spike
dart analyze --fatal-infos lib test tool spike
flutter test
flutter build macos --release   # needs macOS + Xcode + CocoaPods
```

Versioning: `pubspec.yaml` is the single version truth; releases are tagged
from `develop` after the three gates pass. Distribution (signing/notarization)
is tracked in `docs/debt-register.md`.
