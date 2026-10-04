// Workspace environment variables (ADR-0064): the name rules, the loader
// seam, and the output redaction. Pure Dart — the store persists, the tools
// inject, and neither imports the other.

/// A valid environment variable name — what a process environment key must
/// look like to be injectable at all.
bool isValidEnvironmentName(String name) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name);

/// Values shorter than this are stored but NOT redactable: a 3-character
/// string matches too much of any output to replace without destroying it
/// (kelivo's own bound).
const redactableMinimumLength = 5;

/// The seam the tools call to fetch the live variable map at execution time.
/// Async because the values live in the keychain. Empty map = no variables,
/// and the tool behaves exactly as before.
typedef EnvironmentLoader = Future<Map<String, String>> Function();

/// Replaces every occurrence of every [secrets] value in [text] with
/// `[REDACTED]`, longest first so overlapping values cannot unmask each
/// other. Values below [redactableMinimumLength] are skipped — the user was
/// told they are not protectable. Applied ONLY to text heading back to the
/// model: the tool card and the details panel read the same redacted string,
/// so a plaintext value can never reach the transcript through a render.
String redactToolOutput(String text, Iterable<String> secrets) {
  var redacted = text;
  final values = [
    for (final value in secrets)
      if (value.length >= redactableMinimumLength) value,
  ]..sort((a, b) => b.length.compareTo(a.length));
  for (final value in values) {
    redacted = redacted.replaceAll(value, '[REDACTED]');
  }
  return redacted;
}
