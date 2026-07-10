import 'package:fbr_tax_helper/database/tax_db.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/session_router.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/screens/splash_screen.dart';
import 'package:fbr_tax_helper/features/transactions/data/datasources/transaction_local_data_source.dart';
import 'package:fbr_tax_helper/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/bloc/transaction_bloc.dart';
import 'package:fbr_tax_helper/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
          title: 'FilerFlow',
          theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
          home: _useSessionRouter
              ? const SessionRouter()
              : SplashScreen(authService: authService),
        ),
      ),
    );
  }
}
