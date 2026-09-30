// A menu is a shad surface, and its skin is said once in the bridge.
//
// ADR-0036 decision 1: where `shadcn_ui` has the component, the app uses the
// component. Menus were the largest family of controls the four real-window
// screenshots disagreed about, and they had grown three shapes: Material's
// `PopupMenuButton`, a bare `showMenu`, and — since ADR-0028 — one
// `popupMenuTheme` whose whole job was holding Material's defaults at bay (its
// resolution order hands the theme full responsibility for the disabled branch,
// `PopupMenuItem`'s 48px seat cannot be themed at all, and its fill could not
// be told apart from the layer beneath without an override).
//
// So this file holds one structural claim: no Material menu survives in
// `lib/ui`. Value pickers are `ShadSelect`, action lists are `ShadPopover`,
// right-click is `ShadContextMenuRegion`, and all three read the one overlay
// skin `dsw_shad_bridge.dart` gives `popoverTheme`. The expected count is zero
// rather than an allow-list: `tap_affordance_test.dart` keeps a reviewed list
// because a raw detector can have a legitimate reason, and a Material menu
// cannot — it is the same component with a worse theme story.
//
// A source scan and not a widget test, because the claim is which component a
// surface is built from; the skin that overlay paints is asserted in
// `menu_chrome_test.dart`, which opens a real menu and reads it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _materialMenuIds = ['PopupMenuButton', 'PopupMenuItem', 'showMenu'];
const _shadMenuIds = ['ShadSelect', 'ShadPopover', 'ShadContextMenuRegion'];

List<File> get _uiFiles => Directory('lib/ui')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Counts identifier occurrences in `lib/ui`, skipping whole-line comments, as
/// `path -> count`.
Map<String, int> _countIn(List<String> ids) {
  final found = <String, int>{};
  for (final file in _uiFiles) {
    var count = 0;
    for (final raw in file.readAsLinesSync()) {
      final text = raw.trim();
      if (text.startsWith('//')) continue;
      for (final id in ids) {
        count += id.allMatches(text).length;
      }
    }
    if (count > 0) found[file.path.replaceAll(r'\', '/')] = count;
  }
  return found;
}

Map<String, int> materialMenus() => _countIn(_materialMenuIds);

Map<String, int> shadMenus() => _countIn(_shadMenuIds);

void main() {
  test('no Material menu is left in lib/ui', () {
    final found = materialMenus();
    expect(
      found,
      isEmpty,
      reason:
          'ADR-0036: a menu is a ShadSelect, a ShadPopover or a '
          'ShadContextMenuRegion, skinned once by dsw_shad_bridge.dart. '
          'Offenders: '
          '${found.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
    );
  });

  test('the scan is looking at a tree that has menus in it', () {
    // An empty result is only evidence if the walk saw the files. Without this,
    // a wrong working directory would pass the claim above for the wrong
    // reason — and the shad half proves the surfaces were rebuilt, not deleted.
    expect(_uiFiles.length, greaterThan(20));
    expect(shadMenus(), isNotEmpty);
  });
}
