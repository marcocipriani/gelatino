import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/design/focus_ring.dart';
import 'package:gelatino/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  test('ordinary cards are flat in both themes', () {
    expect(AppTheme.lightTheme.cardTheme.elevation, 0);
    expect(AppTheme.darkTheme.cardTheme.elevation, 0);
  });

  test('themed controls retain at least a 44 px interactive target', () {
    for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(
        theme.elevatedButtonTheme.style?.minimumSize?.resolve({})?.height,
        greaterThanOrEqualTo(AppLayout.touchTarget),
      );
      expect(
        theme.textButtonTheme.style?.minimumSize?.resolve({})?.height,
        greaterThanOrEqualTo(AppLayout.touchTarget),
      );
      expect(
        theme.filledButtonTheme.style?.minimumSize?.resolve({})?.height,
        greaterThanOrEqualTo(AppLayout.touchTarget),
      );
      expect(
        theme.outlinedButtonTheme.style?.minimumSize?.resolve({})?.height,
        greaterThanOrEqualTo(AppLayout.touchTarget),
      );
      expect(
        theme.iconButtonTheme.style?.minimumSize?.resolve({})?.height,
        greaterThanOrEqualTo(AppLayout.touchTarget),
      );
    }
  });

  test('Plus Jakarta Sans and semantic Gelatino colors remain canonical', () {
    for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, contains('PlusJakarta'));
      expect(theme.colorScheme.primary, AppColors.fragola);
      expect(theme.colorScheme.secondary, AppColors.menta);
      expect(theme.colorScheme.tertiary, AppColors.sorbetto);
    }

    expect(AppTheme.fragolaPop, AppColors.fragola);
    expect(AppTheme.mentaGlaciale, AppColors.menta);
    expect(AppTheme.puffoElettrico, AppColors.puffo);
    expect(AppTheme.sorbettoYuzu, AppColors.sorbetto);
  });

  test('semantic fills and text actions retain AA contrast', () {
    for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
      final scheme = theme.colorScheme;
      expect(_contrastRatio(scheme.primary, scheme.onPrimary), atLeast4_5);
      expect(_contrastRatio(scheme.secondary, scheme.onSecondary), atLeast4_5);
      expect(_contrastRatio(scheme.tertiary, scheme.onTertiary), atLeast4_5);
      expect(_contrastRatio(scheme.error, scheme.onError), atLeast4_5);

      final textAction = theme.textButtonTheme.style!.foregroundColor!.resolve(
        const <WidgetState>{},
      )!;
      expect(_contrastRatio(theme.colorScheme.surface, textAction), atLeast4_5);
    }
  });

  test('semantic error foreground retains AA against each screen canvas', () {
    expect(AppTheme.lightTheme.colorScheme.error, AppColors.error);
    for (final theme in <ThemeData>[AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(
        _contrastRatio(theme.colorScheme.error, theme.scaffoldBackgroundColor),
        atLeast4_5,
        reason: theme.brightness.name,
      );
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} theme shows a geometric 2 px keyboard focus ring',
      (tester) async {
        final theme = brightness == Brightness.light
            ? AppTheme.lightTheme
            : AppTheme.darkTheme;
        final previousStrategy = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() {
          FocusManager.instance.highlightStrategy = previousStrategy;
        });
        final buttonFocusNode = FocusNode();
        addTearDown(buttonFocusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: AppFocusRing(
                child: TextButton(
                  focusNode: buttonFocusNode,
                  onPressed: () {},
                  child: const SizedBox(width: 80, height: 44),
                ),
              ),
            ),
          ),
        );

        final ringFinder = find.byType(AppFocusRing);
        final buttonFinder = find.byType(TextButton);
        final unfocusedButtonRect = tester.getRect(buttonFinder);
        expect(tester.getRect(ringFinder), unfocusedButtonRect);
        expect(_visibleFocusFinder(ringFinder), findsNothing);

        buttonFocusNode.requestFocus();
        await tester.pump();
        await tester.pump(AppFocus.animationDuration);

        expect(tester.getRect(buttonFinder), unfocusedButtonRect);
        expect(tester.getRect(ringFinder), unfocusedButtonRect);
        final focusFinder = _visibleFocusFinder(ringFinder);
        expect(focusFinder, findsOneWidget);
        expect(
          tester.getRect(focusFinder),
          unfocusedButtonRect.inflate(AppFocus.ringGap + AppFocus.ringWidth),
        );
        final decoration =
            tester.widget<DecoratedBox>(focusFinder).decoration
                as BoxDecoration;
        final border = decoration.border! as Border;
        expect(border.top.width, AppFocus.ringWidth);
        expect(border.top.color, AppColors.fragola);
      },
    );
  }

  testWidgets('focus ring does not add a traversal stop around a button', (
    tester,
  ) async {
    final previousStrategy = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() {
      FocusManager.instance.highlightStrategy = previousStrategy;
    });
    final firstNode = FocusNode();
    final secondNode = FocusNode();
    addTearDown(firstNode.dispose);
    addTearDown(secondNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AppFocusRing(
                child: TextButton(
                  focusNode: firstNode,
                  onPressed: () {},
                  child: const Text('First'),
                ),
              ),
              TextButton(
                focusNode: secondNode,
                onPressed: () {},
                child: const Text('Second'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(firstNode.hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(secondNode.hasPrimaryFocus, isTrue);
  });
}

final atLeast4_5 = greaterThanOrEqualTo(4.5);

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

Finder _visibleFocusFinder(Finder ringFinder) => find.descendant(
  of: ringFinder,
  matching: find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    final border = decoration.border;
    return border is Border && border.top.width == AppFocus.ringWidth;
  }),
);
