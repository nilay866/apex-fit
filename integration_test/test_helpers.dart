import 'dart:async';

import 'package:apex_ai/main.dart' as app;
import 'package:apex_ai/widgets/apex_orb_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String qaEmail = String.fromEnvironment('QA_EMAIL');
const String qaPassword = String.fromEnvironment('QA_PASSWORD');
const String qaFriendQuery = String.fromEnvironment('QA_FRIEND_QUERY');

void launchApp(WidgetTester tester) {
  if (qaEmail.isEmpty || qaPassword.isEmpty) {
    fail('QA_EMAIL and QA_PASSWORD must be passed with --dart-define.');
  }
  app.main();
}

Future<void> loginIfNeeded(WidgetTester tester) async {
  await pumpFor(tester, const Duration(seconds: 3));
  if (isPresent(find.text('Sign in'))) {
    await tester.enterText(
      find.byKey(const ValueKey('auth_email_field')),
      qaEmail,
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth_password_field')),
      qaPassword,
    );
    await tester.tap(find.byKey(const ValueKey('auth_submit_button')));
    await tester.pump();
  }
  await waitFor(tester, find.byKey(const ValueKey('nav_home')));
  await pumpFor(tester, const Duration(seconds: 2));
}

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(
    find
        .byWidgetPredicate(
          (widget) => widget is ApexOrbLogo && widget.onTap != null,
        )
        .first,
  );
  await tester.pump();
  await waitFor(tester, find.text('Goals'));
}

Future<void> tapNav(WidgetTester tester, String label) async {
  final finder = find.byKey(ValueKey('nav_${label.toLowerCase()}'));
  if (isPresent(finder)) {
    await tester.tap(finder);
  } else {
    await tester.tap(find.text(label).first);
  }
  await tester.pump();
  await pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (isPresent(finder)) {
      return;
    }
  }
  throw TimeoutException('Timed out waiting for $finder');
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  final int steps = duration.inMilliseconds ~/ 100;
  for (int i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

bool isPresent(Finder finder) => finder.evaluate().isNotEmpty;
