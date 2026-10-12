<div align="center">

# 企划星 · PlanStar

**A desktop AI agent workbench built from scratch with Flutter + Google Genkit.**

Two workspace modes over one shell — an **agent** that reads, writes and runs
code in your project, and a **plan** surface that reproduces a Notion/Anytype-style
data-view kernel over local Markdown. Bring your own model key; nothing leaves
your machine but the API call you make.

*macOS · Windows · Linux · Flutter 3.41 · Dart 3.11 · Genkit 0.16*

</div>

---

> 中文文档见 [README_zh.md](README_zh.md)。

## Gallery

| Agent mode — chat over a Genkit runtime, workspaces grouped in the sidebar |
| --- |
| ![Agent chat](docs/screenshots/01-agent-chat.png) |

| Plan mode — a local Markdown vault with a collapsible collection & notes sidebar |
| --- |
| ![Plan mode](docs/screenshots/02-plan-mode.png) |

| Data views — the same records projected as Board / Table / List / Gallery / Calendar |
| --- |
| ![Plan data view](docs/screenshots/03-plan-dataview.png) |

| Settings — 15 sections: appearance, models, workspaces, workbench, MCP, shortcuts, usage, backup, approval rules… |
| --- |
| ![Settings](docs/screenshots/04-settings.png) |

---

## What is this?

PlanStar is a **native desktop application** — not a web wrapper, not an Electron
app — where an AI coding agent and a personal knowledge workspace live side by
side. One window, one shell, two modes you flip between in the sidebar:

- **代理 · Agent** — a conversation surface over an in-process
  [Google Genkit](https://genkit.dev) (Dart) runtime, with a real tool loop and a
  split-pane workbench for acting on your files.
- **企划 · Plan** — a local Markdown workbench that replicates
  [Anytype](https://anytype.io)'s data-view kernel: records are `Struct` views,
  and one set of records renders as Table / List / Gallery / Board / Calendar,
  backed by an object library and a block editor.

The agent runtime and the plan workspace share the same notion of a *workspace*
(a folder on disk) but are otherwise independent — you can use either alone.

---

## Agent mode

Everything the agent does is projected into the UI as inspectable, revertible
events — no silent file mutation.

- **Tool-call projection** — every `read` / `write` / `edit` / `glob` / `grep` /
  `bash` call renders as a card with its arguments, result, and diff.
- **Approval gates** — configurable per-workspace rules for what the agent may do
  without asking (`每次询问` / auto-allow read-only / custom rules).
- **Input queueing & steering** — type while the agent is busy; queue items and
  mid-turn guidance are injected at the next safe point.
- **File checkpoints + rewind** — before any overwrite the "before" image is
  captured, so a tool card carries a one-click rewind pill.
- **MCP servers** — connect external Model Context Protocol tools from settings.
- **Sub-agents & side chat** — delegate work to a `general-purpose` sub-agent, or
  open a side conversation that doesn't pollute the main thread.
- **Split-pane workbench** — file tree, code editor, integrated terminal
  (`flutter_pty` + `xterm`), git panel, diff viewer, in-app browser, and side chat,
  arranged in a draggable split layout persisted per workspace.
- **`@` mentions** — a BFS file index lets you reference project files in the
  composer; they're expanded into context on send.
- **Session groups** — conversation history grouped by workspace, with pinning,
  rename, and tombstones.

## Plan mode

A serious local knowledge tool that treats Markdown as the single source of truth
on disk.

- **One record, five projections** — Table / List / Gallery / Board / Calendar all
  read from the same store; filter / sort / group / limit is a shared engine.
- **Block editor** — a live styled-mark editor (`packages/plan_editor`, built on
  `re_editor`) with toggles, callouts, quotes, code, tables, and inline marks.
- **Object library** — All Content, object info, new-collection, templates, Date,
  Gallery, and a Bin (soft-deleted records).
- **Vault tree** — the workspace's `.md` files as a collapsible explorer in the
  sidebar; Markdown that can't fit a block round-trips through a
  `<!-- plan:{json} -->` envelope.
- **Kanban & calendar** — board columns with drag-to-reorder and a calendar month
  view, via the in-repo `packages/board_panel`.

---

## Tech stack

| Layer | Choice |
| --- | --- |
| Framework | Flutter 3.41 / Dart 3.11 |
| Agent runtime | Google Genkit 0.16 (+ `genkit_openai` / `_anthropic` / `_google_genai` / `_mcp` / `_middleware`) |
| State | `flutter_riverpod` 3.2 (annotation mode) |
| UI kit | `shadcn_ui` 0.56 + a `dsw_*` design-token theme layer |
| Persistence | `drift` 2.31 (single multi-domain SQLite db) + atomic JSON stores |
| Editor | `re_editor` + `gpt_markdown` (LaTeX + Mermaid fenced diagrams) |
| Terminal / browser | `flutter_pty` + `xterm`, `flutter_inappwebview` |
| Secrets | `flutter_secure_storage` — OS keychain (Keychain / DPAPI / libsecret) |
| Local packages | In-repo monorepo under `packages/`, consumed downward by `lib` — `board_panel` (data views), `plan_editor` (block editor), `app_common` (feedback + in-app upgrade); ADR-0083 / ADR-0084 |
| Localization | `flutter gen-l10n` with ARB as the single on-disk source (en/zh); `app_common` ships its own generated bundle (`AppCommonLocalizations`) |

### Architecture invariants

The layering is enforced by an executable gate, not just convention:

```sh
dart tool/check_architecture.dart   # 8 rules, fingerprint baseline, blocks new violations
```

- `package:genkit` may only be imported inside `lib/genkit/`.
- `lib/model/` never imports Flutter — it's the pure-Dart vocabulary between the
  runtime and the UI.
- The runtime never reaches into `lib/state/` or touches `dart:ui`.
- `lib/ui/` doesn't call `dart:io` directly (goes through `lib/host/`).

### Local packages & the monorepo

`packages/` is a three-layer monorepo with a **one-way** dependency route
(ADR-0083 / ADR-0084):

```
sentry ─▶ stone_core ─▶ pudding ─▶ appunits ─▶ lib
```

`lib/` is the only consumer — no package may import `lib`. Three in-repo packages are
path-deps wired into `lib` and actually used: **`board_panel`** (plan-mode board &
calendar), **`plan_editor`** (the styled Markdown block editor), and **`app_common`**
(the host-agnostic feedback form + in-app upgrade panel, whose UI copy lives in a
package-owned gen-l10n bundle). The rest (`appunits_core`, `stone_core`, `pudding`)
are vendored / parked and intentionally *not* consumed — ADR-0084's boundary map
records why each is refused or deferred.

---

## Security & privacy

- **Bring your own key.** Provider API keys live in the OS keychain and are
  stripped from the settings file before it's written — a plaintext key never
  touches disk or git.
- **Local-first.** Plan data is plain Markdown in your workspace; the agent acts
  only inside folders you've authorized.
- **Inspectable actions.** Every tool call and file write is visible and rewindable.

---

## Platform support

Three desktop targets are first-class: **macOS**, **Windows**, **Linux**.
`android/` and `ios/` are branding scaffolding only — the app targets desktop and
will not run on mobile (it hits unregistered desktop plugins at startup).

---

## Build & test

```sh
flutter pub get                                  # first step on a new machine
dart format --set-exit-if-changed lib test tool spike
dart analyze --fatal-infos lib test tool spike
flutter test                                     # 127 test files
dart tool/check_architecture.dart                # architecture gate
dart tool/contrast_check.dart                    # WCAG contrast on theme tokens

flutter build macos --release                    # macOS + Xcode + CocoaPods
flutter build windows --release                  # VS C++ desktop workload + CMake
flutter build linux --release                    # GTK toolchain
```

`pubspec.yaml` is the single version truth; releases are tagged from `develop`
after the gates pass.

---

## Documentation

- [`AGENTS.md`](AGENTS.md) — entry point for AI coding agents; rules & conventions index.
- [`docs/README.md`](docs/README.md) — the ADR system (classes, priorities, state machine).
- [`docs/debt-register.md`](docs/debt-register.md) — single status source for known issues and technical debt.
- [`docs/adr/`](docs/adr/) — Architecture Decision Records documenting every design call (latest: ADR-0084).
- [`docs/production-readiness-gap-2026-10-02.md`](docs/production-readiness-gap-2026-10-02.md) — commercial-readiness gap register.

---

## Status

Early production — version `0.1.0`, ad-hoc signed, actively developed. The core
agent loop, workbench, and plan data-view kernel are functional and covered by
tests; distribution signing/notarization and the self-hosted backend are tracked
as open items.

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)** — see [`LICENSE`](LICENSE) for the full text.

You are free to use, study, share, and modify this software, provided that derivative works you distribute are released under the same license and their source is disclosed.
