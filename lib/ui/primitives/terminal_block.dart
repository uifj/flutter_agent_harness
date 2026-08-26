// TerminalBlock: the terminal surface for a shell command and its output, ported
// from `ui-primitives/src/TerminalBlock.tsx` and its stylesheet.
//
// Prompt line (run-state dot + shortened cwd + command), the output, the settled
// exit status, and a copy control for the raw output. Output never soft-wraps:
// column-aligned output (ls, tables, box drawing) keeps its alignment and scrolls
// horizontally instead of folding.
//
// Two divergences from the source, both named where they land below:
//   - No ANSI parsing. dsh runs output through `ansi.ts` and colours each run;
//     there is no ANSI parser in this build, so a line is drawn as text. The
//     terminator and empty-output rules are ported onto plain lines, which is
//     where the parsed-span versions of them mattered.
//   - Display copy is hardcoded English. Upstream it arrives through a `labels`
//     prop because that package is cordis-free; every real call site passes the
//     conversation dictionary, whose `en` entries are the strings below.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'block_chrome.dart';
import 'copy_button.dart';
import 'head_tail_cap.dart';
import 'pill.dart';
import 'state_dot.dart';

/// Output lines shown before the height cap collapses the middle. Matches the TUI
/// transcript's default tool-output budget so both front ends cut a long command's
/// output at the same place.
const defaultTerminalMaxLines = 16;

/// `--dsl-terminal-gutter`: the card's own left inset, holding the run-state dot
/// in a column of its own so it never competes with the commands for horizontal
/// space.
const _gutter = 30.0;

/// `--dsl-terminal-line-height`.
const _lineHeight = 22.0;

/// A multi-line command's banner scrolls at this height (`max-height: 150px`)
/// instead of pushing the output off screen.
const _bannerMaxHeight = 150.0;

class TerminalBlock extends StatefulWidget {
  const TerminalBlock({
    super.key,
    required this.command,
    this.cwd,
    this.home,
    this.output,
    this.exitCode,
    this.signal,
    this.running = false,
    this.maxLines = defaultTerminalMaxLines,
  });

  /// The command line, rendered verbatim after the prompt label.
  final String command;

  /// Working directory for the prompt label; absent renders a plain `$`.
  final String? cwd;

  /// Absolute home directory, so a cwd equal to it collapses to `~`; absent
  /// disables that collapse.
  final String? home;

  /// The command's output text.
  final String? output;

  /// Settled exit code; a non-zero value renders the status pill.
  final int? exitCode;

  /// Settled terminating signal name; any value renders the status pill, taking
  /// precedence over the exit code.
  final String? signal;

  /// The command is still running: the block shows the prompt line alone.
  final bool running;

  final int maxLines;

  @override
  State<TerminalBlock> createState() => _TerminalBlockState();
}

/// Prompt label for a working directory: `~` for the home directory itself,
/// otherwise the path's last segment (both separators accepted, trailing
/// separators ignored), falling back to the path itself when it has no segment.
String promptLabel(String cwd, String? home) {
  final trimmed = cwd.replaceAll(RegExp(r'[/\\]+$'), '');
  if (home != null && trimmed == home.replaceAll(RegExp(r'[/\\]+$'), '')) {
    return '~';
  }
  final segments = trimmed.split(RegExp(r'[/\\]'));
  final segment = segments.isEmpty ? '' : segments.last;
  return segment.isEmpty ? cwd : segment;
}

/// Status pill text for a settled command, or null when the command settled
/// cleanly (exit 0, no signal) and needs no pill — the same distinction the bash
/// tool's own exit-status markers draw.
String? statusText(int? exitCode, String? signal) {
  if (signal != null) return 'signal $signal';
  if (exitCode != null && exitCode != 0) return 'exit code $exitCode';
  return null;
}

/// Run-state indicator for the command, shown at the head of the prompt line so
/// the card states whether the command is still running without the reader having
/// to infer it from the presence of output.
///
/// Three of [StateDotState]'s four states are reachable: the running chase (the
/// same indicator a running tool row's leading icon uses, so the row and its card
/// never disagree), green for a clean settle, red for a signal or a non-zero exit
/// — the same status distinction [statusText] draws for the pill. A settled
/// command whose exit status never reached the view counts as a clean settle: the
/// view says it finished and says nothing went wrong.
({StateDotState state, String label}) runState(
  bool running,
  int? exitCode,
  String? signal,
) {
  if (running) return (state: StateDotState.ongoing, label: 'Running');
  if (statusText(exitCode, signal) != null) {
    return (state: StateDotState.error, label: 'Failed');
  }
  return (state: StateDotState.done, label: 'Done');
}

/// The command's output split into the lines the card draws.
///
/// A command's output ends with a newline; that terminator is not an extra blank
/// line to draw or to count against the height cap. A genuinely blank final line —
/// the double newline — survives, since it has a real empty line before the
/// terminator. dsh runs this check on the ANSI-parsed lines rather than the raw
/// text, because a reset after the final newline (`line\n\x1b[0m`) leaves the
/// string not ending in one while still producing a last line with nothing visible
/// in it; with no parser here, the check is on the split lines, which catches the
/// plain form of the same case.
List<String> outputLines(String text) {
  final lines = text.split('\n');
  return lines.length > 1 && lines.last.isEmpty
      ? lines.sublist(0, lines.length - 1)
      : lines;
}

class _TerminalBlockState extends State<TerminalBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final text = widget.output ?? '';
    final lines = outputLines(text);
    // Judged on the lines the card renders, not on the raw text: output that is
    // only whitespace would otherwise draw a box of blank rows plus a copy control
    // for nothing, and hide the placeholder that belongs there.
    final empty = lines.every((line) => line.trim().isEmpty);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.markdownCodeBlock,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _banner(color, text: text, empty: empty),
          if (!widget.running)
            if (empty) _empty(color) else _output(color, lines),
        ],
      ),
    );
  }

  Widget _banner(
    DswAlias color, {
    required String text,
    required bool empty,
  }) {
    final status = statusText(widget.exitCode, widget.signal);
    final state = runState(widget.running, widget.exitCode, widget.signal);
    // A multi-line command gets one prompt row per line, so a two-command shell
    // snippet reads as the two commands it is instead of collapsing into one
    // ellipsized row. A trailing newline is a terminator, not an empty command.
    final command = widget.command.endsWith('\n')
        ? widget.command.substring(0, widget.command.length - 1)
        : widget.command;
    final commandLines = command.split('\n');

    return Container(
      padding: const EdgeInsets.only(right: 14, top: 9, bottom: 9),
      decoration: BoxDecoration(
        // The section boundary between banner and body. A running card is
        // banner-only, so it draws none.
        border: widget.running
            ? null
            : Border(bottom: BorderSide(color: color.borderL2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The gutter is a reserved column rather than an absolutely positioned
          // dot, so nothing a consumer does to margins can pull the reservation
          // and the dot apart. The dot is aria-hidden upstream and carries a
          // visually hidden text label; here that label is the semantics of this
          // column.
          Semantics(
            label: state.label,
            child: SizedBox(
              width: _gutter,
              height: _lineHeight,
              child: Align(
                // `left: calc(-1 * gutter + 8px)` — 8 from the card's own edge.
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  // One dot for the card, on the first row: the exit status the
                  // view carries is the whole call's, and bash reports no
                  // per-command status, so a dot per row would assert a per-line
                  // outcome nothing here knows.
                  child: StateDot(state: state.state),
                ),
              ),
            ),
          ),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _bannerMaxHeight),
              // The source scrolls the whole banner and keeps the pill and the
              // copy control sticky inside it; here only the prompt column
              // scrolls, which puts those two in the same place without a sticky
              // layer. The dot stays with the first row's position rather than
              // scrolling with the first command, which is the one thing this
              // arrangement gives up.
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var index = 0; index < commandLines.length; index++)
                      _promptLine(color, commandLines[index], first: index == 0),
                  ],
                ),
              ),
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 12),
            Pill(
              label: status,
              height: _lineHeight,
              color: color.stateErrorPrimary,
            ),
          ],
          if (!widget.running && !empty) ...[
            const SizedBox(width: 12),
            // The raw output, never the rendered tree: the prompt line and the
            // status pill are chrome the user did not run.
            CopyButton(
              text: text,
              idleColor: color.labelSecondary,
              hoverColor: color.labelPrimary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _promptLine(DswAlias color, String line, {required bool first}) {
    final cwd = widget.cwd;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The cwd labels the CALL, so only its first row carries it. The view
        // knows one working directory — where the call started — and a later line
        // may well run somewhere else (a `cd` in the command is enough), so
        // repeating the label down the rows would assert a directory per line that
        // nothing here knows. Later rows keep a bare `$` to stay aligned.
        Text(
          !first || cwd == null ? '\$' : promptLabel(cwd, widget.home),
          style: DswType.markdownCodeBlock.copyWith(
            color: color.labelTertiary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            line,
            // `white-space: pre`, so the repeated spaces and tabs of an indented
            // continuation survive; the row holds one line and ellipsizes.
            softWrap: false,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.markdownCodeBlock.copyWith(
              color: color.labelPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _empty(DswAlias color) => Padding(
    padding: const EdgeInsets.only(left: _gutter, right: 14, top: 12, bottom: 12),
    child: Text(
      'No output',
      style: DswType.markdownCodeBlock.copyWith(color: color.labelTertiary),
    ),
  );

  Widget _output(DswAlias color, List<String> lines) {
    final cap = headTailCap(lines.length, widget.maxLines, _expanded);
    final shown = cap.capped ? lines.head(cap.headLines) : lines;
    return Padding(
      padding: const EdgeInsets.only(
        left: _gutter,
        right: 14,
        top: 12,
        bottom: 12,
      ),
      child: BlockScroller(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in shown) _line(color, line),
            if (cap.hidden > 0)
              BlockExpandToggle(
                expanded: _expanded,
                hidden: cap.hidden,
                onToggle: () => setState(() => _expanded = !_expanded),
                textStyle: DswType.markdownCodeBlock,
                expandSemantics:
                    'Expand the remaining ${cap.hidden} output lines',
                collapseSemantics: 'Collapse output',
              ),
            if (cap.capped)
              for (final line in lines.tail(cap.tailLines)) _line(color, line),
          ],
        ),
      ),
    );
  }

  /// `.line`: no wrapping, because alignment is the payload of terminal output.
  Widget _line(DswAlias color, String line) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      line,
      softWrap: false,
      style: DswType.markdownCodeBlock.copyWith(color: color.labelPrimary),
    ),
  );
}
