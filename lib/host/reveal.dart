// Showing a file, or a folder, in the operating system's own file browser.
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

import 'package:path/path.dart' as p;

/// Reveals [path] in Finder / Explorer / the default file manager.
///
/// [path] may be a directory, which opens, or a file, which is selected inside
/// its folder — the file case is what the tree and the git panel hand over.
Future<bool> revealInFileManager(String path) async {
  if (path.isEmpty) return false;
  final isDirectory = await Directory(path).exists();
  if (!isDirectory && !await File(path).exists()) return false;
  final command = switch (true) {
    _ when Platform.isMacOS => 'open',
    _ when Platform.isWindows => 'explorer',
    _ => 'xdg-open',
  };
  final List<String> arguments;
  if (isDirectory) {
    arguments = [path];
  } else if (Platform.isMacOS) {
    arguments = ['-R', path];
  } else if (Platform.isWindows) {
    arguments = ['/select,$path'];
  } else {
    // No `xdg-open` implementation takes a "select this file" argument, so the
    // folder opens and the file is not highlighted. Named rather than hidden:
    // it is the one thing the three platforms do not agree on.
    arguments = [p.dirname(path)];
  }
  try {
    final result = await Process.run(command, arguments);
    // `explorer` exits non-zero even when it opened the folder, so its status
    // is not evidence either way; the others are.
    return Platform.isWindows || result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
