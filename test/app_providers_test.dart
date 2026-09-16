// Guards the read-seam providers (ADR-0002 stage 3a).
//
// The bug this catches: the first version wired these seams with
// `ref.notifyListeners()`, which on a *functional* provider re-notifies the
// cached value WITHOUT re-running the body — so a store save never reached
// readers and theme/language/workspace switches silently did nothing. Caught
// only on a running app (widget tests build controllers directly, and no test
// asserted store->provider propagation), which is exactly why this file exists:
// it drives a real store and asserts the provider reflects it.

import 'dart:io';

import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/state/app_providers.dart';
import 'package:agent_harness/state/prefs_store.dart';
import 'package:agent_harness/state/settings_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late SettingsStore settings;
  late PrefsStore prefs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dsh_providers');
    settings = await SettingsStore.open(dir);
    prefs = await PrefsStore.open(dir);
  });

  tearDown(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [
      supportDirectoryProvider.overrideWithValue(dir),
      settingsStoreProvider.overrideWithValue(settings),
      prefsStoreProvider.overrideWithValue(prefs),
    ],
  );

  test('settingsDocument reflects a store save (theme)', () async {
    final c = container();
    addTearDown(c.dispose);
    final before = c.read(settingsDocumentProvider);
    await settings.save(before.copyWith(theme: ThemeMode.dark));
    expect(
      c.read(settingsDocumentProvider).theme,
      ThemeMode.dark,
      reason:
          'the read seam must re-run on a store change, not re-notify stale',
    );
  });

  test('settingsDocument reflects a store save (locale)', () async {
    final c = container();
    addTearDown(c.dispose);
    final before = c.read(settingsDocumentProvider);
    await settings.save(before.copyWith(locale: LocaleMode.zh));
    expect(c.read(settingsDocumentProvider).locale, LocaleMode.zh);
  });

  test('workbenchPrefs reflects a store save', () async {
    final c = container();
    addTearDown(c.dispose);
    final before = c.read(workbenchPrefsProvider);
    await prefs.save(
      before.copyWith(bottomPanelAutoTerminal: !before.bottomPanelAutoTerminal),
    );
    expect(
      c.read(workbenchPrefsProvider).bottomPanelAutoTerminal,
      !before.bottomPanelAutoTerminal,
    );
  });
}
