import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture fuel screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tapNav(tester, 'Fuel');
    await waitFor(tester, find.text("Today's macros"));
    await pumpFor(tester, const Duration(seconds: 1));
    debugPrint('CAPTURE fuel: screenshot start');
    await binding.takeScreenshot('04-fuel-screen');
  });
}
