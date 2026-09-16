// The one sentence this file holds: the profile is a plain value object whose
// avatar initial is derived from the display name, and the mock source resolves
// a fixed profile through the async repository contract.
//
// This is the ADR-0006 S1 check. The `ProfileRepository` indirection is the
// Supabase seam, so the mock must actually be async (a real source is), and the
// initial getter is the only computation in the model — both are worth pinning
// before the sidebar renders them.

import 'package:agent_harness/host/profile_repository.dart';
import 'package:agent_harness/model/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfile', () {
    test('the initial is the first character, upper-cased and trimmed', () {
      expect(const UserProfile(displayName: 'demo', email: '').initial, 'D');
      expect(const UserProfile(displayName: '  wb', email: '').initial, 'W');
      expect(const UserProfile(displayName: '   ', email: '').initial, '?');
      expect(const UserProfile(displayName: '', email: '').initial, '?');
    });

    test('two profiles with the same fields are equal', () {
      const a = UserProfile(
        displayName: 'X',
        email: 'x@y.z',
        avatarColorIndex: 3,
        subscription: 'Pro',
      );
      const b = UserProfile(
        displayName: 'X',
        email: 'x@y.z',
        avatarColorIndex: 3,
        subscription: 'Pro',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(b.copyWithLikeSubscription),
        reason: 'a differing subscription is a different profile',
      );
    });
  });

  group('MockProfileRepository', () {
    test('resolves a fixed profile through the async contract', () async {
      final profile = await const MockProfileRepository().fetchProfile();
      expect(profile, isNotNull);
      expect(profile!.initial, 'D');
      expect(profile.email, isNotEmpty);
    });
  });
}

extension on UserProfile {
  /// A same-shape profile with one field changed, for the inequality check.
  UserProfile get copyWithLikeSubscription => UserProfile(
    displayName: displayName,
    email: email,
    avatarColorIndex: avatarColorIndex,
    subscription: subscription == null ? 'x' : '${subscription}x',
  );
}
