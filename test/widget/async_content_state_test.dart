import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/widgets/async_content_state.dart';
import 'package:gelatino/widgets/skeleton_loader.dart';

void main() {
  testWidgets('loading reserves the configured final geometry', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AsyncContentState.loading(width: 280, height: 160),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AsyncContentState)),
      const Size(280, 160),
    );
    expect(tester.getSize(find.byType(SkeletonBox)), const Size(280, 160));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('empty state recovery action is keyboard reachable and 44 px', (
    tester,
  ) async {
    var recovered = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncContentState.empty(
            width: 320,
            height: 240,
            icon: Icons.bookmark_border,
            title: 'Nessun posto salvato',
            description: 'Esplora le gelaterie.',
            actionLabel: 'Esplora',
            onAction: () => recovered = true,
          ),
        ),
      ),
    );

    final action = find.widgetWithText(FilledButton, 'Esplora');
    expect(
      tester.getSize(action).height,
      greaterThanOrEqualTo(AppLayout.touchTarget),
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(recovered, isTrue);
  });

  testWidgets('error is concise, retries inline and hides raw details', (
    tester,
  ) async {
    var retries = 0;
    const raw = 'FirebaseException: permission-denied /private/path';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncContentState.error(
            width: 320,
            height: 180,
            message: 'Non riusciamo a caricare i contenuti.',
            details: raw,
            onRetry: () => retries++,
          ),
        ),
      ),
    );

    expect(find.text('Non riusciamo a caricare i contenuti.'), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
    final retry = find.widgetWithText(TextButton, 'Riprova');
    expect(retry, findsOneWidget);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    expect(retries, 1);
  });
}
