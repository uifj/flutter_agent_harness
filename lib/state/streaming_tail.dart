// The high-frequency end of the transcript.
//
// Token deltas land here and nowhere else. A streaming answer can produce
// hundreds of updates a second; routing them through the conversation controller
// would rebuild the whole message list each time, so the last assistant bubble
// subscribes to these listenables directly and the list stays still.
//
// The conversation controller freezes the tail into a `ConversationNode` when the
// message ends, which is the point at which the list does rebuild — once.

import 'package:flutter/foundation.dart';

class StreamingTail {
  final _text = ValueNotifier<String>('');
  final _reasoning = ValueNotifier<String>('');
  String? _nodeId;

  /// Answer text accumulated so far for [nodeId].
  ValueListenable<String> get text => _text;

  /// Reasoning accumulated so far for [nodeId].
  ValueListenable<String> get reasoning => _reasoning;

  /// The node currently being streamed into, or null when nothing is streaming.
  ///
  /// Only changes at message boundaries, so reading it during a build driven by
  /// the conversation controller is safe.
  String? get nodeId => _nodeId;

  bool get isEmpty => _text.value.isEmpty && _reasoning.value.isEmpty;

  /// Points the tail at a freshly created node.
  void begin(String nodeId) {
    _nodeId = nodeId;
    _text.value = '';
    _reasoning.value = '';
  }

  void appendText(String delta) => _text.value += delta;

  void appendReasoning(String delta) => _reasoning.value += delta;

  /// Detaches the tail and hands back what it accumulated, for the caller to
  /// store on the node.
  ({String text, String reasoning}) finish() {
    final result = (text: _text.value, reasoning: _reasoning.value);
    _nodeId = null;
    _text.value = '';
    _reasoning.value = '';
    return result;
  }

  void dispose() {
    _text.dispose();
    _reasoning.dispose();
  }
}
