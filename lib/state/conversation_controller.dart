// The transcript, and the turn that is building it.
//
// This is the low-frequency half of the streaming split: it notifies only when
// the *shape* of the transcript changes — a node appears, a tool card changes
// status, a turn ends. Token deltas go to [StreamingTail] instead and never reach
// a listener here, which is what keeps a streaming answer from rebuilding the
// whole list on every token.
//
// It consumes `Stream<TurnEvent>` and knows nothing about Genkit; the projection
// from Genkit's chunk stream happens in `lib/genkit/agent_runtime.dart`.

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../model/conversation.dart';
import '../model/turn_event.dart';
import '../model/turn_source.dart';
import 'streaming_tail.dart';

class ConversationController extends ChangeNotifier {
  ConversationController({
    required TurnSource runtime,
    required StreamingTail tail,
    this.onSessionPersisted,
  }) : _runtime = runtime,
       _tail = tail;

  TurnSource _runtime;
  final StreamingTail _tail;

  /// Called with the session id once a turn has been persisted, so the session
  /// list can pick up a conversation that did not exist before.
  final void Function(String sessionId)? onSessionPersisted;

  final List<ConversationNode> _nodes = [];
  final Map<String, String> _toolNodeIds = {};
  StreamSubscription<TurnEvent>? _subscription;
  ApprovalRequest? _pendingApproval;
  bool _isBusy = false;
  int _nextId = 0;

  /// The message index the tail is currently attached to; see [TextDelta].
  int? _streamingIndex;

  List<ConversationNode> get nodes => UnmodifiableListView(_nodes);

  /// True while a turn is streaming. False again the moment [stop] is called —
  /// the UI does not wait for the runtime to confirm.
  bool get isBusy => _isBusy;

  /// Set while a tool is waiting for permission. The turn is paused, not over.
  ApprovalRequest? get pendingApproval => _pendingApproval;

  /// True when the composer should refuse input: mid-turn, or blocked on a
  /// decision.
  bool get isInputBlocked => _isBusy || _pendingApproval != null;

  String? get sessionId => _runtime.sessionId;

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  Future<void> send(String text) async {
    if (isInputBlocked) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _nodes.add(UserMessageNode(id: _newId(), text: trimmed));
    _isBusy = true;
    notifyListeners();

    await _consume(_runtime.send(trimmed));
  }

  /// Answers the pending approval and lets the paused turn continue.
  Future<void> respondToApproval(bool approved) async {
    final request = _pendingApproval;
    if (request == null || _isBusy) return;

    _pendingApproval = null;
    // Marked before the round trip so the card stops looking like a question the
    // moment the button is pressed. A decline also settles here: the tool will
    // report the refusal as a failure, and [_settleTool] keeps `denied` rather
    // than overwriting it with the less precise status.
    _updateTool(
      request.ref,
      (node) => node.copyWith(
        status: approved ? ToolStatus.running : ToolStatus.denied,
        clearApproval: true,
      ),
    );
    _isBusy = true;
    notifyListeners();

    await _consume(
      _runtime.respondToApproval(ref: request.ref, approved: approved),
    );
  }

  /// Stops the running turn.
  ///
  /// Goes quiet immediately rather than waiting for the runtime's own
  /// `TurnFinished`: the spike established that an in-flight request cannot
  /// actually be interrupted, so anything that still arrives is discarded.
  void stop() {
    if (!_isBusy) return;
    _runtime.stop();
    _freezeTail();
    _isBusy = false;
    notifyListeners();
  }

  /// Starts a fresh conversation. The old one stays on disk.
  void startNewSession() {
    stop();
    _runtime.startNewSession();
    _reset();
    notifyListeners();
  }

  /// Loads a persisted conversation into the transcript.
  ///
  /// A tool call that was awaiting approval when the session was persisted comes
  /// back as `running` and cannot be resumed — the runtime's pending interrupts
  /// do not survive a restart.
  Future<void> openSession(String id) async {
    stop();
    final restored = await _runtime.openSession(id);
    _reset();
    _nodes.addAll(restored);
    notifyListeners();
  }

  /// Swaps in a runtime rebuilt for new model settings, dropping the current
  /// conversation. Disposing the old runtime is the caller's job.
  void adoptRuntime(TurnSource next) {
    stop();
    _runtime = next;
    _reset();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Turn consumption
  // ---------------------------------------------------------------------------

  Future<void> _consume(Stream<TurnEvent> events) {
    final done = Completer<void>();
    void settle() {
      _subscription = null;
      if (!done.isCompleted) done.complete();
    }

    _subscription = events.listen(
      _handle,
      onError: (Object error) {
        _fail(error.toString());
        settle();
      },
      onDone: settle,
      cancelOnError: true,
    );
    return done.future;
  }

  void _handle(TurnEvent event) {
    switch (event) {
      case TextDelta(:final text, :final messageIndex):
        _openAssistantNode(messageIndex);
        // Deliberately no notifyListeners: this is the hot path.
        _tail.appendText(text);

      case ReasoningDelta(:final text, :final messageIndex):
        _openAssistantNode(messageIndex);
        _tail.appendReasoning(text);

      case ToolCallRequested(:final ref, :final name, :final arguments):
        // A tool call closes whatever the model was saying: the next text delta
        // belongs to a new message.
        _freezeTail();
        final id = _newId();
        _toolNodeIds[ref] = id;
        _nodes.add(
          ToolCallNode(
            id: id,
            name: name,
            arguments: arguments,
            status: ToolStatus.running,
            startedAt: DateTime.now(),
          ),
        );
        notifyListeners();

      case ToolCallSucceeded(:final ref, :final output):
        _updateTool(
          ref,
          (node) => node.copyWith(
            status: ToolStatus.succeeded,
            output: output,
            clearApproval: true,
          ),
        );

      case ToolCallFailed(:final ref, :final message):
        _updateTool(
          ref,
          (node) => node.copyWith(
            // A declined call reports back as a failure; the decline is the more
            // useful thing to show, so it wins.
            status: node.status == ToolStatus.denied
                ? ToolStatus.denied
                : ToolStatus.failed,
            errorMessage: message,
            clearApproval: true,
          ),
        );

      case ApprovalRequired(:final request):
        _freezeTail();
        _pendingApproval = request;
        _updateTool(
          request.ref,
          (node) => node.copyWith(
            status: ToolStatus.awaitingApproval,
            approval: request,
          ),
        );

      case TurnFinished(:final outcome, :final sessionId, :final errorMessage):
        _freezeTail();
        _isBusy = false;
        if (outcome == TurnOutcome.failed) {
          _nodes.add(
            ErrorNode(
              id: _newId(),
              message: errorMessage ?? 'The turn failed.',
            ),
          );
        }
        notifyListeners();
        if (sessionId != null) onSessionPersisted?.call(sessionId);
    }
  }

  /// Points the tail at an assistant node for [messageIndex], creating one if the
  /// model has moved on to a new message.
  void _openAssistantNode(int messageIndex) {
    if (_tail.nodeId != null && _streamingIndex == messageIndex) return;

    _freezeTail();
    final id = _newId();
    _streamingIndex = messageIndex;
    _nodes.add(AssistantMessageNode(id: id, text: '', isStreaming: true));
    _tail.begin(id);
    notifyListeners();
  }

  /// Writes the tail's contents onto its node and detaches it.
  ///
  /// Does not notify: every caller either notifies for its own reasons or is
  /// about to.
  void _freezeTail() {
    final nodeId = _tail.nodeId;
    if (nodeId == null) return;

    final frozen = _tail.finish();
    _streamingIndex = null;

    final index = _nodes.indexWhere((node) => node.id == nodeId);
    if (index < 0) return;

    if (frozen.text.isEmpty && frozen.reasoning.isEmpty) {
      // The node was opened by a delta that turned out to be empty, or the model
      // went straight to a tool call. An empty bubble is worse than none.
      _nodes.removeAt(index);
      return;
    }
    _nodes[index] = (_nodes[index] as AssistantMessageNode).copyWith(
      text: frozen.text,
      reasoning: frozen.reasoning,
      isStreaming: false,
    );
  }

  void _updateTool(String ref, ToolCallNode Function(ToolCallNode) update) {
    final id = _toolNodeIds[ref];
    if (id == null) return;
    final index = _nodes.indexWhere((node) => node.id == id);
    if (index < 0) return;
    final node = _nodes[index] as ToolCallNode;
    var next = update(node);
    // The transition into a settled status is the moment the call's clock
    // stops; guarding on the transition rather than the state keeps a second
    // update of a settled call (a decline reported after a failure, say) from
    // moving the stamp.
    if (next.finishedAt == null &&
        next.status.isSettled &&
        !node.status.isSettled) {
      next = next.copyWith(finishedAt: DateTime.now());
    }
    _nodes[index] = next;
    notifyListeners();
  }

  void _fail(String message) {
    _freezeTail();
    _isBusy = false;
    _nodes.add(ErrorNode(id: _newId(), message: message));
    notifyListeners();
  }

  void _reset() {
    _subscription?.cancel();
    _subscription = null;
    if (_tail.nodeId != null) _tail.finish();
    _streamingIndex = null;
    _nodes.clear();
    _toolNodeIds.clear();
    _pendingApproval = null;
    _isBusy = false;
  }

  /// Ids are minted here rather than derived from content, so they stay stable
  /// while a node is edited in place. The prefix keeps them clear of the
  /// position-derived ids a restored session brings with it.
  String _newId() => 'n${_nextId++}';

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
