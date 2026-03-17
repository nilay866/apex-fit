import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture active workout screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);

    await tapNav(tester, 'Train');
    await waitFor(tester, find.text('Workouts'));
    await tester.tap(find.byKey(const ValueKey('new_workout_fab')));
    await tester.pump();
    await waitFor(tester, find.byKey(const ValueKey('workout_name_field')));
    await tester.enterText(
      find.byKey(const ValueKey('workout_name_field')),
      'QA Capture Session',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise_name_field_0')),
      'Bench Press',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise_reps_field_0')),
      '8',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise_weight_field_0')),
      '60',
    );
    await tester.tap(find.byKey(const ValueKey('save_workout_button')));
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));

    await tester.tap(find.text('QA Capture Session').first);
    await tester.pump();
    await waitFor(tester, find.text('Start workout'));
    await tester.tap(find.text('Start workout').first);
    await tester.pump();
    await waitFor(tester, find.text('Finish workout'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    debugPrint('CAPTURE active workout: screenshot start');
    await binding.takeScreenshot('06-active-workout');
  });
}
