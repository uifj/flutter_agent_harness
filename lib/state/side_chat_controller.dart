// The side chat: one lightweight conversation beside the main one.
//
// A port of the better-sidebar Side Chat tab, narrowed to this app's single
// runtime. The source's side threads are child sessions with their own
// persistence; this app's `SideChatSource` is deliberately one-shot — an aside
// is a question about the work, not work of its own — so the controller holds
// the exchange in memory and nothing survives a restart.
//
// Talks to the runner through [SideTurnSource], never Genkit, for the same
// reason the transcript does: the state layer compiles without the runtime.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/turn_event.dart';
import '../model/turn_source.dart';

/// One side-chat bubble: the user's aside or the agent's answer.
class SideChatMessage {
  const SideChatMessage({required this.isUser, required this.text});

  /// True for the user's line, false for the agent's.
  final bool isUser;

  final String text;
}

class SideChatController extends ChangeNotifier {
  final List<SideChatMessage> _messages = [];
  StreamSubscription<TurnEvent>? _subscription;

  /// The runner, or null when no runtime has been adopted yet. A null source
  /// makes [send] fail loudly rather than silently dropping the aside.
  SideTurnSource? _source;

  /// True while an aside is being answered.
  bool _busy = false;

  /// The exchange, oldest first.
  List<SideChatMessage> get messages => List.unmodifiable(_messages);

  bool get busy => _busy;

  /// Whether a runner has been adopted. The tab's empty state says something
  /// different when this is false: there is no model to talk to yet.
  bool get ready => _source != null;

  /// Swaps in the runner a rebuilt runtime brings. The in-flight exchange, if
  /// any, is abandoned: it belonged to the runtime being replaced, and a turn
  /// that cannot be resumed is not a transcript worth keeping half of.
  void adoptSource(SideTurnSource? source) {
    if (identical(source, _source)) return;
    _subscription?.cancel();
    _subscription = null;
    _source = source;
    _busy = false;
    notifyListeners();
  }

  /// Sends [text] as the next aside.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;
    final source = _source;
    if (source == null) {
      _messages.add(const SideChatMessage(isUser: false, text: 'no source'));
      notifyListeners();
      return;
    }

    _messages.add(SideChatMessage(isUser: true, text: trimmed));
    _busy = true;
    notifyListeners();

    var answer = '';
    _subscription = source.send(trimmed).listen(
      (event) {
        switch (event) {
          case TextDelta(:final text):
            answer += text;
            _updateAnswer(answer);
          case TurnFinished(outcome: TurnOutcome.failed, :final errorMessage):
            _busy = false;
            _messages.add(
              SideChatMessage(isUser: false, text: errorMessage ?? 'failed'),
            );
            notifyListeners();
          case TurnFinished():
            _busy = false;
            notifyListeners();
          case _:
            break;
        }
      },
      onError: (Object error) {
        _busy = false;
        _messages.add(SideChatMessage(isUser: false, text: '$error'));
        notifyListeners();
      },
    );
    try {
      await _subscription?.asFuture<void>();
    } catch (_) {
      // The error already surfaced through onError; this only stops it
      // escaping the send the UI never awaited.
    }
    _subscription = null;
  }

  /// Rewrites the live answer bubble in place rather than appending, so a
  /// streaming reply is one bubble that grows, the way the main transcript's
  /// tail behaves.
  void _updateAnswer(String text) {
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      _messages[_messages.length - 1] = SideChatMessage(
        isUser: false,
        text: text,
      );
    } else {
      _messages.add(SideChatMessage(isUser: false, text: text));
    }
    notifyListeners();
  }

  /// Drops the exchange and the thread's context — a fresh aside starts a
  /// fresh context, as the source's own "new side chat" does.
  void reset() {
    _subscription?.cancel();
    _subscription = null;
    _source?.reset();
    _messages.clear();
    _busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
