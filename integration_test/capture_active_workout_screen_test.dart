import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture active workout screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tester.tap(find.text('Train').first);
    await tester.pump();
    await waitFor(tester, find.text('Workouts'));
    await pumpFor(tester, const Duration(seconds: 1));
    await waitFor(tester, find.text('Start workout'));
    await tester.tap(find.text('Start workout').first);
    await tester.pump();
    await waitFor(tester, find.text('Finish workout'));
    await pumpFor(tester, const Duration(milliseconds: 800));
    print('CAPTURE active workout: screenshot start');
    await binding.takeScreenshot('06-active-workout');
  });
}
