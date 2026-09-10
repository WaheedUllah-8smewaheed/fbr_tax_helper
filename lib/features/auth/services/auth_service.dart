import 'dart:async';
import 'dart:convert';
import 'package:fbr_tax_helper/features/auth/domain/models/app_user.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FlutterSecureStorage? secureStorage,
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
       _storage = secureStorage ?? const FlutterSecureStorage(),
       _driveScopes = List.unmodifiable(driveScopes ?? _defaultDriveScopes) {
    _initAuthSession();
  }

  static const List<String> _defaultDriveScopes = [
    drive.DriveApi.driveAppdataScope,
  ];

  static http.Client? authenticatedDriveClient;

  final FirebaseAuth? _firebaseAuthOverride;
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _storage;
  final List<String> _driveScopes;

  GoogleSignInAccount? _googleAccount;
  Map<String, String>? _googleDriveHeaders;
  AppUser? _offlineUser;
  final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();
  StreamSubscription<User?>? _firebaseAuthSubscription;

  static const String _activeOfflineKey = 'active_offline_session';
  static const String _activeOfflineUidKey = 'active_offline_uid';
  static const String _activeOfflineEmailKey = 'active_offline_email';
  static const String _activeOfflineNameKey = 'active_offline_name';

  void _initAuthSession() {
    _loadOfflineSession();
    final auth = _tryGetFirebaseAuth();
    if (auth != null) {
      _firebaseAuthSubscription = auth.authStateChanges().listen((user) {
        if (_offlineUser == null) {
          _authStateController.add(
            user != null ? AppUser.fromFirebase(user) : null,
          );
        }
      });
    }
  }

  Future<void> _loadOfflineSession() async {
    try {
      final isActive = await _storage.read(key: _activeOfflineKey);
      if (isActive == 'true') {
        final uid =
            await _storage.read(key: _activeOfflineUidKey) ??
            'offline_local_user';
        final email =
            await _storage.read(key: _activeOfflineEmailKey) ??
            'offline@filerflow.local';
        final name =
            await _storage.read(key: _activeOfflineNameKey) ?? 'Offline User';
        _offlineUser = AppUser.offline(
          uid: uid,
          email: email,
          displayName: name,
        );
        _authStateController.add(_offlineUser);
      }
    } catch (_) {
      // Storage read error ignored
    }
  }

  FirebaseAuth? _tryGetFirebaseAuth() {
    if (_firebaseAuthOverride != null) return _firebaseAuthOverride;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth get _firebaseAuth {
    final auth = _tryGetFirebaseAuth();
    if (auth == null) {
      throw const AuthServiceException(
        'Firebase authentication is not available.',
      );
    }
    return auth;
  }

  AppUser? get currentUser {
    if (_offlineUser != null) return _offlineUser;
    final auth = _tryGetFirebaseAuth();
    if (auth != null) {
      try {
        final fbUser = auth.currentUser;
        if (fbUser != null) return AppUser.fromFirebase(fbUser);
      } catch (_) {}
    }
    return null;
  }

  bool get isOfflineSession => _offlineUser != null;

  Stream<AppUser?> get userSessionStream => authStateChanges();

  Stream<AppUser?> authStateChanges() async* {
    yield currentUser;
    yield* _authStateController.stream;
  }

  Map<String, String>? get cachedGoogleDriveHeaders => _googleDriveHeaders;

  bool get hasGoogleDriveHeaders => _googleDriveHeaders != null;

  void dispose() {
    _firebaseAuthSubscription?.cancel();
    _authStateController.close();
  }

  Future<AppUser> signInOffline({
    String uid = 'offline_local_user',
    String? email,
    String? displayName,
  }) async {
    final user = AppUser.offline(
      uid: uid,
      email: email ?? 'offline@filerflow.local',
      displayName: displayName ?? 'Offline User',
    );
    _offlineUser = user;
    try {
      await _storage.write(key: _activeOfflineKey, value: 'true');
      await _storage.write(key: _activeOfflineUidKey, value: user.uid);
      await _storage.write(key: _activeOfflineEmailKey, value: user.email ?? '');
      await _storage.write(
        key: _activeOfflineNameKey,
        value: user.displayName ?? '',
      );
    } catch (_) {}
    _authStateController.add(_offlineUser);
    return user;
  }

  Future<void> _cacheOnlineCredentials({
    required String email,
    required String password,
    required String uid,
    String? displayName,
  }) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final creds = {
        'uid': uid,
        'email': normalizedEmail,
        'displayName': displayName ?? '',
        'password': password,
      };
      await _storage.write(
        key: 'offline_cred_$normalizedEmail',
        value: jsonEncode(creds),
      );
    } catch (_) {}
  }

  Future<AppUser?> verifyAndSignInOfflineCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final raw = await _storage.read(key: 'offline_cred_$normalizedEmail');
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cachedPwd = data['password'] as String?;
      if (cachedPwd != null && cachedPwd == password) {
        final uid = data['uid'] as String? ?? 'offline_local_user';
        final displayName = (data['displayName'] as String?)?.isNotEmpty == true
            ? data['displayName'] as String
            : null;
        return await signInOffline(
          uid: uid,
          email: normalizedEmail,
          displayName: displayName,
        );
      }
    } catch (_) {}
    return null;
  }

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
    if (_offlineUser != null) return true;
    final user = _requireCurrentUser();
    try {
      await user.reload();
      return _firebaseAuth.currentUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> updateCurrentUserDisplayName(String displayName) async {
    if (_offlineUser != null) {
      _offlineUser = AppUser.offline(
        uid: _offlineUser!.uid,
        email: _offlineUser!.email,
        displayName: displayName.trim(),
      );
      try {
        await _storage.write(
          key: _activeOfflineNameKey,
          value: displayName.trim(),
        );
      } catch (_) {}
      _authStateController.add(_offlineUser);
      return;
    }
    final user = _requireCurrentUser();
    try {
      await user.updateDisplayName(displayName.trim());
      await user.reload();
      _authStateController.add(
        AppUser.fromFirebase(_firebaseAuth.currentUser ?? user),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(_firebaseAuthMessage(error));
    }
  }

  Future<void> reloadCurrentUser() async {
    if (_offlineUser != null) return;
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

  Future<AppUser?> signUpWithEmail({
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
      await _cacheOnlineCredentials(
        email: email,
        password: password,
        uid: user.uid,
        displayName: name,
      );
      final appUser = AppUser.fromFirebase(user);
      _authStateController.add(appUser);
      return appUser;
    }
    return null;
  }

  Future<AppUser?> signInWithEmail(String email, String password) async {
    try {
      final credential = await signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthServiceException(
          'Email login failed. Please try again.',
        );
      }
      _offlineUser = null;
      try {
        await _storage.delete(key: _activeOfflineKey);
        await _storage.delete(key: _activeOfflineUidKey);
        await _storage.delete(key: _activeOfflineEmailKey);
        await _storage.delete(key: _activeOfflineNameKey);
      } catch (_) {}

      await _cacheOnlineCredentials(
        email: email,
        password: password,
        uid: user.uid,
        displayName: user.displayName,
      );
      final appUser = AppUser.fromFirebase(user);
      _authStateController.add(appUser);
      return appUser;
    } on AuthServiceException catch (error) {
      final msg = error.message.toLowerCase();
      final isNetwork =
          msg.contains('internet') ||
          msg.contains('network') ||
          msg.contains('connection');
      if (isNetwork) {
        final cached = await verifyAndSignInOfflineCredentials(
          email: email,
          password: password,
        );
        if (cached != null) {
          return cached;
        }
        throw const AuthServiceException(
          'Network unavailable and no matching offline credentials found. Check your internet connection or use "Continue in Offline Mode".',
        );
      }
      rethrow;
    }
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
    _offlineUser = null;
    try {
      await _storage.delete(key: _activeOfflineKey);
      await _storage.delete(key: _activeOfflineUidKey);
      await _storage.delete(key: _activeOfflineEmailKey);
      await _storage.delete(key: _activeOfflineNameKey);
    } catch (_) {}
    try {
      await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
    } catch (_) {}
    _authStateController.add(null);
  }

  Future<void> deleteCurrentUser() async {
    if (_offlineUser != null) {
      await signOut();
      return;
    }
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
    if (_offlineUser != null) {
      throw const AuthServiceException(
        'This feature requires an online account. Connect to the internet and sign in.',
      );
    }
    final user = _firebaseAuth.currentUser;
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
