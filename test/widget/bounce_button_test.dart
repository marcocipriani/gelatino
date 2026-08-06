import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/widgets/bounce_button.dart';

void main() {
  group('BounceButton Widget Tests', () {
    testWidgets('should render child correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: BounceButton(
              child: Text('Interactive Button'),
            ),
          ),
        ),
      );

      expect(find.text('Interactive Button'), findsOneWidget);
    });

    testWidgets('should execute onTap callback when tapped', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BounceButton(
              onTap: () {
                tapped = true;
              },
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      final buttonFinder = find.text('Tap Me');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('should scale down on tap down and revert on tap up', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BounceButton(
              onTap: () {},
              child: const SizedBox(width: 100, height: 100, child: Text('Scale Check')),
            ),
          ),
        ),
      );

      final transformFinder = find.descendant(
        of: find.byType(BounceButton),
        matching: find.byType(Transform),
      );
      expect(transformFinder, findsOneWidget);

      // Initial scale should be 1.0
      Transform transform = tester.widget<Transform>(transformFinder);
      expect(transform.transform.entry(0, 0), 1.0);

      // Press down (trigger scale animation start)
      final gesture = await tester.press(find.byType(BounceButton));
      await tester.pump(); // Start animation frame
      await tester.pump(const Duration(milliseconds: 100)); // Finish animation duration

      // Scale should be scaled down (1 - 0.15 = 0.85)
      transform = tester.widget<Transform>(transformFinder);
      expect(transform.transform.entry(0, 0), closeTo(0.85, 0.01));

      // Release touch (reverse animation)
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // Revert duration

      // Scale should return to 1.0
      transform = tester.widget<Transform>(transformFinder);
      expect(transform.transform.entry(0, 0), 1.0);
    });
  });
}
