# plan_editor

The plan workspace's attributed-text editing core (ADR-0044): a
`TextEditingController` whose value carries inline marks and renders them
**live while the caret is in the field**, riding the SDK seam at
`EditableText → controller.buildTextSpan`.

Capability checklist and stage plan: `docs/plan-editor-capability-design-2026-10-02.md`
(in the host repository). Reference studies: re-editor / super_editor /
appflowy-editor (ADR-0044 background).

## What it owns

- `EditorMark` — the mark vocabulary (bold, italic, underline, strikethrough,
  keyboard, link(url), textColor(ladder), background(ladder)). Param-carrying
  marks are distinct attributions, so a second colour or URL overwrites the
  overlap instead of stacking.
- `PlanEditorController` — the field controller:
  - every text change is diffed into one remove + one insert; the span bank
    shifts with it (typed text inherits the marks of the character before the
    insertion point; code and link only continue *inside* their run);
  - `buildTextSpan` renders marks live, including the IME composing underline;
  - `toggleMark/addMark/removeMark/hasMark` for the host's toolbar;
  - `sync(AttributedText)` mirrors the host document back in — a marks-only
    push never touches the `TextEditingValue`, so the caret stays put.
- `buildEditorRuns` + `EditorStyleResolver` — the mark→style glue; the host
  supplies the styles, the package stays colour-blind.

## What it does not own

The block tree, the Markdown codec, undo, slash menu and search live in the
host app (`PlanBlockDocument` & co). Truth channels (ADR-0044 decision 3):
while typing the controller is the only shift engine and the document mirrors
it wholesale; when a command changes the document, the controller mirrors it
back. There is no second shift implementation anywhere.

## Gates

```sh
dart analyze
flutter test
```

The package is exempt from the host repo's root lint/format baseline (root
`analysis_options.yaml` excludes `packages/**`, same arrangement as
`board_panel`).
