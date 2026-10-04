// ADR-0058 guards: the context snapshot's part rules — text keeps its whole
// words, tool payloads are capped, media bytes never land in the log, and a
// record survives a JSON round-trip. The capture itself is thin glue; this
// is the logic worth pinning.

import 'package:genkit/genkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/genkit/agent_runtime.dart';
import 'package:planstar/model/diagnostic_record.dart';

void main() {
  test('text keeps whole words and roles survive', () {
    final request = ModelRequest(
      messages: [
        Message(
          role: Role.system,
          content: [TextPart(text: 'You are the workspace agent.')],
        ),
        Message(
          role: Role.user,
          content: [TextPart(text: 'list the files, then stop')],
        ),
      ],
    );

    final record = contextSnapshotOf(request, 'deepseek-chat');

    expect(record.model, 'deepseek-chat');
    expect(record.messages, hasLength(2));
    expect(record.messages[0].role, 'system');
    expect(record.messages[0].parts.single.kind, 'text');
    expect(
      record.messages[0].parts.single.text,
      'You are the workspace agent.',
    );
    expect(record.messages[1].role, 'user');
  });

  test('small tool payloads stay exact, big ones are capped', () {
    final request = ModelRequest(
      messages: [
        Message(
          role: Role.model,
          content: [
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'read',
                input: {'path': 'notes/plan.md'},
              ),
            ),
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'bash',
                input: {'command': 'ls', 'noise': 'x' * 5000},
              ),
            ),
            ToolResponsePart(
              toolResponse: ToolResponse(
                name: 'bash',
                output: {'output': 'y' * 5000},
              ),
            ),
          ],
        ),
      ],
    );

    final record = contextSnapshotOf(request, 'deepseek-chat');
    final parts = record.messages.single.parts;

    expect(parts[0].kind, 'toolRequest');
    expect(parts[0].name, 'read');
    expect(parts[0].payload, '{"path":"notes/plan.md"}');

    expect(parts[1].kind, 'toolRequest');
    expect(parts[1].name, 'bash');
    expect(parts[1].payload as String, contains('(truncated)'));
    expect(
      (parts[1].payload as String).length,
      lessThanOrEqualTo(4096 + '…(truncated)'.length),
    );

    expect(parts[2].kind, 'toolResponse');
    expect(parts[2].name, 'bash');
    expect(parts[2].payload as String, contains('(truncated)'));
  });

  test('media bytes are elided, a remote URL stays readable', () {
    final request = ModelRequest(
      messages: [
        Message(
          role: Role.user,
          content: [
            MediaPart(
              media: Media(
                contentType: 'image/png',
                url: 'data:image/png;base64,AAAApayloadbytes',
              ),
            ),
            MediaPart(
              media: Media(
                contentType: 'image/png',
                url: 'https://example.com/diagram.png',
              ),
            ),
          ],
        ),
      ],
    );

    final record = contextSnapshotOf(request, 'deepseek-chat');
    final parts = record.messages.single.parts;

    expect(parts[0].kind, 'media');
    expect(parts[0].elided, isTrue);
    expect(parts[0].payload, '<media elided>');
    expect(parts[0].text, isNull);

    expect(parts[1].elided, isFalse);
    expect(parts[1].text, 'https://example.com/diagram.png');
    expect(parts[1].payload, isNull);
  });

  test('a snapshot record survives the JSON round-trip', () {
    final request = ModelRequest(
      messages: [
        Message(
          role: Role.system,
          content: [TextPart(text: 'sys')],
        ),
        Message(
          role: Role.user,
          content: [
            TextPart(text: 'hi'),
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'glob',
                input: {'pattern': '*.md'},
              ),
            ),
          ],
        ),
      ],
    );

    final record = contextSnapshotOf(request, 'deepseek-chat');
    final restored = ContextSnapshotRecord.fromJson(record.toJson());

    expect(restored.model, record.model);
    expect(restored.messages, hasLength(2));
    expect(restored.messages[1].parts, hasLength(2));
    expect(restored.messages[1].parts[1].kind, 'toolRequest');
    expect(restored.messages[1].parts[1].name, 'glob');
    expect(restored.messages[1].parts[1].payload, '{"pattern":"*.md"}');
  });
}
