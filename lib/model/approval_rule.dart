// What the user has already decided, so the next identical call does not ask.
//
// The approval loop this serves asks per call: `ask` mode interrupts on every
// `write`, `edit`, `bash` and external MCP tool (`tools.dart`, and the middleware
// in `agent_runtime.dart`), which is the "approve until you stop reading"
// complaint the porting evaluation records against this app (ADR-0012). A rule
// is the answer to that: the verdict the user gave once, kept for the same
// subject again.
//
// Pure Dart, like the rest of `lib/model/` — the runtime's gate and the settings
// list both read this, and neither may pull the other's dependencies in.
//
// Two decisions worth the reading:
//   * **deny always beats allow.** Adding an allow must never quietly撤销 a deny
//     the user wrote earlier, so the scan does not stop at the first match.
//   * **wildcards go at the end and nowhere else.** `git *` means "a command
//     that starts with git ", which is what a person means when they type it.
//     `* install` would mean "anything containing install" — including
//     `curl x | sh; rm -rf / --install-log`, and that is the one shape of rule
//     that turns an approval system into a rubber stamp. A pattern with a star
//     anywhere but the end is treated as a literal, so the safe reading is the
//     only one that ever happens.

/// What a rule is about.
enum ApprovalSubjectKind {
  /// A shell command, as the model wrote it (`git status`).
  command,

  /// A workspace file, as the approval panel showed it (relative to the root).
  filePath,

  /// A tool by name — an external `server/tool`, or a local tool.
  tool,
}

/// What the rule says to do when it matches.
enum ApprovalOutcome { allow, deny }

/// One saved decision.
class ApprovalRule {
  const ApprovalRule({
    required this.kind,
    required this.value,
    required this.outcome,
  });

  final ApprovalSubjectKind kind;

  /// The subject, or a prefix of it when [endsWithWildcard] is true.
  final String value;
  final ApprovalOutcome outcome;

  bool get endsWithWildcard => value.endsWith('*');

  /// Whether this rule speaks for a call on [subject].
  bool matches(ApprovalSubjectKind candidateKind, String subject) {
    if (candidateKind != kind) return false;
    if (!endsWithWildcard) return subject == value;
    return subject.startsWith(value.substring(0, value.length - 1));
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'value': value,
    'outcome': outcome.name,
  };

  factory ApprovalRule.fromJson(Map<String, dynamic> json) {
    // An unknown kind is refused rather than guessed at: a rule that silently
    // became a `tool` rule would match a different namespace than the one the
    // user approved. The store skips what this throws on.
    final kindName = json['kind'];
    final value = json['value'];
    if (kindName is! String || value is! String || value.isEmpty) {
      throw FormatException('malformed approval rule: $json');
    }
    return ApprovalRule(
      kind: ApprovalSubjectKind.values.byName(kindName),
      value: value,
      outcome: json['outcome'] == 'deny'
          ? ApprovalOutcome.deny
          : ApprovalOutcome.allow,
    );
  }

  /// What the settings list shows: the kind, then the subject.
  String get display => switch (kind) {
    ApprovalSubjectKind.command => '\$ $value',
    ApprovalSubjectKind.filePath => '# $value',
    ApprovalSubjectKind.tool => '@ $value',
  };

  @override
  bool operator ==(Object other) =>
      other is ApprovalRule &&
      other.kind == kind &&
      other.value == value &&
      other.outcome == outcome;

  @override
  int get hashCode => Object.hash(kind, value, outcome);

  @override
  String toString() => '${outcome.name} $display';
}

/// The rules in force for the folder the user has open, and the one question
/// the gate asks them.
class ApprovalRuleBook {
  ApprovalRuleBook({List<ApprovalRule> rules = const []}) : _rules = [...rules];

  final List<ApprovalRule> _rules;

  List<ApprovalRule> get rules => List.unmodifiable(_rules);

  /// The verdict for a call, or null when nothing speaks for it and the user
  /// has to be asked. Deny wins, and the scan does not stop early to find out.
  ApprovalOutcome? decide(ApprovalSubjectKind kind, String subject) {
    ApprovalOutcome? decided;
    for (final rule in _rules) {
      if (!rule.matches(kind, subject)) continue;
      if (rule.outcome == ApprovalOutcome.deny) return ApprovalOutcome.deny;
      decided = ApprovalOutcome.allow;
    }
    return decided;
  }

  /// Records [rule], replacing any saved decision about the same subject. Two
  /// rules for one command would be a second source of truth about what the
  /// user meant.
  void add(ApprovalRule rule) {
    _rules.removeWhere(
      (existing) => existing.kind == rule.kind && existing.value == rule.value,
    );
    _rules.add(rule);
  }

  void remove(ApprovalRule rule) => _rules.remove(rule);

  /// Points the book at another folder: the saved rules are per workspace, so
  /// opening a different one replaces the loaded set rather than adding to it.
  void load(List<ApprovalRule> loaded) {
    _rules
      ..clear()
      ..addAll(loaded);
  }

  @override
  String toString() => 'ApprovalRuleBook(${_rules.length})';
}
