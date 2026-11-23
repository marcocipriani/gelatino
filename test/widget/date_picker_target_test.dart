import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/screens/check_in/experience_step.dart';
import 'package:gelatino/theme/app_theme.dart';

void main() {
  testWidgets(
    'desktop date picker days are 44pt targets',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final note = TextEditingController();
      addTearDown(note.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: ExperienceStep(
              rating: 4,
              reviewController: note,
              enabled: true,
              onRatingChanged: (_) {},
              onReviewChanged: (_) {},
              consumedAt: null,
              onConsumedAtChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('check-in-consumed-at')));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();
      await tester.pump();
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
