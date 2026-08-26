// A turn we drive by hand.
//
// Shared, because three suites need it: the controller test drives events into it
// to check the streaming split, the transcript test only needs it to put the view
// into a mid-turn state, and the sidebar test only needs the session list.

import 'dart:async';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/model/turn_source.dart';

class FakeTurnSource implements TurnSource {
  final _turns = <StreamController<TurnEvent>>[];
  var stopCalls = 0;

  /// What a scan of the store finds. Settable so a test can stock the sidebar
  /// without going near a disk.
  var sessions = const <SessionSummary>[];

  StreamController<TurnEvent> get current => _turns.last;

  void emit(TurnEvent event) => current.add(event);

  Future<void> close() => current.close();

  @override
  Stream<TurnEvent> send(String text) {
    final controller = StreamController<TurnEvent>();
    _turns.add(controller);
    return controller.stream;
  }

  @override
  Stream<TurnEvent> respondToApproval({
    required String ref,
    required bool approved,
  }) {
    final controller = StreamController<TurnEvent>();
    _turns.add(controller);
    return controller.stream;
  }

  @override
  void stop() => stopCalls++;

  @override
  void startNewSession() {}

  @override
  String? get sessionId => null;

  @override
  Future<List<ConversationNode>> openSession(String id) async => const [];

  @override
  Future<List<SessionSummary>> listSessions() async => sessions;
}
