import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricLockService {
  BiometricLockService({
    LocalAuthentication? localAuthentication,
    FlutterSecureStorage? storage,
  }) : _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _storage = storage ?? const FlutterSecureStorage();

  final LocalAuthentication _localAuthentication;
  final FlutterSecureStorage _storage;

  String _enabledKey(String userId) => 'biometric_lock_enabled_$userId';

  Future<bool> isEnabled(String userId) async {
    try {
      return await _storage.read(key: _enabledKey(userId)) == 'true';
    } on PlatformException catch (error) {
      throw BiometricLockException(
        error.message ?? 'Could not read the app-lock setting.',
      );
    }
  }

  Future<bool> isSupported() async {
    try {
      return await _localAuthentication.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<void> enable(String userId) async {
    if (!await isSupported()) {
      throw const BiometricLockException(
        'Set up a fingerprint, Face ID, or device screen lock first.',
      );
    }
    final authenticated = await _authenticate(
      reason: 'Confirm your identity to enable Filer Flow app lock',
    );
    if (!authenticated) {
      throw const BiometricLockException('Authentication was not completed.');
    }
    try {
      await _storage.write(key: _enabledKey(userId), value: 'true');
    } on PlatformException catch (error) {
      throw BiometricLockException(
        error.message ?? 'Could not save the app-lock setting.',
      );
    }
  }

  Future<void> disable(String userId) async {
    final authenticated = await _authenticate(
      reason: 'Confirm your identity to disable Filer Flow app lock',
    );
    if (!authenticated) {
      throw const BiometricLockException('Authentication was not completed.');
    }
    try {
      await _storage.delete(key: _enabledKey(userId));
    } on PlatformException catch (error) {
      throw BiometricLockException(
        error.message ?? 'Could not remove the app-lock setting.',
      );
    }
  }

  Future<bool> unlock() {
    return _authenticate(reason: 'Authenticate to unlock Filer Flow');
  }

  Future<bool> _authenticate({required String reason}) async {
    try {
      return await _localAuthentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (error) {
      throw BiometricLockException(
        error.message ?? 'Device authentication is unavailable.',
      );
    } catch (_) {
      throw const BiometricLockException(
        'Device authentication could not be started.',
      );
    }
  }
}

class BiometricLockException implements Exception {
  const BiometricLockException(this.message);

  final String message;

  @override
  String toString() => message;
}
