import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture photos screen', (WidgetTester tester) async {
    launchApp(tester);
    await loginIfNeeded(tester);
    await tester.tap(find.text('Photos').first);
    await tester.pump();
    await waitFor(tester, find.text('Add progress photo'));
    await pumpFor(tester, const Duration(seconds: 1));
    print('CAPTURE photos: screenshot start');
    await binding.takeScreenshot('08-photos-screen');
  });
}
