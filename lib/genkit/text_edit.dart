// The edit tool's rule: replace literal text, and refuse when the target is
// ambiguous.
//
// A port of the occurrence contract `tool-fs/src/edit.ts` states in its own
// prompt section: "It replaces literal old_string with new_string; by default
// old_string must appear exactly once. If old_string appears multiple times,
// provide a more specific old_string or set replace_all to true."
//
// Literal, not regex, and that is the whole point of the tool existing beside
// `write`: the model does not have to reproduce a file it has already read, and
// the failure mode of getting the surrounding text slightly wrong is a refusal
// rather than a mangled file.

/// Why an edit was refused.
///
/// A refusal is not a failure of the tool: every case here is something the model
/// can fix on its next call, which is why the message says what to do rather than
/// only what went wrong.
class EditRejected implements Exception {
  EditRejected(this.message);

  final String message;

  @override
  String toString() => 'EditRejected: $message';
}

/// A successful edit's result.
class EditOutcome {
  const EditOutcome({required this.content, required this.replacements});

  final String content;

  /// How many occurrences were replaced. Always 1 unless `replace_all` was set,
  /// which is what makes it worth reporting: the model asked for all of them
  /// without knowing how many that was.
  final int replacements;
}

/// Replaces [oldString] with [newString] in [source].
///
/// The four refusals are ordered by what the model most likely got wrong, so the
/// first message it sees is the actionable one.
EditOutcome applyLiteralEdit({
  required String source,
  required String oldString,
  required String newString,
  bool replaceAll = false,
}) {
  if (oldString.isEmpty) {
    throw EditRejected(
      'old_string is empty. Use the write tool to create or replace a whole '
      'file.',
    );
  }
  if (oldString == newString) {
    throw EditRejected(
      'old_string and new_string are identical, so this edit would change '
      'nothing.',
    );
  }

  final occurrences = countOccurrences(source, oldString);
  if (occurrences == 0) {
    throw EditRejected(
      'old_string was not found in the file. Read the file and copy the exact '
      'text, including indentation.',
    );
  }
  if (occurrences > 1 && !replaceAll) {
    throw EditRejected(
      'old_string appears $occurrences times. Include more surrounding text to '
      'make it unique, or set replace_all to true.',
    );
  }

  return EditOutcome(
    content: replaceAll
        ? source.replaceAll(oldString, newString)
        : source.replaceFirst(oldString, newString),
    replacements: replaceAll ? occurrences : 1,
  );
}

/// Non-overlapping occurrences of [needle] in [source].
///
/// Non-overlapping is what `replaceAll` does, so counting any other way would
/// report a number the replacement then contradicts.
int countOccurrences(String source, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var at = source.indexOf(needle);
  while (at != -1) {
    count++;
    at = source.indexOf(needle, at + needle.length);
  }
  return count;
}
