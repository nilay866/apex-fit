import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture train screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    print('CAPTURE train: nav');
    await tester.tap(find.text('Train').first);
    await tester.pump();
    await waitFor(tester, find.text('Workouts'));
    await pumpFor(tester, const Duration(seconds: 1));
    print('CAPTURE train: screenshot start');
    await binding.takeScreenshot('05-train-library');
    print('CAPTURE train: screenshot done');
  });
}
