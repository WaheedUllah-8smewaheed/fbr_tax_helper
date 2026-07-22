import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fbr_tax_helper/main.dart';
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

  testWidgets('builds on tablet width screens', (tester) async {
    await _pumpAppAtSize(tester, const Size(900, 700));

    expect(find.text('Filer Flow'), findsOneWidget);
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
