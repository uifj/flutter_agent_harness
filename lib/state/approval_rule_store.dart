// The saved approval decisions, one document per workspace.
//
// `<support>/approvals.json`: `{ "<workspace root>": [ {kind, value, outcome} ] }`.
//
// Two shape decisions, both load-bearing:
//   * **Keyed by workspace, not global.** A decision made while working in one
//     repo is not a decision about another one, and "always allow `rm -rf *`"
//     given once in a scratch folder must not become the answer everywhere.
//   * **App-level, not project-level.** The porting reference (ZCode) persists
//     rules beside the project. That needs a write into the user's workspace,
//     which on this app means the security-scoped bookmark path (macOS only —
//     `build.md` §2B), and it would let a cloned repository ship its own
//     "approve everything" file. ADR-0012 records the deviation.
//   * **Opened by `AppScope`, not `main`.** Synchronous, small, and not on the
//     runtime-restart channel — the same reasoning that keeps `WorkbenchStore`
//     inside the composition root rather than in the bootstrap list.
//
// One document, one file, one writer, atomic write: the `PrefsStore` shape.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/approval_rule.dart';

/// Owns the live [ApprovalRuleBook] and the file the persisted half lives in.
class ApprovalRuleStore extends ChangeNotifier {
  ApprovalRuleStore._(this._file, this._byWorkspace);

  static const _fileName = 'approvals.json';

  /// Reads the saved decisions out of [root]. A document that cannot be parsed
  /// is treated as absent — the call `SettingsStore` makes too, because a
  /// corrupt approvals file must not brick the app and must not be
  /// half-trusted.
  static ApprovalRuleStore open(Directory root) {
    final file = File('${root.path}/$_fileName');
    final byWorkspace = <String, List<ApprovalRule>>{};
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final rules = entry.value;
            if (rules is! List) continue;
            final parsed = <ApprovalRule>[];
            for (final rule in rules) {
              if (rule is! Map) continue;
              try {
                parsed.add(ApprovalRule.fromJson(rule.cast<String, dynamic>()));
              } on FormatException {
                // One malformed row drops; the rest of the file still counts.
              } on ArgumentError {
                // An unknown subject kind drops too: guessing its namespace
                // would approve something the user never saw.
              }
            }
            byWorkspace[entry.key] = parsed;
          }
        }
      }
    } on FileSystemException {
      // Unreadable: start from nothing.
    } on FormatException {
      // Not JSON: same.
    }
    return ApprovalRuleStore._(file, byWorkspace);
  }

  final File _file;
  final Map<String, List<ApprovalRule>> _byWorkspace;
  final ApprovalRuleBook _book = ApprovalRuleBook();
  String _key = '';

  /// The rules the runtime's gate consults. One book for the app's lifetime:
  /// `AppScope` hands the same object to every runtime it builds, so replacing
  /// a runtime on a settings save cannot silently drop a decision the user made.
  ApprovalRuleBook get book => _book;

  /// The saved rules for the folder currently open.
  List<ApprovalRule> get saved => savedFor(_key);

  /// The saved rules for [workspaceRoot], whether or not it is the open one.
  List<ApprovalRule> savedFor(String? workspaceRoot) =>
      List.unmodifiable(_byWorkspace[_keyOf(workspaceRoot)] ?? const []);

  /// Points the live book at [workspaceRoot]'s saved decisions.
  ///
  /// Replaces rather than merges: opening a different folder is not a reason to
  /// inherit another folder's approvals.
  void useWorkspace(String? workspaceRoot) {
    _key = _keyOf(workspaceRoot);
    _book.load(_byWorkspace[_key] ?? const []);
    notifyListeners();
  }

  /// Records a decision for good: the same call will not interrupt again in
  /// this folder, across restarts, until the user revokes it.
  Future<void> remember(ApprovalRule rule) async {
    _book.add(rule);
    _byWorkspace[_key] = _book.rules;
    await _write();
    notifyListeners();
  }

  /// Drops [rule] from the book and from the file.
  Future<void> forget(ApprovalRule rule) async {
    _book.remove(rule);
    _byWorkspace[_key] = _book.rules;
    await _write();
    notifyListeners();
  }

  /// Forgets every saved decision belonging to [workspaceRoot] — the "this
  /// folder is done with" reset, and the only bulk undo available.
  Future<void> forgetWorkspace(String? workspaceRoot) async {
    _byWorkspace.remove(_keyOf(workspaceRoot));
    if (_key == _keyOf(workspaceRoot)) _book.load(const []);
    await _write();
    notifyListeners();
  }

  String _keyOf(String? workspaceRoot) => workspaceRoot ?? '';

  Future<void> _write() async {
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(
      jsonEncode({
        for (final entry in _byWorkspace.entries)
          if (entry.value.isNotEmpty)
            entry.key: [for (final rule in entry.value) rule.toJson()],
      }),
      flush: true,
    );
    await temp.rename(_file.path);
  }
}
