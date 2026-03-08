import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('smoke test all primary screens with QA account', (
    WidgetTester tester,
  ) async {
    debugPrint('SMOKE 01 launch');
    launchApp(tester);
    await loginIfNeeded(tester);

    debugPrint('SMOKE 02 log water');
    if (isPresent(find.text('Log water'))) {
      await tester.tap(find.text('Log water').first);
      await tester.pump();
      await waitFor(tester, find.text('Log water intake'));
      await tester.tap(find.text('500 ml').first);
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Save intake').first);
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 2));
    }

    debugPrint('SMOKE 03 profile edit');
    await openProfile(tester);
    await tester.tap(find.text('Goals').first);
    await tester.pump();
    await waitFor(tester, find.text('Primary focus'));
    await tester.tap(find.text('Strength & Power').first);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Save changes').first);
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pump();
    await waitFor(tester, find.text('Train'));

    debugPrint('SMOKE 04 workouts');
    await tester.tap(find.text('Train').first);
    await tester.pump();
    await waitFor(tester, find.text('Workouts'));
    await tester.tap(find.text('New').first);
    await tester.pump();
    await waitFor(tester, find.text('WORKOUT NAME'));
    await tester.enterText(
      find.byType(TextField).at(0),
      'QA Grocery Run Session',
    );
    await tester.enterText(find.byType(TextField).at(1), 'Goblet Squat');
    await tester.enterText(find.byType(TextField).at(2), '12');
    await tester.enterText(find.byType(TextField).at(3), '18');
    await tester.tap(find.text('Save workout').first);
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 3));

    debugPrint('SMOKE 05 fuel');
    await tester.tap(find.text('Fuel').first);
    await tester.pump();
    await waitFor(tester, find.text("Today's macros"));
    await tester.tap(find.text('Log meal').first);
    await tester.pump();
    await waitFor(tester, find.text('Log a Meal'));
    await tester.enterText(find.byType(TextField).at(0), 'Paneer rice bowl');
    await tester.enterText(find.byType(TextField).at(1), '1 bowl');
    await tester.enterText(find.byType(TextField).at(2), '640');
    await tester.enterText(find.byType(TextField).at(3), '32');
    await tester.enterText(find.byType(TextField).at(4), '58');
    await tester.enterText(find.byType(TextField).at(5), '24');
    await tester.tap(find.text('Save Meal').first);
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));

    debugPrint('SMOKE 06 photos');
    await tester.tap(find.text('Photos').first);
    await tester.pump();
    await waitFor(tester, find.text('Add progress photo'));

    debugPrint('SMOKE 07 stats');
    await tester.tap(find.text('Stats').first);
    await tester.pump();
    await waitFor(tester, find.text('Achievement board'));
    await tester.scrollUntilVisible(
      find.text('Body weight graph'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).first, '78.9');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(find.text('Log').first);
    await tester.pump();
    await pumpFor(tester, const Duration(seconds: 2));

    debugPrint('SMOKE 08 coach');
    await tester.tap(find.text('Coach').first);
    await tester.pump();
    await waitFor(tester, find.text('Coach'));

    debugPrint('SMOKE 09 sign out');
    await tester.tap(find.text('Home').first);
    await tester.pump();
    await waitFor(tester, find.text('Home'));
    await openProfile(tester);
    await tester.tap(find.text('Account').first);
    await tester.pump();
    await waitFor(tester, find.text('Sign out'));
    await tester.tap(find.text('Sign out').first);
    await tester.pump();
    await waitFor(tester, find.text('Sign in'));
  });
}
