import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/constants/app_strings.dart';
import 'package:gelatino/widgets/share/share_check_in_card.dart';

void main() {
  testWidgets('card renders place, rating and flavor chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShareCheckInCard(
          placeName: 'Gelateria La Romana',
          rating: 5,
          flavors: const [
            {'name': 'Pistacchio', 'color_hex': '#93C572'},
            {'name': 'Limone', 'color_hex': null},
          ],
          photo: const ColoredBox(color: Color(0xFFEEEEEE)),
        ),
      ),
    );
    expect(find.text('Gelateria La Romana'), findsOneWidget);
    expect(find.text('Pistacchio'), findsOneWidget);
    expect(find.text('Limone'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNWidgets(5));
  });

  testWidgets('a failed share shows an error and re-enables the button', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showShareCheckInPreview(
                context,
                placeName: 'Gelateria La Romana',
                rating: 5,
                flavors: const [],
                photo: const ColoredBox(color: Color(0xFFEEEEEE)),
                onShare: (_, {required placeName}) async {
                  throw Exception('boom');
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.shareCardPreviewConfirm));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.shareCardFailed), findsOneWidget);
    // The button is usable again: label is back, no spinner left behind.
    expect(find.text(AppStrings.shareCardPreviewConfirm), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
