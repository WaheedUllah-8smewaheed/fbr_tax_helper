import 'package:fbr_tax_helper/features/auth/domain/models/app_user.dart';
import 'package:fbr_tax_helper/features/auth/presentation/bloc/login/login_bloc.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/login_page.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _store[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUser', () {
    test('constructs offline user with default values', () {
      final user = AppUser.offline();
      expect(user.uid, equals('offline_local_user'));
      expect(user.email, equals('offline@filerflow.local'));
      expect(user.displayName, equals('Offline User'));
      expect(user.isOffline, isTrue);
      expect(user.emailVerified, isTrue);
      expect(user.providerData, isEmpty);
    });

    test('supports custom offline user fields', () {
      final user = AppUser.offline(
        uid: 'user_123',
        email: 'ahmed@test.local',
        displayName: 'Ahmed Khan',
      );
      expect(user.uid, equals('user_123'));
      expect(user.email, equals('ahmed@test.local'));
      expect(user.displayName, equals('Ahmed Khan'));
      expect(user.isOffline, isTrue);
    });

    test('equality and hashcode match identical users', () {
      final user1 = AppUser.offline(uid: 'u1', email: 'u1@test.com');
      final user2 = AppUser.offline(uid: 'u1', email: 'u1@test.com');
      expect(user1, equals(user2));
      expect(user1.hashCode, equals(user2.hashCode));
    });
  });

  group('AuthService Offline Capabilities', () {
    late _FakeSecureStorage storage;
    late AuthService authService;

    setUp(() {
      storage = _FakeSecureStorage();
      authService = AuthService(secureStorage: storage);
    });

    test('signInOffline creates session and persists to storage', () async {
      expect(authService.currentUser, isNull);
      expect(authService.isOfflineSession, isFalse);

      final user = await authService.signInOffline(
        uid: 'custom_offline_id',
        email: 'local@device.com',
        displayName: 'Local Citizen',
      );

      expect(user.uid, equals('custom_offline_id'));
      expect(user.isOffline, isTrue);
      expect(authService.currentUser, equals(user));
      expect(authService.isOfflineSession, isTrue);

      // Check persistence in secure storage
      expect(await storage.read(key: 'active_offline_session'), equals('true'));
      expect(
        await storage.read(key: 'active_offline_uid'),
        equals('custom_offline_id'),
      );
      expect(
        await storage.read(key: 'active_offline_email'),
        equals('local@device.com'),
      );
    });

    test('signOut clears offline session from memory and storage', () async {
      await authService.signInOffline();
      expect(authService.currentUser, isNotNull);

      await authService.signOut();
      expect(authService.currentUser, isNull);
      expect(authService.isOfflineSession, isFalse);
      expect(await storage.read(key: 'active_offline_session'), isNull);
    });

    test('verifyAndSignInOfflineCredentials authenticates cached user', () async {
      // Pre-seed a cached online credential
      await storage.write(
        key: 'offline_cred_test@example.com',
        value:
            '{"uid":"online_uid_99","email":"test@example.com","displayName":"Tariq","password":"secretpassword"}',
      );

      // Wrong password fails
      final wrongResult = await authService.verifyAndSignInOfflineCredentials(
        email: 'test@example.com',
        password: 'wrongpassword',
      );
      expect(wrongResult, isNull);
      expect(authService.currentUser, isNull);

      // Correct password succeeds and sets session
      final validResult = await authService.verifyAndSignInOfflineCredentials(
        email: 'test@example.com',
        password: 'secretpassword',
      );
      expect(validResult, isNotNull);
      expect(validResult!.uid, equals('online_uid_99'));
      expect(validResult.email, equals('test@example.com'));
      expect(validResult.displayName, equals('Tariq'));
      expect(authService.currentUser?.uid, equals('online_uid_99'));
      expect(authService.isOfflineSession, isTrue);
    });
  });

  group('LoginBloc Offline Event', () {
    test('LoginWithOfflineModePressed emits [LoginLoading, LoginSuccess]', () async {
      final storage = _FakeSecureStorage();
      final authService = AuthService(secureStorage: storage);
      final bloc = LoginBloc(authService: authService);

      expectLater(bloc.stream, emitsInOrder([LoginLoading(), LoginSuccess()]));

      bloc.add(const LoginWithOfflineModePressed());
      await pumpEventQueue();

      expect(authService.isOfflineSession, isTrue);
      expect(authService.currentUser?.uid, equals('offline_local_user'));
      await bloc.close();
    });
  });

  group('LoginPage Widget', () {
    testWidgets('renders Continue in Offline Mode button and triggers offline login', (
      tester,
    ) async {
      final storage = _FakeSecureStorage();
      final authService = AuthService(secureStorage: storage);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiRepositoryProvider(
            providers: [RepositoryProvider<AuthService>.value(value: authService)],
            child: const LoginPage(),
          ),
        ),
      );

      // Verify the button is rendered on screen
      expect(find.text('Continue in Offline Mode'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      // Tap the button
      await tester.tap(find.text('Continue in Offline Mode'));
      await tester.pump();

      // Verify offline session was started
      expect(authService.isOfflineSession, isTrue);
      expect(authService.currentUser?.isOffline, isTrue);
    });
  });
}
