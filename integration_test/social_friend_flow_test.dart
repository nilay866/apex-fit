import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('community modal supports search and optional friend connect', (
    WidgetTester tester,
  ) async {
    launchApp(tester);
    await loginIfNeeded(tester);

    await tapNav(tester, 'Social');
    await waitFor(tester, find.text('Social Feed'));

    await tester.tap(find.byKey(const ValueKey('social_add_community_button')));
    await tester.pump();
    await waitFor(tester, find.text('Add to Community'));
    await waitFor(tester, find.byKey(const ValueKey('social_search_field')));

    final query = qaFriendQuery.isEmpty ? qaEmail : qaFriendQuery;
    await tester.enterText(
      find.byKey(const ValueKey('social_search_field')),
      query,
    );
    await pumpFor(tester, const Duration(seconds: 2));

    final connectButtons = find.text('Connect');
    if (qaFriendQuery.isNotEmpty && isPresent(connectButtons)) {
      await tester.tap(connectButtons.first);
      await tester.pump();
      await pumpFor(tester, const Duration(seconds: 2));
    } else {
      expect(find.text('MY ATHLETE CODE'), findsOneWidget);
    }
  });
}
