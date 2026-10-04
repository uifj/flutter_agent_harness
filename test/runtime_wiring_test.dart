// Structural guards for the runtime's wiring (ADR-0068): the retry plugin
// and its middleware ref must stay attached to the model seam. Source-scan
// like the other structure tests — the runtime itself needs a Genkit
// instance and a provider, which a unit test has no business faking.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the retry plugin rides the model seam', () {
    final source = _readRuntime();
    expect(source.contains('RetryPlugin()'), isTrue);
    expect(
      source.contains("middlewareRef<RetryOptions>(name: 'retry')"),
      isTrue,
    );
  });
}

String _readRuntime() {
  // One level up from test/ into lib/genkit/.
  final file = File('lib/genkit/agent_runtime.dart');
  return file.readAsStringSync();
}
