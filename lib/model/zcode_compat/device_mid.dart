// The device identity (`deviceMid.ts:21-28`): a UUID persisted once and used
// as the `X-Device-Mid` header on billing/feedback/update traffic. Our store
// is `<support>/device_state.json`; generation is UUID-v4-shaped from
// `Random.secure` — no dependency.

import 'dart:math';

/// Generates a random UUID v4 string (`xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx`,
/// variant bits `8/9/a/b`).
String generateDeviceMid({Random? random}) {
  final rng = random ?? Random.secure();
  String hex(int count) => [
        for (var i = 0; i < count; i++)
          rng.nextInt(16).toRadixString(16),
      ].join();
  final bytes = hex(32).split('')..[12] = '4';
  final variant = rng.nextInt(4);
  bytes[16] = const ['8', '9', 'a', 'b'][variant];
  final s = bytes.join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-'
      '${s.substring(16, 20)}-${s.substring(20, 32)}';
}

/// True when [value] looks like the UUID shape `deviceMid.ts` persists — the
/// loader accepts what the generator emits and anything else regenerates.
bool isValidDeviceMid(String? value) =>
    value != null &&
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
        .hasMatch(value);
