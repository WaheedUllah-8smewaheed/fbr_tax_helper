import 'package:fbr_tax_helper/features/auth/services/auth_service.dart';
import 'package:fbr_tax_helper/features/splash/presentation/pages/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SplashScreen navigates automatically after duration', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authService: AuthService(),
          nextScreen: const Scaffold(body: Text('Destination Screen')),
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Filer Flow'), findsOneWidget);

    // Advance past the shortened duration (750ms) + reverse (140ms) + route transition (200ms)
    await tester.pump(const Duration(milliseconds: 760));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Destination Screen'), findsOneWidget);
  });

  testWidgets('SplashScreen skips immediately on user tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          authService: AuthService(),
          nextScreen: const Scaffold(body: Text('Immediate Destination')),
        ),
      ),
    );

    expect(find.byType(SplashScreen), findsOneWidget);

    // Tap splash screen immediately
    await tester.tap(find.byType(SplashScreen));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Immediate Destination'), findsOneWidget);
  });
}
