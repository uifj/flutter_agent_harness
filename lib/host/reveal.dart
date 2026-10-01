// Showing a folder in the operating system's own file browser.
//
// `lib/ui` may not import `dart:io` (architecture rule 5), so the surface asks
// for this instead of running the process itself. One function, three
// platforms: the desktop targets this app ships are macOS, Windows and Linux,
// and each already has a "open this here" command — no dependency needed.
//
// Returns whether the command was started, not whether the browser came to the
// foreground: nothing here can observe that, and claiming otherwise would be a
// second truth about a thing the app cannot see.

import 'dart:io';

/// Reveals [path] in Finder / Explorer / the default file manager.
Future<bool> revealInFileManager(String path) async {
  if (path.isEmpty || !await Directory(path).exists()) return false;
  final command = switch (true) {
    _ when Platform.isMacOS => 'open',
    _ when Platform.isWindows => 'explorer',
    _ => 'xdg-open',
  };
  try {
    final result = await Process.run(command, [path]);
    // `explorer` exits non-zero even when it opened the folder, so its status
    // is not evidence either way; the others are.
    return Platform.isWindows || result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
