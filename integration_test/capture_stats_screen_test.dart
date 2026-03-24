import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture stats screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tapNav(tester, 'Stats');
    await waitFor(tester, find.text('Achievement board'));
    await pumpFor(tester, const Duration(seconds: 1));
    debugPrint('CAPTURE stats: screenshot start');
    await binding.takeScreenshot('05-stats-screen');
  });
}
