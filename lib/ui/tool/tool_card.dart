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

import '../../l10n/locales.dart';
import '../../model/conversation.dart';
import '../../state/checkpoint_store.dart';
import '../../state/details_selection.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../primitives/confirm_dialog.dart';
import '../primitives/feedback.dart';
import '../primitives/tappable.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/disclosure_row.dart';
import '../appearance_scope.dart';
import '../primitives/row_sweep.dart';
import '../primitives/state_dot.dart';
import 'checkpoint_scope.dart';

class ToolCard extends StatefulWidget {
  const ToolCard({super.key, required this.node});

  final ToolCallNode node;

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  /// Expand state is view-local, as in the source: it is about this reader's
  /// attention, not about the call. Its *starting* value, though, is the
  /// appearance preference (ADR-0005) — a newly-shown call opens to match how
  /// the user likes tool blocks presented, then the reader is free to fold it.
  bool _expanded = false;

  /// Whether the preference has already been consulted. Collapsed is the value
  /// before the first frame, so the guard is what keeps "only on mount" true even
  /// though `didChangeDependencies` runs again whenever the scope changes.
  bool _preferenceRead = false;

  /// `.root:hover`, which is what reveals the Inspect pill — the whole call,
  /// title row included, not just the body the pill sits under.
  bool _hovered = false;

  /// The starting expansion comes from an ancestor, so it is read here rather
  /// than in `initState`: establishing an inherited dependency while the state
  /// is still locked is an assertion Flutter raises on the spot, and a tool card
  /// is mounted under `AppearanceScope` in every conversation the app has.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preferenceRead) return;
    _preferenceRead = true;
    // One read per mount: a later preference change must not yank a card the
    // reader already toggled. No scope (tests) → collapsed, the pre-ADR default.
    _expanded = AppearanceScope.expandToolCallsOf(context);
  }

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
    _ => Icon(model.icon, size: DswShape.iconSm, color: color.labelTertiary),
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
          borderRadius: BorderRadius.circular(DswShape.pill),
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

  /// `.bodyWrap`: the IN/OUT card (figma 1249:35657) with the pills under
  /// it. A sibling of the header row rather than part of it, which is what keeps
  /// a click in here from toggling the row.
  ///
  /// The second pill is this build's own, not dsh's (ADR-0014): a `write` or
  /// `edit` that left a checkpoint can offer to go back through it. Only those
  /// two tools can, because only those two are intercepted as file mutations.
  Widget? _body(DswAlias color, _ToolRowModel model) {
    if (!model.expandable) return null;
    final selection = DetailsSelectionScope.maybeOf(context);
    final checkpoint = model.checkpointId;
    final rewindable =
        checkpoint != null && CheckpointScope.maybeOf(context) != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ioCard(color, model),
        // No scope, no pill: a transcript mounted without one has nowhere to
        // send the selection, and a dead affordance is worse than none.
        if (selection != null)
          _QuietPill(
            revealed: _hovered,
            // dsh's `IconInspectOutline12` is the `</>` glyph: two chevrons
            // around a slash.
            icon: LucideIcons.code,
            label: 'Inspect',
            onTap: () =>
                selection.select(callId: widget.node.id, toolName: model.title),
          ),
        if (rewindable)
          _QuietPill(
            revealed: _hovered,
            icon: LucideIcons.undo_2,
            label: context.tr('rewindPill'),
            onTap: () => _rewind(checkpoint),
          ),
      ],
    );
  }

  /// Preview, confirm, go, report.
  ///
  /// The preview comes first because the confirmation has to be honest about the
  /// files it cannot touch: a rewind whose every file was edited outside the
  /// agent is worth declining, and the user should learn that before their files
  /// change rather than after.
  Future<void> _rewind(String checkpointId) async {
    final service = CheckpointScope.maybeOf(context);
    if (service == null) return;
    final files = service.preview(checkpointId);
    if (files.isEmpty) {
      _report(context.tr('rewindNothing'));
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('rewindTitle'),
      description: _describe(
        restored: [
          for (final file in files)
            if (!file.blocked && !file.deletes) file.path,
        ],
        deleted: [
          for (final file in files)
            if (!file.blocked && file.deletes) file.path,
        ],
        skipped: [
          for (final file in files)
            if (file.blocked) '${file.path} · ${_reason(file.blockedBy!)}',
        ],
      ),
      confirmLabel: context.tr('rewindConfirm'),
    );
    if (!confirmed || !mounted) return;
    final report = service.rewind(checkpointId);
    if (report.didNothing) {
      _report(context.tr('rewindNothing'));
      return;
    }
    _report(
      _describe(
        restored: report.restored,
        deleted: report.deleted,
        skipped: [for (final skip in report.skipped) skip.path],
      ),
    );
  }

  /// One line per group, in the order the rewind acts on them. The same builder
  /// writes the confirmation and the report after it, so the two cannot tell
  /// different stories about one rewind.
  String _describe({
    required List<String> restored,
    required List<String> deleted,
    required List<String> skipped,
  }) => [
    for (final group in <(String, List<String>)>[
      (context.tr('rewindRestores'), restored),
      (context.tr('rewindDeletes'), deleted),
      (context.tr('rewindSkips'), skipped),
    ])
      if (group.$2.isNotEmpty) '${group.$1} ${_names(group.$2)}',
  ].join('\n');

  /// A long list caps itself rather than pushing the dialog off the screen; the
  /// count of what is not shown stays visible so the truncation is not silent.
  String _names(List<String> names) => names.length <= _rewindListCap
      ? names.join(', ')
      : '${names.take(_rewindListCap).join(', ')} +${names.length - _rewindListCap}';

  String _reason(RewindSkipReason reason) => switch (reason) {
    RewindSkipReason.changedOutsideAgent => context.tr('rewindWhyChanged'),
    RewindSkipReason.imageUnavailable => context.tr('rewindWhyNoImage'),
  };

  void _report(String message) => showFeedback(context, message);

  Widget _ioCard(DswAlias color, _ToolRowModel model) {
    final input = model.input;
    final output = model.output;
    return Container(
      margin: const EdgeInsets.fromLTRB(4, 4, 0, 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(color: color.borderL1),
        borderRadius: BorderRadius.circular(DswShape.shell),
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
// Quiet pills
// -----------------------------------------------------------------------------

/// How many names one rewind line spells out before it counts the rest.
const _rewindListCap = 6;

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
/// and the seat dsh's own `openDetails` was cut for. The rewind pill is the same
/// chrome with a different promise, which is why the label and glyph are
/// parameters rather than a second copy of this widget.
class _QuietPill extends StatelessWidget {
  const _QuietPill({
    required this.revealed,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool revealed;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      // `margin: 4px 0 2px 4px`.
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 2),
      child: AnimatedOpacity(
        opacity: revealed ? 1 : 0,
        duration: DswMotion.respecting(context, DswMotion.fast),
        curve: DswMotion.easeInOut,
        child: DswHoverTap(
          onTap: onTap,
          semanticLabel: label,
          excludeSemantics: true,
          builder: (context, hovered, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              // Base, not the overlay token: the overlay is a raised surface
              // and reads too heavy for a quiet in-flow affordance.
              color: hovered ? color.interactiveBgHoverSolid : color.bgBase,
              border: Border.all(color: color.borderL2),
              borderRadius: BorderRadius.circular(DswShape.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: DswShape.iconTiny,
                  color: hovered ? color.labelPrimary : color.labelSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: DswType.xxxs11.copyWith(
                    height: 16 / 11,
                    color: hovered ? color.labelPrimary : color.labelSecondary,
                  ),
                ),
              ],
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
    required this.checkpointId,
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

  /// The checkpoint this call recorded, or null when there is nothing to go back
  /// to (ADR-0014). Only the two file-mutating tools are intercepted, so an
  /// output that merely carries a `checkpoint` key from another tool — an MCP
  /// server's, say — offers no pill rather than a promise the store cannot keep.
  final String? checkpointId;

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
      input: node.arguments.isEmpty ? null : _render(node.arguments),
      output: output == null || output.isEmpty ? null : output,
      outputIsError: node.errorMessage != null,
      state: state,
      checkpointId: variant == _RowVariant.write || variant == _RowVariant.edit
          ? _checkpointOf(node.output)
          : null,
    );
  }

  /// The id the write/edit tool put in its own output, if it put one there.
  static String? _checkpointOf(Object? output) {
    if (output is! Map) return null;
    final id = output['checkpoint'];
    return id is String && id.isNotEmpty ? id : null;
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
    if (base.isEmpty) base = _firstLine(_render(args));
    if (_titles.containsKey(node.name)) return base;
    return '${node.name} · $base';
  }

  static String _firstLine(String text) {
    final newline = text.indexOf('\n');
    return newline == -1 ? text : text.substring(0, newline);
  }

  /// A tool's return value as display text.
  ///
  /// Not the way the model receives it: `JsonEncoder` escapes the newlines
  /// inside a string value, so a 30-line `ls -la` arrived on screen as one
  /// unscannable paragraph with literal `\n` in it (ADR-0031, from a real
  /// window screenshot). Structure is kept — one key per line, so `path` and
  /// `totalLines` stay readable — while a text payload is printed raw and
  /// indented under its key. A result that is already a plain string is shown
  /// as it is.
  static String? _format(Object? output) {
    if (output == null) return null;
    if (output is String) {
      final decoded = _tryDecode(output);
      return decoded == null ? output : _render(decoded);
    }
    return _render(output);
  }

  /// Only a string that *looks* like a JSON document is tried; a tool that
  /// answers with prose starting in a brace is shown as that prose.
  static Object? _tryDecode(String value) {
    final text = value.trimLeft();
    if (!text.startsWith('{') && !text.startsWith('[')) return null;
    try {
      return jsonDecode(value);
    } on FormatException {
      return null;
    }
  }

  static String _render(Object? value, {String at = ''}) {
    if (value is Map) {
      if (value.isEmpty) return '$at{}';
      return value.entries
          .map((e) {
            final v = e.value;
            if (v is String && v.contains('\n')) {
              return '$at${e.key}:\n${_block(v, '$at  ')}';
            }
            if (v is Map || v is List) {
              return '$at${e.key}:\n${_render(v, at: '$at  ')}';
            }
            return '$at${e.key}: ${v is String ? v : _scalar(v)}';
          })
          .join('\n');
    }
    if (value is List) {
      if (value.isEmpty) return '$at[]';
      return value.map((e) => '$at- ${_render(e, at: '').trim()}').join('\n');
    }
    return '$at${_scalar(value)}';
  }

  static String _block(String text, String at) =>
      text.split('\n').map((line) => '$at$line').join('\n');

  static String _scalar(Object? value) =>
      value == null ? 'null' : value.toString();
}
