import 'package:fbr_tax_helper/core/database/tax_database.dart';
import 'package:fbr_tax_helper/core/theme/app_theme.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/session_router.dart';
import 'dart:io' show Platform;
import 'package:fbr_tax_helper/features/splash/presentation/pages/splash_screen.dart';
import 'package:fbr_tax_helper/features/transactions/data/datasources/transaction_local_data_source.dart';
import 'package:fbr_tax_helper/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fbr_tax_helper/firebase_options.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void main() async {
  if (kIsWeb) {
    // For web
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // For desktop
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  runApp(MyApp());
}

Future<void> _activateAppCheck() async {
  // A web app needs its own reCAPTCHA v3 site key. Do not ship a placeholder
  // key: Firebase App Check must be configured before web enforcement is on.
  const webSiteKey = String.fromEnvironment('FBR_HELPER_RECAPTCHA_V3_SITE_KEY');
  if (kIsWeb) {
    if (webSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(webSiteKey),
      );
    }
    return;
  }

  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.deviceCheck,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, AuthService? authService})
    : _authService = authService,
      _useSessionRouter = authService == null;

  final AuthService? _authService;
  final bool _useSessionRouter;

  @override
  Widget build(BuildContext context) {
    final authService = _authService ?? AuthService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authService),
        RepositoryProvider(
          create: (context) => TransactionRepositoryImpl(
            localDataSource: TransactionLocalDataSourceImpl(
              databaseHelper: TaxDatabase.instance,
            ),
          ),
        ),
      ],
      child: BlocProvider(
        create: (context) => TransactionBloc(
          transactionRepository: context.read<TransactionRepositoryImpl>(),
          authService: context.read<AuthService>(),
        ),
        child: MaterialApp(
          title: 'Filer Flow',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) {
            if (!_useSessionRouter) {
              return _AppThemeFrame(
                isAuthenticated: false,
                child: child ?? const SizedBox.shrink(),
              );
            }
            return StreamBuilder<User?>(
              stream: authService.authStateChanges(),
              initialData: authService.currentUser,
              builder: (context, session) => _AppThemeFrame(
                isAuthenticated: session.data != null,
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: SplashScreen(
            authService: authService,
            nextScreen: _useSessionRouter ? const SessionRouter() : null,
          ),
        ),
      ),
    );
  }
}

class _AppThemeFrame extends StatelessWidget {
  const _AppThemeFrame({required this.isAuthenticated, required this.child});

  final bool isAuthenticated;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isAuthenticated ? AppTheme.authenticated : AppTheme.light,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isAuthenticated
                ? const [
                    Color(0xFFE8FAF4),
                    Color(0xFFF4F0FF),
                    Color(0xFFFFF2E5),
                    Color(0xFFEAF4FF),
                  ]
                : const [
                    AppColors.mintSoft,
                    AppColors.background,
                    AppColors.goldSurface,
                  ],
            stops: isAuthenticated
                ? const [0, 0.36, 0.7, 1]
                : const [0, 0.62, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}
