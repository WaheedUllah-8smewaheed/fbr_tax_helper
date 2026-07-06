import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    String? googleClientId,
    String? googleServerClientId,
    List<String> driveScopes = defaultDriveScopes,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance,
       _googleClientId = googleClientId,
       _googleServerClientId = googleServerClientId,
       _driveScopes = List.unmodifiable(driveScopes);

  static const defaultDriveScopes = <String>[
    drive.DriveApi.driveFileScope,
    drive.DriveApi.driveAppdataScope,
  ];

  static Future<void>? _googleInitializeFuture;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final String? _googleClientId;
  final String? _googleServerClientId;
  final List<String> _driveScopes;

  GoogleSignInAccount? _googleAccount;
  Map<String, String>? _googleDriveHeaders;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> authStateChanges() => _firebaseAuth.authStateChanges();

  Map<String, String>? get cachedGoogleDriveHeaders => _googleDriveHeaders;

  bool get hasGoogleDriveHeaders => _googleDriveHeaders != null;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserCredential> signInWithGoogle({
    bool requestDriveAccess = true,
  }) async {
    await _ensureGoogleInitialized();

    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthServiceException(
        'Google Sign-In is not available on this platform.',
      );
    }

    final account = await _googleSignIn.authenticate(
      scopeHint: requestDriveAccess ? _driveScopes : const <String>[],
    );
    final auth = account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthServiceException(
        'Google Sign-In did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);

    _googleAccount = account;
    if (requestDriveAccess) {
      _googleDriveHeaders = await _loadDriveHeaders(
        account,
        promptIfNecessary: true,
      );
    }

    return userCredential;
  }

  Future<Map<String, String>> getGoogleDriveHeaders({
    bool promptIfNecessary = false,
  }) async {
    await _ensureGoogleInitialized();

    final account = _googleAccount ?? await _restoreGoogleAccount();
    if (account == null) {
      throw const AuthServiceException(
        'Sign in with Google before using Drive sync.',
      );
    }

    final headers = await _loadDriveHeaders(
      account,
      promptIfNecessary: promptIfNecessary,
    );
    _googleDriveHeaders = headers;
    return headers;
  }

  Future<void> refreshGoogleDriveHeaders() async {
    await getGoogleDriveHeaders(promptIfNecessary: true);
  }

  Future<void> signOut() async {
    _googleAccount = null;
    _googleDriveHeaders = null;
    await Future.wait([_firebaseAuth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> disconnectGoogle() async {
    _googleAccount = null;
    _googleDriveHeaders = null;
    await _googleSignIn.disconnect();
  }

  Future<void> _ensureGoogleInitialized() {
    return _googleInitializeFuture ??= _googleSignIn.initialize(
      clientId: _googleClientId,
      serverClientId: _googleServerClientId,
    );
  }

  Future<GoogleSignInAccount?> _restoreGoogleAccount() async {
    final attempt = _googleSignIn.attemptLightweightAuthentication();
    if (attempt == null) return null;
    _googleAccount = await attempt;
    return _googleAccount;
  }

  Future<Map<String, String>> _loadDriveHeaders(
    GoogleSignInAccount account, {
    required bool promptIfNecessary,
  }) async {
    final headers = await account.authorizationClient.authorizationHeaders(
      _driveScopes,
      promptIfNecessary: promptIfNecessary,
    );

    if (headers == null) {
      throw const AuthServiceException(
        'Google Drive permission is required for cloud sync.',
      );
    }

    return Map.unmodifiable(headers);
  }
}

class AuthServiceException implements Exception {
  const AuthServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
