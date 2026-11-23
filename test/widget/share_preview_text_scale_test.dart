import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/widgets/share/share_check_in_card.dart';

void main() {
  testWidgets('share preview fits and exports the same at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showShareCheckInPreview(
              context,
              placeName: 'Gelateria',
              rating: 4,
              flavors: const [
                {'name': 'Pistacchio', 'color_hex': '#9CAF5A'},
              ],
              photo: const SizedBox(),
            ),
            child: const Text('apri'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The card is an exported image: device text size must not change it.
    final name = tester.widget<RichText>(
      find.descendant(
        of: find.text('Gelateria'),
        matching: find.byType(RichText),
      ),
    );
    expect(name.textScaler.scale(44), 44);
  });
}
