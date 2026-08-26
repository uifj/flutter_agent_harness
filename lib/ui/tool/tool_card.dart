// One tool call in the transcript.
//
// A port of `ToolRow.tsx` / `ToolRow.module.css` (figma 122:9479): the shared
// 24px disclosure header — `[16 leading] gap6 [title 14/24] gap8 [2x2 dot] gap8
// [summary FILL truncate]` — over a collapsed-by-default body. The collapsed row
// is always one line, so a run of calls stays scannable.
//
// The row model below is `models/tool-call-model.ts` narrowed to this build's
// three tools: same variant table, same title/summary precedence, same "first
// error line replaces the summary" rule. dsh's card materials (terminal, diff,
// read, search, web blocks) are not ported — every call here is text in, text
// out, which is exactly dsh's IN/OUT card path.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../model/conversation.dart';
import '../../state/details_selection.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/disclosure_row.dart';
import '../primitives/row_sweep.dart';
import '../primitives/state_dot.dart';

class ToolCard extends StatefulWidget {
  const ToolCard({super.key, required this.node});

  final ToolCallNode node;

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  /// Expand state is view-local, as in the source: it is about this reader's
  /// attention, not about the call.
  bool _expanded = false;

  /// `.root:hover`, which is what reveals the Inspect pill — the whole call,
  /// title row included, not just the body the pill sits under.
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final model = _ToolRowModel.of(widget.node);
    final open = _expanded && model.expandable;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: _row(color, model, open),
    );
  }

  Widget _row(DswAlias color, _ToolRowModel model, bool open) => DisclosureRow(
      icon: _leading(color, model),
      title: model.title,
      // 400, like the reasoning row: the summary beside it is the content.
      titleStyle: DswType.s14.copyWith(
        height: 24 / 14,
        fontWeight: FontWeight.w400,
        color: color.labelSecondary,
      ),
      chevronColor: color.labelSecondary,
      open: open,
      expandable: model.expandable,
      onToggle: () => setState(() => _expanded = !_expanded),
      // Running keeps the tool icon and lets the sweep carry the in-flight
      // signal; a settled row that went wrong swaps the icon for a state dot.
      rowOverlay: model.state == _RowState.running
          ? RowSweep(base: color.bgBase)
          : null,
      // The summary names which call this is, which stays worth knowing once
      // the body is out.
      keepCollapsedWhenOpen: true,
      collapsed: model.summary.isEmpty ? null : _summary(color, model),
      child: _body(color, model),
    );

  /// The leading slot yields to the terminal state semantic: error is red,
  /// interrupted is an amber halo. Running keeps the tool icon — the sweep
  /// carries the in-flight signal, so a second marker would only compete.
  Widget _leading(DswAlias color, _ToolRowModel model) => switch (model.state) {
    _RowState.error => const StateDot(state: StateDotState.error),
    _RowState.stopped => const StateDot(state: StateDotState.warning),
    _ => Icon(model.icon, size: 14, color: color.labelTertiary),
  };

  /// A 2px separator, then the FILL-truncated summary. An empty summary drops
  /// the separator with it — a row that is only its title shows no trailing dot.
  Widget _summary(DswAlias color, _ToolRowModel model) => Row(
    children: [
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 2,
        height: 2,
        decoration: BoxDecoration(
          color: color.labelCaption,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
      Expanded(
        child: Text(
          model.summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.s14.copyWith(
            height: 24 / 14,
            color: model.summaryIsFailure
                ? color.stateErrorPrimary
                : color.labelTertiary,
          ),
        ),
      ),
    ],
  );

  /// `.bodyWrap`: the IN/OUT card (figma 1249:35657) with the Inspect pill under
  /// it. A sibling of the header row rather than part of it, which is what keeps
  /// a click in here from toggling the row.
  Widget? _body(DswAlias color, _ToolRowModel model) {
    if (!model.expandable) return null;
    final selection = DetailsSelectionScope.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ioCard(color, model),
        // No scope, no pill: a transcript mounted without one has nowhere to
        // send the selection, and a dead affordance is worse than none.
        if (selection != null)
          _InspectPill(
            revealed: _hovered,
            onTap: () => selection.select(
              callId: widget.node.id,
              toolName: model.title,
            ),
          ),
      ],
    );
  }

  Widget _ioCard(DswAlias color, _ToolRowModel model) {
    final input = model.input;
    final output = model.output;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: color.borderL1),
        borderRadius: BorderRadius.circular(12),
        color: color.markdownCodeBlock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (input != null) _section(color, 'IN', input, isError: false),
          // The hairline sits between the padded sections, so it spans the card.
          if (input != null && output != null)
            Container(height: 1, color: color.borderL2),
          if (output != null)
            _section(color, 'OUT', output, isError: model.outputIsError),
        ],
      ),
    );
  }

  /// One gutter-labelled section, capped and scrolling alone so a long input
  /// never buries a short output.
  ///
  /// dsh makes the label `position: sticky` inside the section's own scroller;
  /// here the label sits outside it instead, which parks it by construction.
  Widget _section(
    DswAlias color,
    String label,
    String text, {
    required bool isError,
  }) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 150),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            // Caption, not tertiary: one step dimmer than the payload, so the
            // gutter labels read as labels rather than as part of the content.
            style: DswType.markdownCodeBlockSmall.copyWith(
              color: color.labelCaption,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: DswType.markdownCodeBlockSmall.copyWith(
                  color: isError
                      ? color.stateErrorPrimary
                      : color.labelSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// -----------------------------------------------------------------------------
// Inspect pill
// -----------------------------------------------------------------------------

/// `.inspectButton`: a quiet 11/16 pill in real flow under the expanded body's
/// bottom-left corner, revealed by hovering anywhere on the call.
///
/// It reserves its line whether revealed or not, which is the point of doing this
/// with opacity rather than with mounting: revealing it never shifts the
/// transcript under the pointer.
///
/// dsh's pill jumps to the trajectory record for the call. This build has no
/// trajectory, so it points at the details column instead — the same gesture
/// ("show me more about this call") landing on the richest view there is here,
/// and the seat dsh's own `openDetails` was cut for.
class _InspectPill extends StatefulWidget {
  const _InspectPill({required this.revealed, required this.onTap});

  final bool revealed;
  final VoidCallback onTap;

  @override
  State<_InspectPill> createState() => _InspectPillState();
}

class _InspectPillState extends State<_InspectPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      // `margin: 4px 0 2px 4px`.
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 2),
      child: AnimatedOpacity(
        opacity: widget.revealed ? 1 : 0,
        duration: DswMotion.respecting(context, DswMotion.fast),
        curve: DswMotion.easeInOut,
        // Not wrapped in an `IgnorePointer` while hidden, matching CSS: an
        // `opacity: 0` button still takes clicks, and the only way to reach this
        // one is to hover the row, which reveals it.
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                // Base, not the overlay token: the overlay is a raised surface
                // and reads too heavy for a quiet in-flow affordance.
                color: _hovered ? color.interactiveBgHoverSolid : color.bgBase,
                border: Border.all(color: color.borderL2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    // `IconInspectOutline12` is the `</>` glyph: two chevrons
                    // around a slash.
                    LucideIcons.code,
                    size: 12,
                    color: _hovered ? color.labelPrimary : color.labelSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Inspect',
                    style: DswType.xs13.copyWith(
                      fontSize: 11,
                      height: 16 / 11,
                      color: _hovered
                          ? color.labelPrimary
                          : color.labelSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Row model
// -----------------------------------------------------------------------------

/// `ToolRowState`: the row's terminal semantic, which is what decides the
/// leading slot and the sweep. Deliberately coarser than [ToolStatus] — the
/// chrome has three things to say, not five.
enum _RowState { running, ok, error, stopped }

/// `ToolRowVariant`, narrowed to this build's tools.
///
/// The variant — not the tool name — is what the chrome keys on, because dsh's
/// rows are shared: `grep` and `glob` are one search row, `write` and `edit` are
/// one mutation row. A tool with no card material of its own falls to [others],
/// which is a working row and not a degraded one: the title names the act and
/// the path lands in the summary slot.
enum _RowVariant { search, read, bash, write, edit, others }

/// `TOOL_VARIANTS`. dsh also maps `pwsh`, `web_fetch`, `web_search` and
/// `run_code`; those tools do not exist here, and listing them would claim
/// coverage this build does not have.
const _toolVariants = {
  'read': _RowVariant.read,
  'write': _RowVariant.write,
  'edit': _RowVariant.edit,
  'glob': _RowVariant.search,
  'grep': _RowVariant.search,
  'bash': _RowVariant.bash,
};

/// `VARIANT_TITLES` overlaid with `SEARCH_TITLES`.
///
/// dsh's search row titles itself per tool rather than per variant — one row
/// serving two tools would otherwise say 'Search' for both, and which one ran is
/// the more useful fact.
const _titles = {
  'read': 'Read',
  'write': 'Write',
  'edit': 'Edit',
  'glob': 'Glob',
  'grep': 'Grep',
  'bash': 'Bash',
};

const _icons = {
  // `IconBrowseOutline16`, `IconSearchOutline16`, `IconEditOutline16` and the
  // bash row's `IconApiOutline14`, in their nearest Lucide glyphs.
  _RowVariant.read: LucideIcons.book_open,
  _RowVariant.search: LucideIcons.search,
  _RowVariant.write: LucideIcons.pen_line,
  _RowVariant.edit: LucideIcons.pen_line,
  _RowVariant.bash: LucideIcons.terminal,
  _RowVariant.others: LucideIcons.sparkles,
};

/// `SUMMARY_KEYS`, per variant.
///
/// bash leads with `description` because that is the field the model writes for
/// the user to read; the command itself is the fallback when it omitted one. The
/// `url` seats are dsh's web tools' and stay unused here, since dropping them
/// would make these lists say something different from their source.
const _summaryKeys = {
  _RowVariant.read: ['path', 'file_path', 'url'],
  _RowVariant.search: ['query', 'pattern', 'url'],
  _RowVariant.write: ['path', 'file_path'],
  _RowVariant.edit: ['path', 'file_path'],
  _RowVariant.bash: ['description', 'command'],
  _RowVariant.others: <String>[],
};

class _ToolRowModel {
  const _ToolRowModel({
    required this.title,
    required this.icon,
    required this.summary,
    required this.summaryIsFailure,
    required this.input,
    required this.output,
    required this.outputIsError,
    required this.state,
  });

  final String title;
  final IconData icon;
  final String summary;

  /// Whether [summary] is the failure line rather than the call's arguments.
  final bool summaryIsFailure;

  final String? input;
  final String? output;
  final bool outputIsError;
  final _RowState state;

  bool get expandable => input != null || output != null;

  static _ToolRowModel of(ToolCallNode node) {
    final state = switch (node.status) {
      ToolStatus.running => _RowState.running,
      ToolStatus.succeeded => _RowState.ok,
      ToolStatus.failed => _RowState.error,
      // Both pauses are interruptions, not failures: waiting on the user and
      // refused by the user leave the call unrun, which is what warning says.
      ToolStatus.awaitingApproval => _RowState.stopped,
      ToolStatus.denied => _RowState.stopped,
    };
    final failure = state == _RowState.error
        ? _firstLine(node.errorMessage ?? '')
        : '';
    // An error row's collapsed summary IS the failure: the first error line
    // outranks the args summary.
    final summary = failure.isNotEmpty ? failure : _summaryOf(node);
    final output = node.errorMessage ?? _format(node.output);
    final variant = _toolVariants[node.name] ?? _RowVariant.others;
    return _ToolRowModel(
      title: _titles[node.name] ?? 'Tool call',
      icon: _icons[variant]!,
      summary: summary,
      summaryIsFailure: failure.isNotEmpty,
      input: node.arguments.isEmpty ? null : _pretty(node.arguments),
      output: output == null || output.isEmpty ? null : output,
      outputIsError: node.errorMessage != null,
      state: state,
    );
  }

  /// The first preferred string argument, then any string argument, then the
  /// whole args blob — dsh's `deriveSummary`, minus the multi-query case its
  /// search tools need.
  ///
  /// An unknown tool prefixes its wire name, since the generic title does not
  /// say which tool ran.
  static String _summaryOf(ToolCallNode node) {
    final args = node.arguments;
    final variant = _toolVariants[node.name] ?? _RowVariant.others;
    var base = '';
    for (final key in _summaryKeys[variant]!) {
      final value = args[key];
      if (value is String && value.isNotEmpty) {
        base = _firstLine(value);
        break;
      }
    }
    if (base.isEmpty) {
      for (final value in args.values) {
        if (value is String && value.isNotEmpty) {
          base = _firstLine(value);
          break;
        }
      }
    }
    if (base.isEmpty) base = _firstLine(_pretty(args));
    if (_titles.containsKey(node.name)) return base;
    return '${node.name} · $base';
  }

  static String _firstLine(String text) {
    final newline = text.indexOf('\n');
    return newline == -1 ? text : text.substring(0, newline);
  }

  /// A tool's return value as display text: a string verbatim, anything else as
  /// pretty JSON.
  static String? _format(Object? output) {
    if (output == null) return null;
    if (output is String) return output;
    return _pretty(output);
  }

  static String _pretty(Object value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } on JsonUnsupportedObjectError {
      // A tool returned something outside JSON. Showing it plainly beats
      // showing nothing, and the guard keeps a decoding quirk out of the frame.
      return value.toString();
    }
  }
}
