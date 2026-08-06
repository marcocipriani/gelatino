import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/design/app_tokens.dart';
import 'package:gelatino/theme/app_theme.dart';
import 'package:gelatino/widgets/editorial_card.dart';
import 'package:gelatino/widgets/editorial_header.dart';
import 'package:gelatino/widgets/section_heading.dart';
import 'package:gelatino/widgets/semantic_state_button.dart';
import 'package:gelatino/widgets/skeleton_loader.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = true);

  for (final brightness in Brightness.values) {
    testWidgets(
      '${brightness.name} editorial cards never combine border and elevation',
      (tester) async {
        await tester.pumpWidget(
          _app(
            brightness,
            const Column(
              children: [
                EditorialCard.flat(key: ValueKey('flat'), child: Text('Flat')),
                EditorialCard.overlay(
                  key: ValueKey('overlay'),
                  child: Text('Overlay'),
                ),
              ],
            ),
          ),
        );

        final flat = tester.widget<Material>(
          find.descendant(
            of: find.byKey(const ValueKey('flat')),
            matching: find.byType(Material),
          ),
        );
        final overlay = tester.widget<Material>(
          find.descendant(
            of: find.byKey(const ValueKey('overlay')),
            matching: find.byType(Material),
          ),
        );

        expect(flat.elevation, AppElevation.flat);
        expect((flat.shape! as OutlinedBorder).side.width, 1);
        expect(overlay.elevation, AppElevation.overlay);
        expect((overlay.shape! as OutlinedBorder).side, BorderSide.none);
      },
    );
  }

  testWidgets('header and section heading expose a clear visual hierarchy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Brightness.light,
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EditorialHeader(
              eyebrow: 'Raccolta',
              title: 'Le tue gelaterie',
              description: 'Posti salvati',
            ),
            SectionHeading(title: 'Recenti', description: 'Ultimi salvataggi'),
          ],
        ),
      ),
    );

    final pageTitle = tester.widget<Text>(find.text('Le tue gelaterie'));
    final sectionTitle = tester.widget<Text>(find.text('Recenti'));
    expect(
      pageTitle.style!.fontSize,
      greaterThan(sectionTitle.style!.fontSize!),
    );
    expect(find.text('Raccolta'), findsOneWidget);
    expect(find.text('Ultimi salvataggi'), findsOneWidget);
  });

  testWidgets('compact header wraps actions below copy without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Brightness.light,
        const SizedBox(
          width: 320,
          child: EditorialHeader(
            title: 'Una raccolta dal titolo volutamente lungo',
            actions: [
              FilledButton(onPressed: null, child: Text('Prima azione')),
              FilledButton(onPressed: null, child: Text('Seconda azione')),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Prima azione'), findsOneWidget);
    expect(find.text('Seconda azione'), findsOneWidget);
  });

  testWidgets('compact section heading stacks a wide action below copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Brightness.light,
        const SizedBox(
          width: 320,
          child: SectionHeading(
            title: 'Una sezione dal titolo volutamente molto lungo',
            description: 'Descrizione editoriale',
            action: SizedBox(
              width: 280,
              child: FilledButton(
                onPressed: null,
                child: Text('Azione di sezione molto larga'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final title = tester.getRect(
      find.text('Una sezione dal titolo volutamente molto lungo'),
    );
    final action = find.widgetWithText(
      FilledButton,
      'Azione di sezione molto larga',
    );
    expect(tester.getRect(action).top, greaterThan(title.bottom));
    expect(
      tester.getSize(action).height,
      greaterThanOrEqualTo(AppLayout.touchTarget),
    );
  });

  testWidgets('ordinary skeleton cards stay flat with A1 card geometry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Brightness.light,
        const SizedBox(height: 500, child: GroupsSkeleton()),
      ),
    );

    final cards = tester.widgetList<Card>(find.byType(Card));
    expect(cards, isNotEmpty);
    for (final card in cards) {
      expect(card.elevation, AppElevation.flat);
      final shape = card.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(AppRadii.card));
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('state button communicates selection without relying on color', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Brightness.light,
        SemanticStateButton(
          selected: true,
          selectedLabel: 'Salvata',
          unselectedLabel: 'Salva',
          selectedIcon: Icons.bookmark,
          unselectedIcon: Icons.bookmark_border,
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Salvata'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark), findsOneWidget);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(AppLayout.touchTarget),
    );
    expect(
      tester.getSemantics(find.byType(SemanticStateButton)),
      matchesSemantics(
        label: 'Salvata',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
  });
}

Widget _app(Brightness brightness, Widget child) => MaterialApp(
  theme: brightness == Brightness.light
      ? AppTheme.lightTheme
      : AppTheme.darkTheme,
  home: Scaffold(body: Center(child: child)),
);
