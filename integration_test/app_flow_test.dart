import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke test current primary app flow with QA account', (
    WidgetTester tester,
  ) async {
    launchApp(tester);
    await loginIfNeeded(tester);

    await openProfile(tester);
    await tester.tap(find.text('Strength & Power').first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Save').last);
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pump();

    await tapNav(tester, 'Train');
    await waitFor(tester, find.text('Workouts'));
    await tester.tap(find.byKey(const ValueKey('new_workout_fab')));
    await tester.pump();
    await waitFor(tester, find.byKey(const ValueKey('workout_name_field')));
    await tester.enterText(
      find.byKey(const ValueKey('workout_name_field')),
      'QA Full Flow Session',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise_name_field_0')),
      'Goblet Squat',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise_reps_field_0')),
      '12',
    );
    await tester.enterText(
      find.byKey(const ValueKey('exercise_weight_field_0')),
      '18',
    );
    await tester.tap(find.byKey(const ValueKey('save_workout_button')));
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));
    await waitFor(tester, find.text('QA Full Flow Session'));

    await tapNav(tester, 'Social');
    await waitFor(tester, find.text('Social Feed'));
    await tester.tap(find.byKey(const ValueKey('social_add_community_button')));
    await tester.pump();
    await waitFor(tester, find.text('Add to Community'));
    await tester.enterText(
      find.byKey(const ValueKey('social_search_field')),
      qaFriendQuery.isEmpty ? qaEmail : qaFriendQuery,
    );
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();

    await tapNav(tester, 'Fuel');
    await waitFor(tester, find.text("Today's macros"));
    await tester.tap(find.byKey(const ValueKey('log_meal_fab')));
    await tester.pump();
    await waitFor(tester, find.text('Log a Meal'));
    await tester.enterText(
      find.byKey(const ValueKey('meal_food_field')),
      'Paneer rice bowl',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal_quantity_field')),
      '1 bowl',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal_calories_field')),
      '640',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal_protein_field')),
      '32',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal_carbs_field')),
      '58',
    );
    await tester.enterText(find.byKey(const ValueKey('meal_fat_field')), '24');
    await tester.tap(find.byKey(const ValueKey('save_meal_button')));
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));

    await tapNav(tester, 'Stats');
    await waitFor(tester, find.text('Achievement board'));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('body_weight_input')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byKey(const ValueKey('body_weight_input')),
      '78.9',
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.byKey(const ValueKey('body_weight_log_button')));
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));

    await tapNav(tester, 'Home');
    await openProfile(tester);
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Sign out').first);
    await tester.pump();
    await waitFor(tester, find.text('Sign in'));
  });
}
