import 'package:firebase_auth/firebase_auth.dart';
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

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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
      await user.reload();
    }
    return user;
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final credential = await signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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
    } on FirebaseAuthException catch (error) {
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
  }

  Future<void> refreshGoogleDriveHeaders() async {
    await getGoogleDriveHeaders(promptIfNecessary: true);
  }

  Future<void> signOut() async {
    _googleAccount = null;
    _clearDriveCredentials();
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
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
    final hasDriveAccess = await _googleSignIn.canAccessScopes(_driveScopes);
    if (!hasDriveAccess) {
      if (!promptIfNecessary) {
        throw const AuthServiceException(
          'Google Drive permission is required for cloud sync.',
        );
      }

      final granted = await _googleSignIn.requestScopes(_driveScopes);
      if (!granted) {
        throw const AuthServiceException(
          'Google Drive permission is required for cloud sync.',
        );
      }
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
      _ => 'Authentication failed. Please try again.',
    };
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
