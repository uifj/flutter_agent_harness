// Who the app is showing its chrome for (ADR-0006).
//
// A plain value object, deliberately NOT part of `AppSettings`: the settings
// document is what the app remembers between launches, whereas the profile is
// *fetched* from an identity source (mock today, Supabase tomorrow — see
// `host/profile_repository.dart`). Persisting it would fork a second copy of a
// fact the source owns. So it rides a provider, not the store.
//
// Pure Dart: no flutter import (the `lib/model` invariant). The avatar colour is
// an index into a palette the UI owns, not a `Color`, precisely so this file
// stays framework-free.

class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.email,
    this.avatarColorIndex = 0,
    this.subscription,
  });

  /// The name shown beside the avatar and its initial.
  final String displayName;

  /// The account email, shown under the name.
  final String email;

  /// Index into the avatar palette the sidebar picks a colour from. An index
  /// rather than a colour so the model stays free of `dart:ui`.
  final int avatarColorIndex;

  /// A short plan label ('Pro', '团队版', …), or null when there is nothing to
  /// say. It is fetched data, not UI copy, so it does not go through i18n.
  final String? subscription;

  /// The avatar's glyph when there is no image: the first character of the
  /// display name, upper-cased; '?' for an empty one.
  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.displayName == displayName &&
      other.email == email &&
      other.avatarColorIndex == avatarColorIndex &&
      other.subscription == subscription;

  @override
  int get hashCode =>
      Object.hash(displayName, email, avatarColorIndex, subscription);
}
