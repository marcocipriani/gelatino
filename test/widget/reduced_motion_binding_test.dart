import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/motion.dart';

class _TestBinding extends AutomatedTestWidgetsFlutterBinding
    with ReduceMotionBinding {}

void main() {
  // Its own file: a process gets one binding.
  _TestBinding();

  testWidgets('iOS Reduce Motion also stills framework-owned animation', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );
    showModalBottomSheet<void>(
      context: tester.element(find.byType(Scaffold)),
      builder: (_) => const SizedBox(height: 200, child: Text('sheet')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    final landed = tester.getTopLeft(find.text('sheet')).dy;
    await tester.pumpAndSettle();
    expect(landed, tester.getTopLeft(find.text('sheet')).dy);
  });
}
