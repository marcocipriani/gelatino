import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/gelato_type.dart';
import 'package:gelatino/widgets/gelato_type_selector.dart';

Widget harness({
  List<GelatoType>? allTypes,
  List<GelatoType>? compactTypes,
  GelatoType? selected,
  ValueChanged<GelatoType>? onSelected,
}) {
  final all = allTypes ?? defaultGelatoTypes;
  return MaterialApp(
    home: Scaffold(
      body: GelatoTypeSelector(
        allTypes: all,
        compactTypes: compactTypes ?? all.take(4).toList(),
        selected: selected,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

void main() {
  group('GelatoTypeSelector', () {
    testWidgets('shows compact types and toggles the full catalog', (
      tester,
    ) async {
      await tester.pumpWidget(harness());

      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('Semifreddo'), findsNothing);

      await tester.tap(find.byKey(const Key('gelato-type-expand')));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(defaultGelatoTypes.length));
      expect(find.text('Semifreddo'), findsOneWidget);

      await tester.tap(find.byKey(const Key('gelato-type-collapse')));
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(4));
      expect(find.text('Semifreddo'), findsNothing);
    });

    testWidgets('emits the selected type', (tester) async {
      GelatoType? selected;
      await tester.pumpWidget(harness(onSelected: (value) => selected = value));

      await tester.tap(find.text('Cono'));

      expect(selected?.id, 'cono');
    });

    testWidgets('marks only the current selection', (tester) async {
      await tester.pumpWidget(harness(selected: defaultGelatoTypes[1]));

      final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
      expect(chips.where((chip) => chip.selected), hasLength(1));
      expect(
        (chips.singleWhere((chip) => chip.selected).label as Text).data,
        'Coppetta',
      );
    });
  });
}
