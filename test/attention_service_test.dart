// ADR-0045 PH: the attention service raises the hidden window on the
// busy→idle edge, gated by the notifications toggle — and never touches the
// window when the toggle is off or the window is already visible.

import 'dart:io';

import 'package:agent_harness/state/attention_service.dart';
import 'package:agent_harness/state/settings_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

/// A [WindowManager] fake: the visibility answer is a field, the raises are
/// counted. No platform channel involved.
class _FakeWindowManager implements WindowManager {
  _FakeWindowManager({this.visible = false});

  bool visible;
  int showCount = 0;
  int focusCount = 0;

  @override
  Future<bool> isVisible() async => visible;

  @override
  Future<void> show({bool inactive = false}) async {
    showCount++;
    visible = true;
  }

  @override
  Future<void> focus() async {
    focusCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The conversation surface the service reads: a [Listenable] whose `isBusy`
/// the test flips. No runtime needed.
class _FakeConversation extends ChangeNotifier {
  bool _busy = false;
  bool get isBusy => _busy;

  void setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

Future<SettingsStore> _storeWith({required bool notificationsOn}) async {
  final root = await Directory.systemTemp.createTemp('attention_test');
  addTearDown(() => root.delete(recursive: true));
  final store = await SettingsStore.open(root);
  await store.save(store.value.copyWith(notificationsOn: notificationsOn));
  return store;
}

AttentionService _service(
  _FakeConversation conversation,
  _FakeWindowManager window,
  SettingsStore settings,
) => AttentionService(
  conversation: conversation,
  isBusy: () => conversation.isBusy,
  settings: settings,
  window: window,
);

void main() {
  test('raises the hidden window on the busy-to-idle edge', () async {
    final conversation = _FakeConversation();
    final window = _FakeWindowManager(visible: false);
    final settings = await _storeWith(notificationsOn: true);
    final service = _service(conversation, window, settings);
    addTearDown(service.dispose);

    conversation.setBusy(true); // the run starts
    expect(window.showCount, 0);
    conversation.setBusy(false); // the run finishes — hidden, so raise
    await Future<void>.delayed(Duration.zero);
    expect(window.showCount, 1);
    expect(window.focusCount, 1);
  });

  test('a visible window is never raised', () async {
    final conversation = _FakeConversation();
    final window = _FakeWindowManager(visible: true);
    final settings = await _storeWith(notificationsOn: true);
    final service = _service(conversation, window, settings);
    addTearDown(service.dispose);

    conversation.setBusy(true);
    conversation.setBusy(false);
    await Future<void>.delayed(Duration.zero);
    expect(window.showCount, 0);
  });

  test('the toggle off silences the raise without unbinding', () async {
    final conversation = _FakeConversation();
    final window = _FakeWindowManager(visible: false);
    final store = await _storeWith(notificationsOn: true);
    final service = _service(conversation, window, store);
    addTearDown(service.dispose);

    conversation.setBusy(true);
    // The toggle flips mid-run: the next edge honors it.
    await store.save(store.value.copyWith(notificationsOn: false));
    conversation.setBusy(false);
    await Future<void>.delayed(Duration.zero);
    expect(window.showCount, 0);
    expect(service.notificationsOn, isFalse);
  });

  test('stream frames between busy edges never raise', () async {
    final conversation = _FakeConversation();
    final window = _FakeWindowManager(visible: false);
    final settings = await _storeWith(notificationsOn: true);
    final service = _service(conversation, window, settings);
    addTearDown(service.dispose);

    conversation.setBusy(true);
    for (var i = 0; i < 5; i++) {
      conversation.setBusy(true); // notify churn while running
      await Future<void>.delayed(Duration.zero);
    }
    expect(window.showCount, 0);
  });
}
