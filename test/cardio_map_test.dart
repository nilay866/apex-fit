import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:apex_ai/screens/cardio_map_screen.dart';
import 'package:flutter_map/flutter_map.dart';

void main() {
  testWidgets('CardioMapScreen rendering smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MaterialApp(
        home: CardioMapScreen(
          workout: const {'name': 'Running'},
          onFinish: () {},
        ),
      ),
    );

    // Verify that the FlutterMap widget is present
    expect(find.byType(FlutterMap), findsOneWidget);
    
    // Verify that TileLayer and PolylineLayer are present
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });
}
