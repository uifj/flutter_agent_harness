// A git runner that answers from a map, or fails, recording every call.
//
// Shared by git_test.dart (command shapes, where an unstubbed command is noise
// and answers '') and git_tab_test.dart (panel wiring, where an unstubbed
// command is a bug worth failing on — hence [unknownResponse]'s strict default).

import 'package:agent_harness/host/git.dart';
import 'package:agent_harness/state/git_status_store.dart';

/// The command key `git status` answers under.
const fakeStatusKey = 'status --porcelain=v1 -z --untracked-files=all';

/// The command key `git log` answers under, for page [skip] at batch [count].
String fakeLogKey({int count = 20, int skip = 0}) =>
    'log -n $count --skip $skip --decorate=short '
    '--pretty=format:%h\x1f%s\x1f%an\x1f%ai\x1f%H\x1f%D';

class FakeGit {
  FakeGit({this.unknownResponse});

  /// What a command with no stub answers, or null to make it a wiring error.
  final String? unknownResponse;

  final calls = <(String, List<String>)>[];
  final responses = <String, String>{};

  /// A cache that answers "not a repository" without spawning anything.
  ///
  /// Anything pumped through a [Workbench] needs one: the real runner arms a 30s
  /// process-timeout timer inside the test's fake-async zone, and a pending timer
  /// fails the test for a reason that has nothing to do with what it was checking.
  static GitStatusStore inert() =>
      GitStatusStore(runner: (cwd, args) async => '');

  /// Command keys that fail, with stderr `boom: <key>`.
  final failures = <String>{};

  /// One healthy repository: a staged edit, an unstaged edit, an untracked
  /// file, two branches, one decorated history row.
  void stubRepo({String root = '/fake/repo'}) {
    responses['rev-parse --show-toplevel'] = '$root\n';
    responses['rev-parse --abbrev-ref HEAD'] = 'main\n';
    responses[fakeStatusKey] =
        'M  staged.txt\x00 M unstaged.txt\x00?? new.txt\x00';
    responses['for-each-ref --format=%(refname:short) refs/heads'] =
        'main\ndev\n';
    responses[fakeLogKey()] =
        'abc1234\x1fsubject line\x1fauthor\x1f2024-01-01 10:00:00 +0800'
        '\x1ffullhash123\x1fHEAD -> main';
  }

  /// Every command key sent so far, args joined — what most assertions read.
  Iterable<String> get commands => calls.map((call) => call.$2.join(' '));

  GitRunner get runner => (cwd, args) async {
    calls.add((cwd, args));
    final key = args.join(' ');
    if (failures.contains(key)) {
      throw GitCommandError('boom: $key', key);
    }
    final stdout = responses[key] ?? unknownResponse;
    if (stdout == null) {
      throw StateError('no fake response for: $key');
    }
    return stdout;
  };
}
