import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/widgets/creamy_card.dart';

void main() {
  group('CreamyCard Widget Tests', () {
    testWidgets('should render child widget correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreamyCard(
              child: Text('Test Child Text'),
            ),
          ),
        ),
      );

      expect(find.text('Test Child Text'), findsOneWidget);
    });

    testWidgets('should apply constraints, padding and margin correctly', (WidgetTester tester) async {
      const padding = EdgeInsets.all(16.0);
      const margin = EdgeInsets.all(24.0);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CreamyCard(
              width: 200,
              height: 100,
              padding: padding,
              margin: margin,
              child: Text('Inside Card'),
            ),
          ),
        ),
      );

      final containerFinder = find.byType(Container).first;
      final container = tester.widget<Container>(containerFinder);

      expect(container.constraints?.maxWidth, 200);
      expect(container.constraints?.maxHeight, 100);
      expect(container.margin, margin);
    });

    testWidgets('should render correctly in Light theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: const Scaffold(
            body: CreamyCard(
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(CreamyCard));
      expect(Theme.of(context).brightness, Brightness.light);
    });

    testWidgets('should render correctly in Dark theme', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: const Scaffold(
            body: CreamyCard(
              child: SizedBox(width: 50, height: 50),
            ),
          ),
        ),
      );

      final BuildContext context = tester.element(find.byType(CreamyCard));
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });
}
