import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture coach screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tester.tap(find.text('Coach').first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('AI Coach'));
    await pumpFor(tester, const Duration(seconds: 1));
    print('CAPTURE coach: screenshot start');
    await binding.takeScreenshot('10-coach-screen');
  });
}
