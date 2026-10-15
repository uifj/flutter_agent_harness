// A settings control must change something the app reads.
//
// `AppSettings` carries one field per row of the settings page. A field that
// only ever gets *written* is a control that lies: the user picks Serif, Glass,
// "New window", or turns on follow-up prompts, the value lands on disk, and
// nothing in the running app behaves differently. ADR-0022 removed the four
// such fields this repo had grown (all of them inherited from ADR-0005's
// "persisted but not wired" backlog) and this file is what stops a fifth from
// appearing: it enumerates the fields from their own declarations and requires
// a read somewhere other than the model and the page that writes them.
//
// Two honest limits. The scan is by `.<name>` and cannot tell a read of
// `settings.theme` from another object's `.theme` — so the guard errs toward
// passing, which is the safe direction (it never blocks real work, it only
// catches a brand-new name nobody reads at all). And it proves a field is
// *read*, not that reading it produces a visible change: a value consumed but
// ignored by the renderer still passes. That half is still a walkthrough.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _definition = 'lib/model/app_settings.dart';
const _pageEntry = 'lib/ui/settings/model_settings.dart';

/// The settings page is one library split across part files (ADR-0085 D7), so
/// "the page that writes these fields" is the entry file *and* every file it
/// declares as a part — otherwise a write-only field could hide in a section
/// file and read as wired.
List<String> _pageLibrary() {
  final dir = _pageEntry.substring(0, _pageEntry.lastIndexOf('/') + 1);
  return [
    _pageEntry,
    for (final line in File(_pageEntry).readAsLinesSync())
      if (RegExp(r"^part '(.+)';").firstMatch(line) case final part?)
        dir + part.group(1)!,
  ];
}

void main() {
  group('a hint is a fact the user can act on', () {
    // ADR-0033. A field hint is not decoration: it names a directory someone may
    // create. Two of them were inherited from the project this one was written
    // against - `/Users/you/.dsh/skills` on a screen whose own description says
    // "application support directory", and `/Users/you/project` - so the copy
    // contradicted the screen it sat on.
    test('no copy in lib/ui names the upstream product directory', () {
      final offenders = <String>[];
      for (final file in Directory(
        'lib/ui',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final text = lines[i];
          if (!text.contains('.dsh')) continue;
          if (text.trimLeft().startsWith('//') ||
              text.trimLeft().startsWith('///')) {
            continue;
          }
          offenders.add('${file.path}: ${i + 1}');
        }
      }
      expect(offenders, isEmpty);
    });

    test('no field hint is an invented absolute path', () {
      final offenders = <String>[];
      for (final file in Directory(
        'lib/ui',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (RegExp(r"hint: '/").hasMatch(lines[i])) {
            offenders.add('${file.path}: ${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a hint that starts with / is a path someone will type into a '
            'folder picker; the real one is already known at runtime',
      );
    });
  });

  test('every field of AppSettings is read somewhere it can take effect', () {
    final fields = _settingsFields();
    // Guards against the parse silently finding nothing, which would make the
    // loop below vacuously green.
    expect(fields.length, greaterThan(8), reason: 'parsed $fields');

    final sources = _libSources(excluding: {_definition, ..._pageLibrary()});
    final unread = [
      for (final field in fields)
        if (!_readAnywhere(sources, field)) field,
    ];
    expect(
      unread,
      isEmpty,
      reason:
          'these are persisted by the settings page and never read back: '
          '$unread. Either wire the read or remove the row and the field '
          '(ADR-0022).',
    );
  });
}

/// The `final …;` declarations inside `class AppSettings`, in source order.
List<String> _settingsFields() {
  final lines = File(_definition).readAsLinesSync();
  final start = lines.indexWhere(
    (line) => line.startsWith('class AppSettings'),
  );
  expect(start, greaterThan(-1), reason: '$_definition lost its class line');
  final fields = <String>[];
  for (var i = start + 1; i < lines.length; i++) {
    if (lines[i] == '}') break;
    final field = RegExp(
      r'^\s+final\s+[\w<>, ?]+\s+(\w+);\s*$',
    ).firstMatch(lines[i]);
    if (field != null) fields.add(field.group(1)!);
  }
  return fields;
}

List<String> _libSources({required Set<String> excluding}) => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .map((file) => file.path.replaceAll(r'\', '/'))
    .where((path) => !excluding.contains(path))
    .toList();

bool _readAnywhere(List<String> sources, String field) {
  final read = RegExp(r'\.' + field + r'\b');
  return sources.any((path) => read.hasMatch(File(path).readAsStringSync()));
}
