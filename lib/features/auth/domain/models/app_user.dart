import 'package:firebase_auth/firebase_auth.dart';

/// Represents an authenticated or offline user within Filer Flow.
class AppUser {
  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.providerData = const [],
    this.emailVerified = false,
    this.isOffline = false,
  });

  /// Unique identifier for the user (Firebase UID or offline user ID).
  final String uid;

  /// User email address (if available).
  final String? email;

  /// User display name.
  final String? displayName;

  /// User photo URL.
  final String? photoURL;

  /// List of provider metadata (e.g. password, google.com).
  final List<AppUserInfo> providerData;

  /// Whether the user's email address has been verified.
  final bool emailVerified;

  /// Whether the user is currently in a local offline session.
  final bool isOffline;

  /// Constructs an [AppUser] from an active Firebase [User].
  factory AppUser.fromFirebase(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      providerData: user.providerData
          .map((info) => AppUserInfo(providerId: info.providerId))
          .toList(),
      emailVerified: user.emailVerified,
      isOffline: false,
    );
  }

  /// Constructs an [AppUser] for an offline / local session.
  factory AppUser.offline({
    String uid = 'offline_local_user',
    String? email,
    String? displayName,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? 'offline@filerflow.local',
      displayName: displayName ?? 'Offline User',
      photoURL: null,
      providerData: const [],
      emailVerified: true,
      isOffline: true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email &&
          displayName == other.displayName &&
          emailVerified == other.emailVerified &&
          isOffline == other.isOffline;

  @override
  int get hashCode =>
      uid.hashCode ^
      email.hashCode ^
      displayName.hashCode ^
      emailVerified.hashCode ^
      isOffline.hashCode;

  @override
  String toString() =>
      'AppUser(uid: $uid, email: $email, displayName: $displayName, isOffline: $isOffline)';
}

/// Lightweight representation of provider metadata for [AppUser].
class AppUserInfo {
  const AppUserInfo({required this.providerId});

  /// The provider identifier (e.g. 'password', 'google.com').
  final String providerId;
}
