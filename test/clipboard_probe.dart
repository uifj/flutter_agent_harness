// What the copy controls actually put on the clipboard.
//
// Every block primitive's copy control has a contract about its payload — the
// read card copies the file's lines without the gutter numbers, the terminal card
// copies the raw output without the prompt, the search card copies the whole
// result rather than the rows that survived the height cap. Asserting that
// `Copied` appeared only proves the control reacted, so these tests read the
// clipboard call itself.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures `Clipboard.setData` for the duration of a test.
///
/// The mock is installed in the test's own binding and removed on teardown, so a
/// test that copies nothing still sees [text] as null rather than the previous
/// test's payload.
class ClipboardProbe {
  ClipboardProbe(this._messenger) {
    _messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        text = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(
      () => _messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }

  final TestDefaultBinaryMessenger _messenger;

  /// The most recent copied payload, or null while nothing has been copied.
  String? text;
}
