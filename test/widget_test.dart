import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fbr_tax_helper/main.dart';
import 'package:fbr_tax_helper/features/tax_calculator/presentation/screens/splash_screen.dart';

void main() {
  testWidgets('launches from splash, then shows a blank calculator', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);

    await _pumpPastSplash(tester);

    expect(find.text('FBR Tax Helper'), findsOneWidget);
    expect(find.text('Tax Year 2026-27'), findsWidgets);
    expect(find.text('Monthly gross income'), findsOneWidget);
    expect(find.text('Calculate'), findsOneWidget);
    final incomeField = tester.widget<TextField>(find.byType(TextField));
    expect(incomeField.controller?.text, isEmpty);
    expect(find.text('Start with monthly gross income'), findsOneWidget);
  });

  testWidgets('builds on compact phone screens', (tester) async {
    await _pumpAppAtSize(tester, const Size(360, 640));

    expect(find.text('FBR Tax Helper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds on tablet width screens', (tester) async {
    await _pumpAppAtSize(tester, const Size(900, 700));

    expect(find.text('FBR Tax Helper'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh clears fields and estimate results', (tester) async {
    await tester.pumpWidget(const MyApp());
    await _pumpPastSplash(tester);

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

  await tester.pumpWidget(const MyApp());
  await _pumpPastSplash(tester);
}

Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1700));
  await tester.pump(const Duration(milliseconds: 400));
}
