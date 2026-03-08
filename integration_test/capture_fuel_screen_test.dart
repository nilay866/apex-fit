import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture fuel screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tester.tap(find.text('Fuel').first);
    await tester.pump();
    await waitFor(tester, find.text("Today's macros"));
    await pumpFor(tester, const Duration(seconds: 1));
    print('CAPTURE fuel: screenshot start');
    await binding.takeScreenshot('07-fuel-screen');
  });
}
