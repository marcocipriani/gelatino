import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/providers/flavor_search_provider.dart';
import 'package:gelatino/providers/places_discovery_provider.dart';
import 'package:gelatino/theme/app_theme.dart';
import 'package:gelatino/widgets/places/place_list.dart';

// Chip render checks: the flavor-match pill's color logic branches on
// whether `colorHex` parses, and the fallback branch must stay readable in
// both light and dark theme (the app follows ThemeMode.system).
void main() {
  Widget wrap(DiscoveryPlace entry, ThemeData theme) => MaterialApp(
    theme: theme,
    home: Scaffold(
      body: PlaceList(
        entries: [entry],
        selectedPlaceId: null,
        onSelect: (_) {},
        onOpenDetail: (_) {},
      ),
    ),
  );

  Place place(String id) => Place(
    id: id,
    name: 'Gelateria $id',
    address: 'Via Test 1',
    location: const GeoPoint(45, 9),
    geohash: 'u0nd9',
    createdAt: DateTime(2026, 7, 15),
  );

  /// Finds the chip's own pill `Container` (nearest `Container` ancestor of
  /// its text) and the `Text` widget, so tests inspect the real
  /// decoration/style the widget renders instead of just its string.
  (Color? background, Color? foreground) chipColors(
    WidgetTester tester,
    String text,
  ) {
    final textFinder = find.text(text);
    final container = tester.widget<Container>(
      find.ancestor(of: textFinder, matching: find.byType(Container)).first,
    );
    final textWidget = tester.widget<Text>(textFinder);
    final decoration = container.decoration as BoxDecoration?;
    return (decoration?.color, textWidget.style?.color);
  }

  testWidgets('valid colorHex: background is the parsed color', (
    tester,
  ) async {
    const chipText = '🍦 Pistacchio · 4★';
    await tester.pumpWidget(
      wrap(
        DiscoveryPlace(
          place: place('p1'),
          flavorMatch: const FlavorPlaceMatch(
            flavorName: 'Pistacchio',
            colorHex: '#8BC34A',
            bestRating: 4,
            tastings: 2,
          ),
        ),
        AppTheme.lightTheme,
      ),
    );
    final (background, _) = chipColors(tester, chipText);
    expect(background, const Color(0xFF8BC34A));
  });

  testWidgets(
    'legacy null colorHex: fallback is theme-aware in light theme',
    (tester) async {
      const chipText = '🍦 Fior di latte · 5★';
      await tester.pumpWidget(
        wrap(
          DiscoveryPlace(
            place: place('p2'),
            flavorMatch: const FlavorPlaceMatch(
              flavorName: 'Fior di latte',
              colorHex: null,
              bestRating: 5,
              tastings: 1,
            ),
          ),
          AppTheme.lightTheme,
        ),
      );
      final scheme = AppTheme.lightTheme.colorScheme;
      final (background, foreground) = chipColors(tester, chipText);
      expect(background, scheme.onSurface.withValues(alpha: 0.1));
      expect(foreground, scheme.onSurface);
    },
  );

  testWidgets('legacy null colorHex: fallback is theme-aware in dark theme', (
    tester,
  ) async {
    const chipText = '🍦 Fior di latte · 5★';
    await tester.pumpWidget(
      wrap(
        DiscoveryPlace(
          place: place('p3'),
          flavorMatch: const FlavorPlaceMatch(
            flavorName: 'Fior di latte',
            colorHex: null,
            bestRating: 5,
            tastings: 1,
          ),
        ),
        AppTheme.darkTheme,
      ),
    );
    final scheme = AppTheme.darkTheme.colorScheme;
    final (background, foreground) = chipColors(tester, chipText);
    expect(background, scheme.onSurface.withValues(alpha: 0.1));
    expect(foreground, scheme.onSurface);
    // Regression guard for the original bug: background and foreground must
    // not collapse to the same near-black in dark theme.
    expect(background, isNot(foreground));
  });

  testWidgets('unparseable colorHex takes the theme-aware fallback branch', (
    tester,
  ) async {
    const chipText = '🍦 Stracciatella · 3★';
    await tester.pumpWidget(
      wrap(
        DiscoveryPlace(
          place: place('p4'),
          flavorMatch: const FlavorPlaceMatch(
            flavorName: 'Stracciatella',
            colorHex: 'not-a-color',
            bestRating: 3,
            tastings: 1,
          ),
        ),
        AppTheme.lightTheme,
      ),
    );
    final scheme = AppTheme.lightTheme.colorScheme;
    final (background, foreground) = chipColors(tester, chipText);
    expect(background, scheme.onSurface.withValues(alpha: 0.1));
    expect(foreground, scheme.onSurface);
  });
}
