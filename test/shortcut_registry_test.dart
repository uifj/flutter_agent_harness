// ADR-0045 PC: the shortcut registry is the single definition — the hotkey
// service, the tray and the settings table all read it. The registry test
// pins the law: every command parseable, ids unique, scopes declared.

import 'package:planstar/model/shortcut_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ids are unique and every command has a label and default binding', () {
    final ids = ShortcutRegistry.commands.map((c) => c.id).toSet();
    expect(ids.length, ShortcutRegistry.commands.length);
    for (final command in ShortcutRegistry.commands) {
      expect(command.labelKey, isNotEmpty);
      expect(command.defaultSpec, isNotEmpty);
      expect(command.binding.key, isNotEmpty);
    }
  });

  test('the hotkey service can parse every default binding', () {
    // The parser in HotKeyService switches on these exact tokens; a registry
    // entry the parser cannot read would silently not bind.
    const parseable = {'H', 'N', 'Comma', 'B'};
    for (final command in ShortcutRegistry.commands) {
      expect(
        parseable.contains(command.binding.key),
        isTrue,
        reason: '${command.id} binds ${command.binding.key}',
      );
    }
  });

  test('the parsed modifiers map onto the key-event modifiers', () {
    final toggleWindow = ShortcutRegistry.byId('toggleWindow')!;
    expect(toggleWindow.binding.modifiers, ['CmdOrCtrl', 'Shift']);
    expect(
      _modifiersOf(toggleWindow.binding),
      containsAll([LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.shiftLeft]),
    );
  });

  test('toggleWindow is the only system-scope command', () {
    expect(
      [
        for (final c in ShortcutRegistry.commands)
          if (c.system) c.id,
      ],
      ['toggleWindow'],
    );
  });

  test('accelerator spelling follows the platform', () {
    expect(
      ShortcutRegistry.acceleratorFor('CmdOrCtrl+Shift+H', isMacOS: true),
      '\u2318Shift+H',
    );
    expect(
      ShortcutRegistry.acceleratorFor('CmdOrCtrl+Shift+H', isMacOS: false),
      'Ctrl+Shift+H',
    );
  });
}

List<LogicalKeyboardKey> _modifiersOf(ShortcutBinding binding) {
  final modifiers = <LogicalKeyboardKey>[];
  for (final modifier in binding.modifiers) {
    switch (modifier) {
      case 'CmdOrCtrl':
        modifiers.add(LogicalKeyboardKey.metaLeft);
      case 'Shift':
        modifiers.add(LogicalKeyboardKey.shiftLeft);
    }
  }
  return modifiers;
}
