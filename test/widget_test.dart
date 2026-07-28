import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(tester.takeException(), isNull);
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
