import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture home screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tapNav(tester, 'Home');
    await pumpFor(tester, const Duration(seconds: 1));
    debugPrint('CAPTURE home: screenshot start');
    await binding.takeScreenshot('01-home-screen');
  });
}
