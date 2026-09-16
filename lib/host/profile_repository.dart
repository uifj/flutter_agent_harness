// The seam between the app's chrome and wherever the user's identity lives
// (ADR-0006).
//
// The sidebar avatar and the footer quick-menu read a `UserProfile` through this
// one method. Today the only implementation is [MockProfileRepository] (fixed
// demo data). The point of the indirection is that a later Supabase-backed
// implementation drops in behind the SAME interface with no UI change — the
// switch is a single provider override (see `app_providers.profileRepository`).
//
// Reserved Supabase integration (NOT implemented yet — adding `supabase_flutter`
// needs its own DEP ADR):
//   * `class SupabaseProfileRepository implements ProfileRepository`
//   * auth: the signed-in user is `supabase.auth.currentSession?.user`; when
//     there is no session, `fetchProfile()` returns null and the UI falls back to
//     an anonymous placeholder avatar.
//   * data: a `profiles` row keyed by that user's uid, columns
//     `display_name`, `email`, `avatar_color_index`, `subscription`.
//   * wiring: `main` overrides `profileRepositoryProvider` with the Supabase
//     instance instead of the mock; nothing below the provider changes.

import '../model/user_profile.dart';

/// Loads the current user's profile, or null when there is none (signed out,
/// or a source that has no record yet).
abstract class ProfileRepository {
  const ProfileRepository();

  Future<UserProfile?> fetchProfile();
}

/// The stand-in used until a real identity source is wired: a fixed demo
/// profile, resolved on the next microtask so callers exercise the async path.
class MockProfileRepository extends ProfileRepository {
  const MockProfileRepository();

  @override
  Future<UserProfile?> fetchProfile() async => const UserProfile(
    displayName: 'Demo User',
    email: 'demo@example.com',
    avatarColorIndex: 2,
    subscription: 'Pro',
  );
}
