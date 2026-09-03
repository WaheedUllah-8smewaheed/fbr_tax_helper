import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:fbr_tax_helper/main.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/login_page.dart';
import 'package:fbr_tax_helper/features/auth/presentation/pages/public_calculator_screen.dart';
import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/datasources/tax_local_data_source.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/models/tax_profile_model.dart';
import 'package:fbr_tax_helper/features/tax_calculator/data/repositories/tax_repository_impl.dart';
import 'package:fbr_tax_helper/features/tax_calculator/domain/usecases/calculate_tax_liability.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/bloc/tax_calculator_bloc.dart';
import 'package:fbr_tax_helper/features/splash/presentation/pages/splash_screen.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/pages/tax_calculator_screen.dart';
import 'package:fbr_tax_helper/features/transactions/presentation/pages/add_transaction_page.dart';
import 'package:fbr_tax_helper/features/transactions/services/category_preferences_service.dart';

class FakeLocalDataSource implements TaxLocalDataSource {
  TaxProfileModel? cachedProfile;

  @override
  Future<void> cacheTaxProfile(TaxProfileModel profileToCache) async {
    cachedProfile = profileToCache;
  }

  @override
  Future<TaxProfileModel?> getLastTaxProfile() async => cachedProfile;

  @override
  Future<void> clearTaxProfile() async {
    cachedProfile = null;
  }
}

void main() {
  testWidgets('launches from animated splash, then shows a blank calculator', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(authService: AuthService()));

    expect(find.byType(SplashScreen), findsOneWidget);

    await _pumpPastSplash(tester);

    expect(find.byType(TaxCalculatorScreen), findsOneWidget);
    expect(find.text('Filer Flow'), findsOneWidget);
    expect(find.text('Tax Year 2026-27'), findsWidgets);
    expect(find.text('Monthly gross income'), findsOneWidget);
    expect(find.text('Calculate'), findsOneWidget);
    final incomeField = tester.widget<TextField>(find.byType(TextField));
    expect(incomeField.controller?.text, isEmpty);
    expect(find.text('Start with monthly gross income'), findsOneWidget);
  });

  testWidgets('builds on compact phone screens', (tester) async {
    await _pumpAppAtSize(tester, const Size(360, 640));

    expect(find.text('Filer Flow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds on extra narrow phone screens', (tester) async {
    await _pumpAppAtSize(tester, const Size(320, 640));

    expect(find.text('Filer Flow'), findsOneWidget);
    expect(find.text('Salaried'), findsOneWidget);
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculator scrolls without overflow on short narrow screens', (
    tester,
  ) async {
    await _pumpAppAtSize(tester, const Size(320, 480));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Calculate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('public calculator fits a short phone without scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const MaterialApp(home: PublicCalculatorScreen()));
    await tester.pump();

    expect(find.text('Tax Calculator'), findsOneWidget);
    expect(find.text('Calculate'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds on tablet width screens', (tester) async {
    await _pumpAppAtSize(tester, const Size(900, 700));

    expect(find.text('Filer Flow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks calculator inputs when the card width is constrained', (
    tester,
  ) async {
    await _pumpAppAtSize(tester, const Size(720, 1280));

    final taxYearTop = tester.getTopLeft(
      find.byType(DropdownButtonFormField<String>),
    );
    final incomeTop = tester.getTopLeft(find.byType(TextField));

    expect(incomeTop.dy, greaterThan(taxYearTop.dy + 50));
    expect(find.text('Calculate'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login card fits short phone screens without scrolling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 480);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      RepositoryProvider<AuthService>.value(
        value: AuthService(),
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('forgot password opens dialog with email prefill and allows cancel', (
    tester,
  ) async {
    await tester.pumpWidget(
      RepositoryProvider<AuthService>.value(
        value: AuthService(),
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pump();

    // Type email on login page
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'user@example.com',
    );
    await tester.tap(find.text('Forgot password?'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Forgot Password'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('user@example.com'),
      ),
      findsOneWidget,
    );
    expect(find.text('Send link'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Forgot Password'), findsNothing);
  });

  testWidgets('refresh clears fields and estimate results', (tester) async {
    final bloc = TaxCalculatorBloc(
      calculateTaxUseCase: const CalculateTaxLiability(),
      repository: TaxRepositoryImpl(localDataSource: FakeLocalDataSource()),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(MaterialApp(home: TaxCalculatorScreen(bloc: bloc)));

    await tester.enterText(find.byType(TextField), '150000');
    await tester.tap(find.text('Calculate'));
    await tester.pumpAndSettle();

    expect(find.text('Estimate ready'), findsOneWidget);
    expect(find.text('Filing Receipt'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    var incomeField = tester.widget<TextField>(find.byType(TextField));
    expect(incomeField.controller?.text, '150000');

    await tester.tap(find.byTooltip('Clear calculator'));
    await tester.pumpAndSettle();

    expect(find.text('Estimate ready'), findsNothing);
    expect(find.text('Filing Receipt'), findsNothing);
    expect(find.text('Start with monthly gross income'), findsOneWidget);
    incomeField = tester.widget<TextField>(find.byType(TextField));
    expect(incomeField.controller?.text, isEmpty);
  });

  testWidgets('AddTransactionPage replicates subcategories from preferences without inline add button', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final preferences = CategoryPreferencesService();
    addTearDown(preferences.dispose);
    await preferences.loadForUser('test-user');

    // Add a custom subcategory via preferences (as done from settings)
    await preferences.addSubcategory(
      parentName: 'Bills',
      categoryName: 'Internet Fiber',
      isExpense: true,
    );

    await tester.pumpWidget(
      RepositoryProvider<AuthService>.value(
        value: AuthService(),
        child: MaterialApp(
          home: AddTransactionPage(
            parentCategory: 'Bills',
            categoryOptions: preferences.childrenOf('Bills'),
            categoryPreferences: preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inline add button should NOT be present on AddTransactionPage
    expect(find.text('Add subcategory to Bills'), findsNothing);

    // Newly added subcategory from preferences is replicated on transaction screen
    expect(find.text('Internet Fiber'), findsOneWidget);
  });
}

Future<void> _pumpAppAtSize(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(MyApp(authService: AuthService()));
  await _pumpPastSplash(tester);
}

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 400));
}
