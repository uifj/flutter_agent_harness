// The composer-takeover question form (ADR-0059).
//
// When the model's ask_user call interrupts, this takes the input card's seat
// — the same seat the approval prompt takes, same floating-capsule footprint —
// and renders the tool's questions as an answerable form. The answers ride
// back through the resume as the tool result, so submitting here is what lets
// the turn continue.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

import '../../l10n/app_localizations.dart';
import '../../model/ask_user.dart';
import '../../model/conversation.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../appearance_scope.dart';
import '../primitives/capsule_button.dart';
import '../primitives/tappable.dart';
import 'conversation_root.dart';

class AskUserPanel extends StatefulWidget {
  const AskUserPanel({
    super.key,
    required this.request,
    required this.onSubmit,
  });

  final ApprovalRequest request;

  /// The completed answer set. Fired once — the latch keeps the submit button
  /// from re-firing while the controller clears the request.
  final void Function(List<AskUserAnswer> answers) onSubmit;

  @override
  State<AskUserPanel> createState() => _AskUserPanelState();
}

class _AskUserPanelState extends State<AskUserPanel> {
  late final List<AskUserQuestion> _questions;

  /// One selection set per question — a single-choice question's set holds
  /// at most one index, a multi-choice's holds any.
  late final List<Set<int>> _selected;
  late final List<bool> _skipped;
  late final List<TextEditingController> _custom;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final raw = widget.request.details['questions'];
    _questions = [
      if (raw is List)
        for (final entry in raw) AskUserQuestion.fromJson(entry),
    ].where((question) => question.isValid).toList();
    _selected = [for (final _ in _questions) <int>{}];
    _skipped = [for (final _ in _questions) false];
    _custom = [for (final _ in _questions) TextEditingController()];
    // Typing has to re-arm the submit button: _complete reads the controllers'
    // text, and a text change notifies nothing else.
    for (final controller in _custom) {
      controller.addListener(_onCustomChanged);
    }
  }

  void _onCustomChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (var i = 0; i < _custom.length; i++) {
      _custom[i].removeListener(_onCustomChanged);
      _custom[i].dispose();
    }
    super.dispose();
  }

  /// A question counts as answered when it is skipped, or when it has a
  /// chosen option or any typed words.
  bool _answered(int index) {
    if (_skipped[index]) return true;
    return _selected[index].isNotEmpty || _custom[index].text.trim().isNotEmpty;
  }

  bool get _complete => [
    for (var i = 0; i < _questions.length; i++) _answered(i),
  ].every((answered) => answered);

  void _submit() {
    if (!_complete || _submitted) return;
    setState(() => _submitted = true);
    widget.onSubmit([
      for (var i = 0; i < _questions.length; i++)
        AskUserAnswer(
          question: _questions[i].question,
          values: [
            if (!_skipped[i])
              for (final index in _selected[i]) _questions[i].options[index],
          ],
          custom: _skipped[i] ? null : _custom[i].text.trim(),
          skipped: _skipped[i],
        ),
    ]);
  }

  /// Multi-select keeps insertion order for the payload; single-select
  /// replaces. No-op while skipped — undo the skip first.
  void _toggle(int index, int option) {
    setState(() {
      if (_skipped[index]) return;
      if (_questions[index].multi) {
        _selected[index].contains(option)
            ? _selected[index].remove(option)
            : _selected[index].add(option);
      } else {
        _selected[index] = {option};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      // Identical to the approval panel: the two takeovers swap content, not
      // geometry (ADR-0059 shares ADR-0012's seat).
      padding: const EdgeInsets.fromLTRB(
        composerSideClearance + 16,
        8,
        composerSideClearance + 16,
        12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppearanceScope.widthOf(context, chatContentWidth),
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color.inputMajor,
              // The neutral business band, not the warn stroke: nothing is at
              // risk here — the agent is waiting on a person, not permission.
              border: Border.all(color: color.borderL2),
              borderRadius: BorderRadius.circular(DswShape.float),
              boxShadow: DswShadow.lv2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [_strip(color), _body(color), _actions(color)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _strip(DswAlias color) => Container(
    color: color.stateBusinessTertiary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Icon(
          LucideIcons.circle_question_mark,
          // On the icon ramp (ADR-0026): 13 is the off-ramp middle value the
          // ramp eliminated; the caption pair here is 12.
          size: 12,
          color: color.stateBusinessPrimary,
        ),
        const SizedBox(width: 8),
        Text(
          AppLocalizations.of(context).askUserStrip,
          style: DswType.xs13.copyWith(
            // 13/18 here, not the token's 13/20: the strip is a band, not
            // prose — the same metrics the approval strip runs.
            height: 18 / 13,
            color: color.stateBusinessPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _body(DswAlias color) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: composerTextMaxHeight),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _questions.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            _question(i, color),
          ],
          const SizedBox(height: 4),
        ],
      ),
    ),
  );

  Widget _question(int index, DswAlias color) {
    final question = _questions[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                question.question,
                style: DswType.panelHeadline15.copyWith(
                  color: color.labelPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _skipChip(index, color),
          ],
        ),
        if (!_skipped[index]) ...[
          for (var o = 0; o < question.options.length; o++)
            _optionRow(index, o, color),
          if (question.options.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                AppLocalizations.of(context).askUserOther,
                style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: ShadInput(
              controller: _custom[index],
              placeholder: Text(AppLocalizations.of(context).askUserOpenHint),
            ),
          ),
        ],
      ],
    );
  }

  Widget _skipChip(int index, DswAlias color) => DswHoverTap(
    onTap: () => setState(() => _skipped[index] = !_skipped[index]),
    semanticLabel: _skipped[index]
        ? AppLocalizations.of(context).askUserSkipped
        : AppLocalizations.of(context).askUserSkip,
    builder: (context, hovered, focused) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: hovered || _skipped[index]
              ? color.interactiveBgHover
              : Colors.transparent,
          borderRadius: BorderRadius.circular(DswShape.pill),
          border: Border.all(color: color.borderL2),
        ),
        child: Text(
          _skipped[index]
              ? AppLocalizations.of(context).askUserSkipped
              : AppLocalizations.of(context).askUserSkip,
          style: DswType.xxs12.copyWith(color: color.labelSecondary),
        ),
      );
    },
  );

  Widget _optionRow(int index, int option, DswAlias color) {
    final question = _questions[index];
    final chosen = _selected[index].contains(option);
    return DswHoverTap(
      enabled: !_skipped[index],
      onTap: () => _toggle(index, option),
      semanticLabel: question.options[option],
      toggled: chosen,
      builder: (context, hovered, focused) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                chosen ? LucideIcons.circle_check_big : LucideIcons.circle,
                size: 14,
                color: chosen ? color.brandPrimary : color.labelTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.options[option],
                  style: DswType.s14.copyWith(
                    color: _skipped[index]
                        ? color.labelTertiary
                        : color.labelPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _actions(DswAlias color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        CapsuleButton(
          label: AppLocalizations.of(context).askUserSubmit,
          enabled: _complete && !_submitted,
          variant: CapsuleVariant.primary,
          onTap: _submit,
        ),
      ],
    ),
  );
}
