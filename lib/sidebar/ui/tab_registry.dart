// Which widget a tab type draws, and which viewer a file path deserves.
//
// A narrowed projection of `DSH-better-sidebar/src/client/service.ts:161-232`.
// The source's `TabDescriptor` carries twelve fields; this one carries four,
// because the rest were solved elsewhere or solve problems this app does not
// have:
//
//   * `single` / `dedupeKey` — the id conventions in [SidebarTab]'s factories
//     already make a repeat open a focus. A registry that also knows about
//     dedupe is a second answer to the same question.
//   * `available` / `hidden` — the source hides tab types per host capability
//     (no repo, no pty). Here a type that cannot work says so in its own body,
//     where it can explain why instead of vanishing.
//   * `settings` / `badge` / `urlTarget` — no consumer.
//
// The registry stays keyed by [TabType] strings so a new tab type is one entry
// here and nothing else, which is the one property of the source worth keeping.

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../model/sidebar_tab.dart';
import '../state/workbench_controller.dart';

/// Builds a tab's content.
///
/// The controller is a parameter rather than something the body looks up.
/// An `InheritedNotifier` would be the idiomatic reach, but it rebuilds every
/// dependent on every notification — and a notification here means "some pane
/// somewhere changed", which for a terminal or an editor is exactly the rebuild
/// worth avoiding.
typedef TabBodyBuilder =
    Widget Function(
      BuildContext context,
      WorkbenchController workbench,
      SidebarTab tab,
    );

/// How one tab type presents itself.
class TabDescriptor {
  const TabDescriptor({
    required this.type,
    required this.icon,
    required this.build,
    this.order = 100,
  });

  final TabType type;

  /// The glyph shown in the tab strip. dsh ships its own icon set; as elsewhere
  /// in this port the nearest Material glyph stands in rather than inventing
  /// artwork.
  final IconData icon;

  final TabBodyBuilder build;

  /// Sort key for any menu that lists openable types. Lower comes first.
  final int order;
}

/// The tab types this build knows how to draw.
///
/// Registration is a mutable map rather than a const one so a later stage can
/// replace an entry without this file having to import the widget: the terminal
/// and git tabs land in stages five and four, and until then the placeholder
/// bodies below say so.
final tabRegistry = <TabType, TabDescriptor>{};

/// Installs [descriptor], replacing any entry for the same type.
void registerTab(TabDescriptor descriptor) {
  tabRegistry[descriptor.type] = descriptor;
}

TabDescriptor? descriptorFor(TabType type) => tabRegistry[type];

/// What kind of viewer a path wants.
enum FileViewer {
  /// A text editor.
  text,

  /// An image, decoded by Flutter.
  image,

  /// Neither: a binary this app has nothing useful to show for.
  ///
  /// Worth its own case rather than falling back to the text editor, which would
  /// try to lay out a few megabytes of one line and hang the frame.
  unsupported,
}

/// Extensions Flutter's own decoders handle. Anything outside this list is not
/// an image as far as this app is concerned, whatever the file really is.
const _imageExtensions = {
  '.png',
  '.jpg',
  '.jpeg',
  '.gif',
  '.webp',
  '.bmp',
};

/// Extensions that are certainly not text. Not exhaustive — it cannot be — which
/// is why [readsAsText] exists to check content as well.
const _binaryExtensions = {
  '.pdf',
  '.zip',
  '.gz',
  '.tar',
  '.bz2',
  '.xz',
  '.7z',
  '.rar',
  '.jar',
  '.class',
  '.so',
  '.dylib',
  '.dll',
  '.exe',
  '.o',
  '.a',
  '.wasm',
  '.woff',
  '.woff2',
  '.ttf',
  '.otf',
  '.eot',
  '.ico',
  '.icns',
  '.mp3',
  '.mp4',
  '.mov',
  '.avi',
  '.mkv',
  '.wav',
  '.flac',
  '.ogg',
  '.webm',
  '.db',
  '.sqlite',
  '.pyc',
  '.bin',
  '.dat',
};

/// The viewer [path] should open in, decided from its name alone.
///
/// Pure and synchronous on purpose: the tab strip and the editor body both need
/// this answer, and a future would make one of them show a spinner over a
/// decision that never involves the disk.
FileViewer matchFileViewer(String path) {
  final ext = p.extension(path).toLowerCase();
  if (_imageExtensions.contains(ext)) return FileViewer.image;
  if (_binaryExtensions.contains(ext)) return FileViewer.unsupported;
  return FileViewer.text;
}

/// Whether [bytes] look like text.
///
/// A NUL byte in the first few KB is the heuristic `file(1)` and git both use,
/// and it is the one that matters here: extensions are a guess, and a `.log` that
/// is actually a core dump would otherwise reach the text editor.
bool readsAsText(List<int> bytes) {
  final limit = bytes.length < 8000 ? bytes.length : 8000;
  for (var i = 0; i < limit; i++) {
    if (bytes[i] == 0) return false;
  }
  return true;
}

/// re_highlight's language key for [path], or null to highlight nothing.
///
/// Keyed by extension and then by whole file name, since `Dockerfile` and
/// `Makefile` have no extension to key on. Returning null rather than falling
/// back to a plausible language is deliberate: wrong highlighting reads as a
/// syntax error that is not there.
String? highlightLanguage(String path) {
  final name = p.basename(path);
  final ext = p.extension(name).toLowerCase();
  final byExtension = switch (ext) {
    '.dart' => 'dart',
    '.ts' || '.tsx' || '.mts' || '.cts' => 'typescript',
    '.js' || '.jsx' || '.mjs' || '.cjs' => 'javascript',
    '.json' || '.jsonc' => 'json',
    '.yaml' || '.yml' => 'yaml',
    '.md' || '.markdown' => 'markdown',
    '.sh' || '.bash' || '.zsh' => 'bash',
    '.py' || '.pyi' => 'python',
    '.rs' => 'rust',
    '.html' || '.htm' || '.xml' || '.plist' || '.svg' => 'xml',
    '.css' => 'css',
    _ => null,
  };
  if (byExtension != null) return byExtension;
  return switch (name) {
    'Dockerfile' => 'dockerfile',
    'Makefile' || 'makefile' => 'makefile',
    '.gitignore' || '.gitattributes' || '.dockerignore' => 'bash',
    _ => null,
  };
}
