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
  runApp(MyApp());
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
          home: SplashScreen(
            authService: authService,
            nextScreen: _useSessionRouter ? const SessionRouter() : null,
          ),
        ),
      ),
    );
  }
}
