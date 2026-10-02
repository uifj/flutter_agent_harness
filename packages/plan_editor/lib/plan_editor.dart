/// Attributed-text editing core for the plan workspace's block editor
/// (ADR-0044): a [PlanEditorController] that carries inline marks and
/// renders them live while the caret is in the field, riding the SDK seam
/// at `EditableText` → `controller.buildTextSpan`. The host supplies the
/// styles; the package never decides what a mark looks like.
library;

export 'src/editor_mark.dart';
export 'src/editor_spans.dart' show buildEditorRuns, EditorStyleResolver;
export 'src/plan_editor_controller.dart';

/// The host needs the engine's value types to talk to the controller
/// (building and reading `AttributedText`), but per ADR-0044 it should not
/// depend on the engine directly — these re-exports are the whole surface.
export 'package:attributed_text/attributed_text.dart'
    show AttributedText, Attribution, SpanRange;
