import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    List<String>? driveScopes,
    String? googleClientId,
    String? googleServerClientId,
  }) : _firebaseAuthOverride = firebaseAuth,
       _googleSignIn =
           googleSignIn ??
           GoogleSignIn(
             clientId: googleClientId,
             serverClientId: googleServerClientId,
           ),
       _driveScopes = List.unmodifiable(driveScopes ?? _defaultDriveScopes);

  static const List<String> _defaultDriveScopes = [
    drive.DriveApi.driveAppdataScope,
  ];

  static http.Client? authenticatedDriveClient;

  final FirebaseAuth? _firebaseAuthOverride;
  final GoogleSignIn _googleSignIn;
  final List<String> _driveScopes;

  GoogleSignInAccount? _googleAccount;
  Map<String, String>? _googleDriveHeaders;

  FirebaseAuth get _firebaseAuth =>
      _firebaseAuthOverride ?? FirebaseAuth.instance;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get userSessionStream => authStateChanges();

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Map<String, String>? get cachedGoogleDriveHeaders => _googleDriveHeaders;

  bool get hasGoogleDriveHeaders => _googleDriveHeaders != null;

  bool get supportsTotpMfa =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthMultiFactorException catch (error) {
      for (final hint in error.resolver.hints) {
        if (hint is TotpMultiFactorInfo) {
          throw TotpChallengeRequiredException(
            TotpSignInChallenge(
              resolver: error.resolver,
              enrollmentId: hint.uid,
            ),
          );
        }
      }
      throw const AuthServiceException(
        'This account requires an unsupported second-factor method.',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<UserCredential> resolveTotpSignIn(
    TotpSignInChallenge challenge,
    String code,
  ) async {
    try {
      final assertion = await TotpMultiFactorGenerator.getAssertionForSignIn(
        challenge.enrollmentId,
        code.trim(),
      );
      return await challenge.resolver.resolveSignIn(assertion);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<List<MultiFactorInfo>> getEnrolledTotpFactors() async {
    _ensureTotpSupport();
    final user = _requireCurrentUser();
    try {
      final factors = await user.multiFactor.getEnrolledFactors();
      return factors.whereType<TotpMultiFactorInfo>().toList();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    } on PlatformException catch (error) {
      throw AuthServiceException(_platformAuthMessage(error));
    }
  }

  Future<void> sendCurrentUserEmailVerification() async {
    final user = _requireCurrentUser();
    try {
      if (!user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<bool> refreshCurrentUserEmailVerification() async {
    final user = _requireCurrentUser();
    try {
      await user.reload();
      return _firebaseAuth.currentUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> updateCurrentUserDisplayName(String displayName) async {
    final user = _requireCurrentUser();
    try {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> reloadCurrentUser() async {
    final user = _requireCurrentUser();
    try {
      await user.reload();
      await _firebaseAuth.currentUser?.getIdToken(true);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> requestCurrentUserEmailChange(String email) async {
    final user = _requireCurrentUser();
    try {
      // Use Firebase's hosted VERIFY_AND_CHANGE_EMAIL handler. Supplying a
      // custom continuation URL makes delivery/application depend on that URL
      // and its authorized-domain configuration in the Firebase project.
      await user.verifyBeforeUpdateEmail(email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'requires-recent-login') {
        throw const RecentLoginRequiredException();
      }
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> reauthenticateCurrentUserWithPassword(String password) async {
    final user = _requireCurrentUser();
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AuthServiceException(
        'Password confirmation is unavailable for this account.',
      );
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> reauthenticateCurrentUserWithGoogle() async {
    final user = _requireCurrentUser();
    try {
      var googleUser =
          _googleAccount ??
          _googleSignIn.currentUser ??
          await _googleSignIn.signInSilently() ??
          await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthServiceException(
          'Google reauthentication was cancelled.',
        );
      }
      var googleAuth = await googleUser.authentication;
      var credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      try {
        await user.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'invalid-credential' ||
            e.code == 'user-token-expired' ||
            e.code == 'user-mismatch') {
          final freshGoogleUser = await _googleSignIn.signIn();
          if (freshGoogleUser == null) {
            throw const AuthServiceException(
              'Google reauthentication was cancelled.',
            );
          }
          googleUser = freshGoogleUser;
          googleAuth = await freshGoogleUser.authentication;
          credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await user.reauthenticateWithCredential(credential);
        } else {
          rethrow;
        }
      }
      _googleAccount = googleUser;
    } on AuthServiceException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    } on PlatformException catch (error) {
      throw AuthServiceException(
        _googleSignInMessage(error, action: 'confirm your Google account'),
      );
    }
  }

  Future<void> sendCurrentUserPasswordReset() async {
    final email = _requireCurrentUser().email;
    if (email == null || email.isEmpty) {
      throw const AuthServiceException(
        'This account does not have an email address.',
      );
    }
    await sendPasswordResetEmail(email);
  }

  Future<bool> hasTotpEnrollment() async {
    return (await getEnrolledTotpFactors()).isNotEmpty;
  }

  Future<TotpEnrollmentData> startTotpEnrollment() async {
    _ensureTotpSupport();
    final user = _requireCurrentUser();
    try {
      final session = await user.multiFactor.getSession();
      final secret = await TotpMultiFactorGenerator.generateSecret(session);
      final qrCodeUrl = await secret.generateQrCodeUrl(
        accountName: user.email ?? user.uid,
        issuer: 'Filer Flow',
      );
      return TotpEnrollmentData(secret: secret, qrCodeUrl: qrCodeUrl);
    } on FirebaseAuthException catch (error) {
      if (_requiresRecentLogin(error.code)) {
        throw const RecentLoginRequiredException();
      }
      throw AuthServiceException(_firebaseAuthMessage(error));
    } on PlatformException catch (error) {
      if (_requiresRecentLogin(error.code)) {
        throw const RecentLoginRequiredException();
      }
      throw AuthServiceException(_platformAuthMessage(error));
    }
  }

  Future<void> openTotpEnrollmentInAuthenticator(
    TotpEnrollmentData enrollment,
  ) {
    return enrollment.secret.openInOtpApp(enrollment.qrCodeUrl);
  }

  Future<void> completeTotpEnrollment(
    TotpEnrollmentData enrollment,
    String code,
  ) async {
    final user = _requireCurrentUser();
    try {
      final assertion =
          await TotpMultiFactorGenerator.getAssertionForEnrollment(
            enrollment.secret,
            code.trim(),
          );
      await user.multiFactor.enroll(
        assertion,
        displayName: 'Authenticator app',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    } on PlatformException catch (error) {
      throw AuthServiceException(_platformAuthMessage(error));
    }
  }

  Future<void> disableTotp(MultiFactorInfo factor) async {
    final user = _requireCurrentUser();
    try {
      await user.multiFactor.unenroll(multiFactorInfo: factor);
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<User?> signUpWithEmail({
    required String name,
    required String contactNumber,
    required String email,
    required String password,
  }) async {
    final credential = await createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(name.trim());
      if (!user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException {
          // The mandatory MFA screen lets the user resend this safely.
        }
      }
      await user.reload();
    }
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (credential.user == null) {
      throw const AuthServiceException('Email login failed. Please try again.');
    }
    return credential.user;
  }

  Future<UserCredential> signInWithGoogle({
    bool requestDriveAccess = true,
  }) async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthServiceException('Google sign in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      _googleAccount = googleUser;
      if (requestDriveAccess) {
        await _loadDriveHeaders(googleUser, promptIfNecessary: true);
      } else {
        _clearDriveCredentials();
      }

      return userCredential;
    } on AuthServiceException {
      rethrow;
    } on FirebaseAuthMultiFactorException catch (error) {
      for (final hint in error.resolver.hints) {
        if (hint is TotpMultiFactorInfo) {
          throw TotpChallengeRequiredException(
            TotpSignInChallenge(
              resolver: error.resolver,
              enrollmentId: hint.uid,
            ),
          );
        }
      }
      throw const AuthServiceException(
        'This Google account requires an unsupported second-factor method.',
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-allowed') {
        throw const AuthServiceException(
          'Google Sign-In is disabled in Firebase. Enable Google under Firebase Console > Authentication > Sign-in method.',
        );
      }
      throw AuthServiceException(_firebaseAuthMessage(error));
    } catch (_) {
      throw const AuthServiceException(
        'Google sign in failed. Please try again.',
      );
    }
  }

  Future<bool> linkGoogleDriveAccount() async {
    try {
      await getGoogleDriveHeaders(promptIfNecessary: true);
      return true;
    } on AuthServiceException {
      return false;
    }
  }

  Future<Map<String, String>> getGoogleDriveHeaders({
    bool promptIfNecessary = false,
  }) async {
    try {
      final account =
          _googleAccount ??
          _googleSignIn.currentUser ??
          await _googleSignIn.signInSilently();

      if (account == null) {
        if (!promptIfNecessary) {
          throw const AuthServiceException(
            'Sign in with Google before using Drive sync.',
          );
        }

        final promptedAccount = await _googleSignIn.signIn();
        if (promptedAccount == null) {
          throw const AuthServiceException('Google sign in was cancelled.');
        }

        _googleAccount = promptedAccount;
        return _loadDriveHeaders(
          promptedAccount,
          promptIfNecessary: promptIfNecessary,
        );
      }

      _googleAccount = account;
      return _loadDriveHeaders(account, promptIfNecessary: promptIfNecessary);
    } on AuthServiceException {
      rethrow;
    } on PlatformException catch (error) {
      throw AuthServiceException(
        _googleSignInMessage(error, action: 'connect Google Drive'),
      );
    } catch (error) {
      throw AuthServiceException(
        'Could not connect Google Drive. ${error.toString()}',
      );
    }
  }

  Future<void> refreshGoogleDriveHeaders() async {
    await getGoogleDriveHeaders(promptIfNecessary: true);
  }

  Future<void> signOut() async {
    _googleAccount = null;
    _clearDriveCredentials();
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> deleteCurrentUser() async {
    final user = _requireCurrentUser();
    try {
      await user.delete();
    } on FirebaseAuthException catch (error) {
      if (_requiresRecentLogin(error.code)) {
        throw const RecentLoginRequiredException();
      }
      throw AuthServiceException(_firebaseAuthMessage(error));
    }

    _googleAccount = null;
    _clearDriveCredentials();
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // The Firebase account is already deleted. A stale Google session must
        // not make the completed deletion appear to have failed.
      }
    }
  }

  Future<void> disconnectGoogle() async {
    _googleAccount = null;
    _clearDriveCredentials();
    await _googleSignIn.disconnect();
  }

  Future<Map<String, String>> _loadDriveHeaders(
    GoogleSignInAccount account, {
    required bool promptIfNecessary,
  }) async {
    if (!promptIfNecessary) {
      // Without prompting, just try to use existing auth headers.
      final headers = Map<String, String>.unmodifiable(
        await account.authHeaders,
      );
      _googleDriveHeaders = headers;
      _setAuthenticatedDriveClient(GoogleHttpClient(headers));
      return headers;
    }

    final granted = await _googleSignIn.requestScopes(_driveScopes);
    if (!granted) {
      throw const AuthServiceException(
        'Google Drive permission is required for cloud sync.',
      );
    }

    final headers = Map<String, String>.unmodifiable(await account.authHeaders);
    _googleDriveHeaders = headers;
    _setAuthenticatedDriveClient(GoogleHttpClient(headers));
    return headers;
  }

  void _clearDriveCredentials() {
    _googleDriveHeaders = null;
    _setAuthenticatedDriveClient(null);
  }

  static void _setAuthenticatedDriveClient(http.Client? client) {
    authenticatedDriveClient?.close();
    authenticatedDriveClient = client;
  }

  String _firebaseAuthMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'email-already-in-use' => 'An account already exists for this email.',
      'invalid-email' => 'Enter a valid email address.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'The email or password is incorrect.',
      'operation-not-allowed' => 'This sign-in method is not enabled.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'user-disabled' => 'This account has been disabled.',
      'weak-password' => 'Choose a stronger password.',
      'network-request-failed' =>
        'Check your internet connection and try again.',
      'invalid-verification-code' || 'invalid-multi-factor-session' =>
        'The authenticator code is invalid or expired.',
      'second-factor-already-in-use' =>
        'An authenticator app is already enrolled.',
      'requires-recent-login' =>
        'For security, confirm your password before changing sensitive account information.',
      'unsupported-first-factor' =>
        'This sign-in method cannot be used with two-factor authentication.',
      'unverified-email' =>
        'Verify your email address before enabling two-factor authentication.',
      _ => 'Authentication failed. Please try again.',
    };
  }

  bool _requiresRecentLogin(String code) {
    final normalized = code.toLowerCase().replaceAll('_', '-');
    return normalized.contains('user-token-expired') ||
        normalized.contains('requires-recent-login') ||
        normalized.contains('invalid-user-token');
  }

  String _platformAuthMessage(PlatformException error) {
    if (_requiresRecentLogin(error.code)) {
      return 'Your session expired. Sign in again and retry.';
    }
    return error.message ?? 'Authentication failed. Please try again.';
  }

  User _requireCurrentUser() {
    final user = currentUser;
    if (user == null) {
      throw const AuthServiceException('Sign in before managing security.');
    }
    return user;
  }

  void _ensureTotpSupport() {
    if (!supportsTotpMfa) {
      throw const AuthServiceException(
        'Authenticator-app verification is supported on Android, iOS, and web.',
      );
    }
  }

  String _googleSignInMessage(
    PlatformException error, {
    required String action,
  }) {
    final details = error.message ?? error.details?.toString();
    final suffix = details == null || details.isEmpty ? '' : ' ($details)';
    return 'Could not $action. Google sign-in returned ${error.code}$suffix.';
  }
}

class GoogleHttpClient extends http.BaseClient {
  GoogleHttpClient(this._headers);

  final Map<String, String> _headers;
  final http.Client _innerClient = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _innerClient.send(request);
  }

  @override
  void close() {
    _innerClient.close();
    super.close();
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RecentLoginRequiredException extends AuthServiceException {
  const RecentLoginRequiredException()
    : super('Your session expired. Confirm your sign-in and try again.');
}

class TotpSignInChallenge {
  const TotpSignInChallenge({
    required this.resolver,
    required this.enrollmentId,
  });

  final MultiFactorResolver resolver;
  final String enrollmentId;
}

class TotpChallengeRequiredException implements Exception {
  const TotpChallengeRequiredException(this.challenge);

  final TotpSignInChallenge challenge;
}

class TotpEnrollmentData {
  const TotpEnrollmentData({required this.secret, required this.qrCodeUrl});

  final TotpSecret secret;
  final String qrCodeUrl;

  String get secretKey => secret.secretKey;
}
