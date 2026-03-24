import 'package:apex_ai/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildAuthScreen() {
    return MaterialApp(home: AuthScreen(onAuth: () {}));
  }

  Future<void> pumpAuthScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildAuthScreen());
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows validation error when sign-in fields are empty', (
    WidgetTester tester,
  ) async {
    await pumpAuthScreen(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('auth_submit_button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pump();

    expect(find.text('Enter email and password.'), findsOneWidget);
  });

  testWidgets('requires a name when creating an account', (
    WidgetTester tester,
  ) async {
    await pumpAuthScreen(tester);

    await tester.tap(find.text('Create account'));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(
      find.byKey(const ValueKey('auth_email_field')),
      'qa@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      '12345678',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('auth_submit_button')),
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pump();

    expect(find.text('Name required.'), findsOneWidget);
  });
}
