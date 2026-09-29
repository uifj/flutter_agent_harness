// A turn we drive by hand.
//
// Shared, because three suites need it: the controller test drives events into it
// to check the streaming split, the transcript test only needs it to put the view
// into a mid-turn state, and the sidebar test only needs the session list.

import 'dart:async';

import 'package:agent_harness/model/approval_mode.dart';
import 'package:agent_harness/model/attached_image.dart';
import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/queued_input.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/model/turn_source.dart';

class FakeTurnSource implements TurnSource {
  final _turns = <StreamController<TurnEvent>>[];
  var stopCalls = 0;
  ApprovalMode? lastApprovalMode;

  /// Whether a turn is open for steering. A test sets it; the real runtime
  /// derives the same answer from its own turn bookkeeping.
  var runOpen = false;

  /// Guides that were accepted, oldest first — what the runtime's middleware
  /// would have read at its next model call.
  final handedGuides = <QueuedInput>[];

  /// Guides the run never reached. A real turn leaves one behind when it ends
  /// without another model call, so closing a turn moves them here; a test can
  /// also stock the list directly.
  final undeliveredGuides = <QueuedInput>[];

  /// What each started turn carried, in order.
  final sentTexts = <String>[];

  /// How many turns were started — one `send` per entry.
  int get turns => _turns.length;

  /// What a scan of the store finds. Settable so a test can stock the sidebar
  /// without going near a disk.
  var sessions = const <SessionSummary>[];

  StreamController<TurnEvent> get current => _turns.last;

  void emit(TurnEvent event) => current.add(event);

  Future<void> close() {
    runOpen = false;
    _strandGuides();
    return current.close();
  }

  /// The model call never came, so nothing read them.
  void _strandGuides() {
    undeliveredGuides.addAll(handedGuides);
    handedGuides.clear();
  }

  @override
  Stream<TurnEvent> send(String text, {List<AttachedImage> images = const []}) {
    final controller = StreamController<TurnEvent>();
    _turns.add(controller);
    sentTexts.add(text);
    runOpen = true;
    return controller.stream;
  }

  @override
  bool guide(QueuedInput input) {
    if (!runOpen) return false;
    handedGuides.add(input);
    return true;
  }

  @override
  List<QueuedInput> takeUndeliveredGuides() {
    final taken = List<QueuedInput>.of(undeliveredGuides);
    undeliveredGuides.clear();
    return taken;
  }

  @override
  set approvalMode(ApprovalMode mode) => lastApprovalMode = mode;

  @override
  Stream<TurnEvent> respondToApproval({
    required String ref,
    required bool approved,
  }) {
    final controller = StreamController<TurnEvent>();
    _turns.add(controller);
    runOpen = true;
    return controller.stream;
  }

  @override
  void stop() {
    stopCalls++;
    runOpen = false;
    _strandGuides();
  }

  @override
  void startNewSession() {
    runOpen = false;
    undeliveredGuides.clear();
  }

  @override
  String? get sessionId => null;

  @override
  Future<List<ConversationNode>> openSession(String id) async => const [];

  @override
  Future<List<SessionSummary>> listSessions() async => sessions;
}
