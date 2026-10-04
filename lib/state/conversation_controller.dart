// The transcript, the turn that is building it, and what waits behind it.
//
// This is the low-frequency half of the streaming split: it notifies only when
// the *shape* of the transcript changes — a node appears, a tool card changes
// status, a turn ends. Token deltas go to [StreamingTail] instead and never reach
// a listener here, which is what keeps a streaming answer from rebuilding the
// whole list on every token.
//
// It consumes `Stream<TurnEvent>` and knows nothing about Genkit; the projection
// from Genkit's chunk stream happens in `lib/genkit/agent_runtime.dart`.
//
// It also owns what the user typed while a turn was running. The queue lives
// here rather than in the runtime because *when* an input is delivered is a
// transcript question — which turn it belongs to, what the panel shows — while
// the runtime only ever answers "read this at the next model call".

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../model/approval_mode.dart';
import '../model/approval_rule.dart';
import '../model/ask_user.dart';
import '../model/attached_image.dart';
import '../model/conversation.dart';
import '../model/queued_input.dart';
import '../model/turn_event.dart';
import '../model/turn_source.dart';
import 'approval_rule_store.dart';
import 'streaming_tail.dart';

class ConversationController extends ChangeNotifier {
  ConversationController({
    required TurnSource runtime,
    required StreamingTail tail,
    this.onSessionPersisted,
    this.onTurnUsage,
    this.approvals,
  }) : _runtime = runtime,
       _tail = tail;

  TurnSource _runtime;
  final StreamingTail _tail;

  /// Where an "always allow" answer is written. Null leaves the panel with the
  /// two verdicts it always had.
  final ApprovalRuleStore? approvals;

  /// Called with the session id once a turn has been persisted, so the session
  /// list can pick up a conversation that did not exist before.
  final void Function(String sessionId)? onSessionPersisted;

  /// Called at the end of every finished turn with the usage block — the
  /// local usage ledger's write seam (ADR-0045 PC). Never called for
  /// cancelled turns.
  final void Function(TurnUsage usage)? onTurnUsage;

  final List<ConversationNode> _nodes = [];
  final Map<String, String> _toolNodeIds = {};
  StreamSubscription<TurnEvent>? _subscription;
  ApprovalRequest? _pendingApproval;
  bool _isBusy = false;
  int _nextId = 0;

  /// What the user submitted while a turn held the transcript, oldest first.
  final _queue = <QueuedInput>[];
  int _nextQueueId = 0;
  bool _queueHeld = false;

  /// The message index the tail is currently attached to; see [TextDelta].
  int? _streamingIndex;

  List<ConversationNode> get nodes => UnmodifiableListView(_nodes);

  /// True while a turn is streaming. False again the moment [stop] is called —
  /// the UI does not wait for the runtime to confirm.
  bool get isBusy => _isBusy;

  /// Set while a tool is waiting for permission. The turn is paused, not over.
  ApprovalRequest? get pendingApproval => _pendingApproval;

  /// True when the composer cannot start a turn: mid-turn, or blocked on a
  /// decision. Inputs are still accepted then — they go to [pendingInputs].
  bool get isInputBlocked => _isBusy || _pendingApproval != null;

  /// The inputs waiting for the running turn to let go, oldest first.
  List<QueuedInput> get pendingInputs => UnmodifiableListView(_queue);

  /// False after [stop]: the queue stays where the user left it until they send
  /// again, rather than starting a turn they did not ask for.
  bool get isQueueHeld => _queueHeld;

  String? get sessionId => _runtime.sessionId;

  /// How gated tools behave from the next call. Held here so the composer's
  /// selector reads one notifier; forwarded to the runtime, which is where the
  /// tools consult it.
  ApprovalMode get approvalMode => _approvalMode;
  ApprovalMode _approvalMode = ApprovalMode.ask;

  set approvalMode(ApprovalMode mode) {
    if (mode == _approvalMode) return;
    _approvalMode = mode;
    _runtime.approvalMode = mode;
    notifyListeners();
  }

  /// The plan of record — the text of the last successful `plan` tool call, or
  /// null when the conversation has none yet.
  ///
  /// Derived by scanning the transcript rather than cached: a restore rebuilds
  /// it for free, and the scan is over a handful of tool nodes.
  String? get currentPlan {
    for (final node in _nodes.reversed) {
      if (node is! ToolCallNode || node.name != 'plan') continue;
      final output = node.output;
      if (output is Map && output['ok'] == true) {
        final text = output['plan'];
        return text is String && text.isNotEmpty ? text : null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Session stats (dsh's StatsLine figures)
  // ---------------------------------------------------------------------------

  /// The conversation's settled turns, for the stats line's counts. A user
  /// message begins one; a failed turn still counts — the user experienced it.
  int get _turnCount => _nodes.whereType<UserMessageNode>().length;

  /// Window-scoped tool wall time: the sum over settled tool calls of
  /// `startedAt → finishedAt`, the same pair dsh folds from its tool-result
  /// nodes. A restored-from-snapshot call has no stamps and contributes
  /// nothing rather than a zero.
  int get toolWallMs {
    var total = 0;
    for (final node in _nodes) {
      if (node is! ToolCallNode) continue;
      final started = node.startedAt;
      final finished = node.finishedAt;
      if (started == null || finished == null) continue;
      final ms = finished.difference(started).inMilliseconds;
      if (ms > 0) total += ms;
    }
    return total;
  }

  /// The running sums of the runtime's turn measurements. Only turns the
  /// runtime could measure land here; `_reset` clears them with the nodes,
  /// so a session switch cannot carry one conversation's figures into the
  /// next's line.
  int _llmMs = 0;
  int _ttftMs = 0;
  int _ttftTurns = 0;
  int _inputTokens = 0;
  int _outputTokens = 0;
  int _totalTokens = 0;

  /// Summed LLM wall time over measured turns — dsh's `stats.llm`.
  int get llmWallMs => _llmMs;

  /// Mean first-token latency over turns that produced a token — dsh's
  /// `stats.ttftAverage`. Null when no turn did.
  double? get ttftAverageMs => _ttftTurns == 0 ? null : _ttftMs / _ttftTurns;

  /// Token sums over the turns whose provider reported usage — dsh folds the
  /// same figures from its session log. A provider that reports nothing
  /// contributes nothing, which is why these stay zero rather than null.
  int get inputTokens => _inputTokens;
  int get outputTokens => _outputTokens;
  int get totalTokens => _totalTokens;

  /// Accumulated from [TurnFinished.usage] — see [_handle].
  void _absorb(TurnUsage? usage) {
    if (usage == null) return;
    _llmMs += usage.wallMs;
    final ttft = usage.ttftMs;
    if (ttft != null) {
      _ttftMs += ttft;
      _ttftTurns++;
    }
    final input = usage.inputTokens;
    if (input != null) _inputTokens += input;
    final output = usage.outputTokens;
    if (output != null) _outputTokens += output;
    final total = usage.totalTokens;
    if (total != null) {
      _totalTokens += total;
    } else if (input != null || output != null) {
      // A provider that skips its own total still leaves a countable bill.
      _totalTokens += (input ?? 0) + (output ?? 0);
    }
  }

  /// Whether the stats line has anything to say — mounted by ConversationRoot
  /// to keep the row's seat rather than conditionally shifting the composer.
  bool get hasStats =>
      _turnCount > 0 ||
      _llmMs > 0 ||
      toolWallMs > 0 ||
      _ttftTurns > 0 ||
      _totalTokens > 0;

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  /// Puts [text] in front of the model.
  ///
  /// Three doors, in this order: a [InputDelivery.guide] with a turn running is
  /// handed to that turn and leaves no queue row; anything submitted while the
  /// transcript is busy joins the queue; otherwise it starts a turn here. The
  /// queue is FIFO and is read only by [_drain], which runs when a turn lets go.
  Future<void> send(
    String text, {
    List<AttachedImage> images = const [],
    InputDelivery delivery = InputDelivery.queue,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && images.isEmpty) return;
    final input = QueuedInput(
      id: _nextQueueId++,
      text: trimmed,
      images: images,
      delivery: delivery,
    );
    // Sending anything new is also the release for a queue that [stop] parked:
    // the user is back in the conversation.
    _queueHeld = false;
    if (delivery == InputDelivery.guide && _handOver(input)) return;
    if (isInputBlocked) {
      _queue.add(input);
      notifyListeners();
      return;
    }
    await _send(input);
    await _drain();
  }

  /// Takes a queued row out of the line.
  void removeQueued(int id) {
    _queue.removeWhere((input) => input.id == id);
    notifyListeners();
  }

  /// Moves a queued row, in the [ReorderableListView] convention where
  /// [newIndex] is expressed against the list the row was still in.
  void moveQueued(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (target < 0 || target > _queue.length - 1) return;
    _queue.insert(target, _queue.removeAt(oldIndex));
    notifyListeners();
  }

  /// Changes a waiting input's delivery. Switching to guide while a turn is open
  /// hands it over at once instead of leaving it to rot at the back of the line.
  void setQueuedDelivery(int id, InputDelivery delivery) {
    final index = _queue.indexWhere((input) => input.id == id);
    if (index < 0) return;
    if (delivery == InputDelivery.guide && _handOver(_queue.removeAt(index))) {
      notifyListeners();
      return;
    }
    _queue[index].delivery = delivery;
    notifyListeners();
  }

  bool _handOver(QueuedInput input) {
    if (!_runtime.guide(input)) return false;
    _nodes.add(
      UserMessageNode(id: _newId(), text: input.text, images: input.images),
    );
    notifyListeners();
    return true;
  }

  /// One turn, no queueing: the node, the busy flag, the stream.
  Future<void> _send(QueuedInput input) async {
    _nodes.add(
      UserMessageNode(id: _newId(), text: input.text, images: input.images),
    );
    _isBusy = true;
    notifyListeners();

    await _consume(_runtime.send(input.text, images: input.images));
  }

  /// The queue's only reader, and the only place a held guide comes back.
  ///
  /// Runs after a turn's stream closed, never from inside an event handler: a
  /// second [_consume] while the first is settling would overwrite
  /// [_subscription] and the new stream would report nothing.
  Future<void> _drain() async {
    // A steer the run never reached is still something the user said. It comes
    // back to the front of the line as an ordinary turn rather than waiting in
    // the runtime for a model call that may never come.
    final leftovers = _runtime.takeUndeliveredGuides();
    if (leftovers.isNotEmpty) {
      for (final input in leftovers) {
        input.delivery = InputDelivery.queue;
      }
      _queue.insertAll(0, leftovers);
      notifyListeners();
    }
    while (!_queueHeld && _queue.isNotEmpty && !isInputBlocked) {
      await _send(_queue.removeAt(0));
    }
  }

  /// Answers the pending approval and lets the paused turn continue.
  Future<void> respondToApproval(bool approved, {bool remember = false}) async {
    final request = _pendingApproval;
    if (request == null || _isBusy) return;

    // Written before the resume, not after: a turn can ask again for the next
    // call, and a decision the user just made should already be in force by
    // then. A remembered rejection would need its own review list first, so
    // only an approval is offered as permanent.
    final rule = approved && remember
        ? request.ruleFor(ApprovalOutcome.allow)
        : null;
    if (rule != null) await approvals?.remember(rule);

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
    // The steer that waited out the pause has had its model call by now; the
    // ones that never got one come back through _drain, ahead of the line.
    await _drain();
  }

  /// Delivers the user's answers to the pending ask_user call (ADR-0059) and
  /// lets the paused turn continue. No rule is remembered here: an answer is
  /// a one-off fact, a standing allow is a judgment — collapsing the two is
  /// how "always allow" would silently start speaking for the user.
  Future<void> respondToAskUser(List<AskUserAnswer> answers) async {
    final request = _pendingApproval;
    if (request == null || _isBusy) return;

    _pendingApproval = null;
    // Marked running before the resume so the question card stops looking
    // like a question the moment the answer is submitted; the runtime
    // projects the settled result itself (respond has no restart output to
    // recover, so the [ToolCallSucceeded] comes straight from it).
    _updateTool(
      request.ref,
      (node) => node.copyWith(status: ToolStatus.running, clearApproval: true),
    );
    _isBusy = true;
    notifyListeners();

    await _consume(
      _runtime.respondToAskUser(
        ref: request.ref,
        answers: AskUserAnswer.payload(answers),
      ),
    );
    await _drain();
  }

  /// Stops the running turn.
  ///
  /// Goes quiet immediately rather than waiting for the runtime's own
  /// `TurnFinished`: the spike established that an in-flight request cannot
  /// actually be interrupted, so anything that still arrives is discarded.
  ///
  /// The queue is parked, not flushed. A user who pressed stop has asked the
  /// agent to hold off; starting the next queued message for them would be the
  /// opposite answer. Sending anything new lets the line run again.
  void stop() {
    if (!_isBusy) return;
    _runtime.stop();
    _freezeTail();
    _isBusy = false;
    _queueHeld = true;
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

      case TurnFinished(
        :final outcome,
        :final sessionId,
        :final errorMessage,
        :final usage,
      ):
        _freezeTail();
        _absorb(usage);
        if (usage != null &&
            (outcome == TurnOutcome.completed ||
                outcome == TurnOutcome.failed)) {
          onTurnUsage?.call(usage);
        }
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
    // The queue belongs to the conversation it was typed in. Carrying it over
    // would send one folder's half-thoughts into another's first turn.
    _queue.clear();
    _queueHeld = false;
    // The stats describe THIS conversation's turns; the next one starts its
    // ledger clean rather than inheriting figures it cannot account for.
    _llmMs = 0;
    _ttftMs = 0;
    _ttftTurns = 0;
    _inputTokens = 0;
    _outputTokens = 0;
    _totalTokens = 0;
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
