// The attention service (ADR-0045 PH): when a turn finishes and the window
// is hidden (the tray's hide path), bring the window back — the desktop
// answer to "the run I started in the background is done". The General
// section's notification toggle gates it, which is what keeps the setting
// off ADR-0022's write-only list: the toggle has a real consumer.
//
// The conversation surface is taken as [Listenable] + a busy reader so tests
// can drive the edge without a runtime; [AppScope] passes its
// ConversationController and reads `isBusy` for it.
//
// System notification banners (firing even when the window has focus) need
// a plugin dependency and are NOT part of this service — registered in the
// ADR as a later batch.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_store.dart';

class AttentionService extends ChangeNotifier {
  AttentionService({
    required Listenable conversation,
    required bool Function() isBusy,
    required SettingsStore settings,
    WindowManager? window,
  }) : _conversation = conversation,
       _isBusy = isBusy,
       _settings = settings,
       _window = window {
    _conversation.addListener(_onConversationChanged);
  }

  final Listenable _conversation;
  final bool Function() _isBusy;
  final SettingsStore _settings;
  final WindowManager? _window;

  /// Busy at the previous notification — the raise fires on the busy→idle
  /// edge only, never on every stream frame in between.
  bool _wasBusy = false;

  /// The setting, read live — the toggle takes effect immediately.
  bool get notificationsOn => _settings.value.notificationsOn;

  void _onConversationChanged() {
    final busy = _isBusy();
    final finished = _wasBusy && !busy;
    _wasBusy = busy;
    if (!finished) return;
    unawaited(_raiseIfHidden());
  }

  Future<void> _raiseIfHidden() async {
    if (!notificationsOn) return;
    final window = _window;
    if (window == null) return;
    if (await window.isVisible()) return;
    await window.show();
    await window.focus();
    notifyListeners();
  }

  @override
  void dispose() {
    _conversation.removeListener(_onConversationChanged);
    super.dispose();
  }
}
