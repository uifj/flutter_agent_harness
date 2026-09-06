// The registry and the three name-and-bytes decisions around it.
//
// These are pure functions with no widget in sight, and they are the ones that
// decide whether a file opens in an editor, in an image view, or not at all —
// the kind of judgement that rots quietly when a new extension shows up. The
// viewer choice is asserted from both directions: what must be text and what
// must not, because the failure that matters is a binary reaching the text
// editor and laying out a megabyte of one line.

import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/ui/workbench/tab_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registry', () {
    setUp(tabRegistry.clear);
    tearDown(tabRegistry.clear);

    TabDescriptor descriptor(TabType type, {IconData? icon, int order = 100}) =>
        TabDescriptor(
          type: type,
          icon: icon ?? LucideIcons.circle,
          order: order,
          build: (context, workbench, tab) => const SizedBox.shrink(),
        );

    test('an unregistered type has no descriptor', () {
      expect(descriptorFor('nothing-like-this'), isNull);
    });

    test('registration is keyed by type', () {
      registerTab(descriptor(BuiltinTabType.editor, icon: LucideIcons.anchor));
      expect(descriptorFor(BuiltinTabType.editor)?.icon, LucideIcons.anchor);
      expect(descriptorFor(BuiltinTabType.git), isNull);
    });

    // A later stage replaces the placeholder terminal and git bodies with the
    // real ones. That has to be a replacement rather than a second entry, or the
    // pane would keep drawing whichever registration ran first.
    test('re-registering a type replaces it', () {
      registerTab(descriptor(BuiltinTabType.terminal, icon: LucideIcons.aperture));
      registerTab(descriptor(BuiltinTabType.terminal, icon: LucideIcons.anchor));
      expect(tabRegistry.length, 1);
      expect(descriptorFor(BuiltinTabType.terminal)?.icon, LucideIcons.anchor);
    });

    test('order sorts openable types', () {
      registerTab(descriptor(BuiltinTabType.git, order: 40));
      registerTab(descriptor(BuiltinTabType.explorer, order: 10));
      final sorted = tabRegistry.values.toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      expect(sorted.map((d) => d.type), [
        BuiltinTabType.explorer,
        BuiltinTabType.git,
      ]);
    });
  });

  group('matchFileViewer', () {
    test('source and unknown extensions are text', () {
      for (final path in [
        '/w/lib/main.dart',
        '/w/pubspec.yaml',
        '/w/README',
        '/w/notes.txt',
        '/w/.gitignore',
        '/w/Makefile',
        '/w/weird.qqq',
      ]) {
        expect(matchFileViewer(path), FileViewer.text, reason: path);
      }
    });

    test('decodable images get the image viewer', () {
      for (final path in ['/w/a.png', '/w/a.JPG', '/w/a.jpeg', '/w/a.webp']) {
        expect(matchFileViewer(path), FileViewer.image, reason: path);
      }
    });

    // `.ico` and `.icns` are files a person would call images, and Flutter
    // decodes neither. They belong with the binaries, not with a viewer that
    // would show a decode error where a picture should be.
    test('undecodable images are unsupported, not image', () {
      expect(matchFileViewer('/w/favicon.ico'), FileViewer.unsupported);
      expect(matchFileViewer('/w/app.icns'), FileViewer.unsupported);
    });

    test('known binaries are unsupported', () {
      for (final path in [
        '/w/doc.pdf',
        '/w/bundle.zip',
        '/w/lib.dylib',
        '/w/module.wasm',
        '/w/font.woff2',
        '/w/clip.mp4',
        '/w/index.sqlite',
      ]) {
        expect(matchFileViewer(path), FileViewer.unsupported, reason: path);
      }
    });

    test('the extension is read case-insensitively', () {
      expect(matchFileViewer('/w/DOC.PDF'), FileViewer.unsupported);
    });

    // A dotted directory name must not make the file inside it look binary.
    test('only the last segment decides', () {
      expect(matchFileViewer('/w/.zip/main.dart'), FileViewer.text);
    });
  });

  group('readsAsText', () {
    test('plain bytes are text', () {
      expect(readsAsText('hello\nworld\n'.codeUnits), isTrue);
    });

    test('empty is text', () {
      expect(readsAsText(const []), isTrue);
    });

    test('a NUL in the sample is not', () {
      expect(readsAsText([104, 105, 0, 106]), isFalse);
    });

    // The sample is bounded, so opening a large file does not scan all of it; a
    // NUL past the bound is deliberately not looked for. Pinning both sides of
    // the bound keeps it from being quietly widened into a full read.
    test('the sample stops at 8000 bytes', () {
      final beyond = List<int>.filled(9000, 65)..[8500] = 0;
      expect(readsAsText(beyond), isTrue);
      final within = List<int>.filled(9000, 65)..[7999] = 0;
      expect(readsAsText(within), isFalse);
    });
  });

  group('highlightLanguage', () {
    test('extensions map to re_highlight keys', () {
      expect(highlightLanguage('/w/lib/main.dart'), 'dart');
      expect(highlightLanguage('/w/src/App.tsx'), 'typescript');
      expect(highlightLanguage('/w/src/app.mjs'), 'javascript');
      expect(highlightLanguage('/w/package.json'), 'json');
      expect(highlightLanguage('/w/pubspec.yaml'), 'yaml');
      expect(highlightLanguage('/w/README.md'), 'markdown');
      expect(highlightLanguage('/w/run.sh'), 'bash');
      expect(highlightLanguage('/w/tool.py'), 'python');
      expect(highlightLanguage('/w/main.rs'), 'rust');
      expect(highlightLanguage('/w/Info.plist'), 'xml');
      expect(highlightLanguage('/w/site.css'), 'css');
    });

    test('extensionless names are matched whole', () {
      expect(highlightLanguage('/w/Dockerfile'), 'dockerfile');
      expect(highlightLanguage('/w/Makefile'), 'makefile');
      expect(highlightLanguage('/w/.gitignore'), 'bash');
    });

    // Guessing is worse than not highlighting: wrong highlighting reads as a
    // syntax error that is not in the file.
    test('an unknown name highlights nothing', () {
      expect(highlightLanguage('/w/notes.txt'), isNull);
      expect(highlightLanguage('/w/LICENSE'), isNull);
      expect(highlightLanguage('/w/weird.qqq'), isNull);
    });

    test('a directory named like a language does not decide', () {
      expect(highlightLanguage('/w/dart/notes.txt'), isNull);
    });
  });
}
