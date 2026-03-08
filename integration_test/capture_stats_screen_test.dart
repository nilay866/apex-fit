import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture stats screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tester.tap(find.text('Stats').first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Body Weight'));
    await pumpFor(tester, const Duration(seconds: 1));
    print('CAPTURE stats: screenshot start');
    await binding.takeScreenshot('09-stats-screen');
  });
}
