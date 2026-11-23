import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/flavor.dart';
import 'package:gelatino/providers/flavors_provider.dart';
import 'package:gelatino/providers/profile_providers.dart';
import 'package:gelatino/widgets/flavors_manager.dart';

void main() {
  testWidgets('a failed flavour catalog can be retried', (tester) async {
    var reads = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ownProfileProvider.overrideWith((ref) => Stream.value(null)),
          flavorsProvider.overrideWith((ref) {
            reads++;
            return reads == 1
                ? Stream<List<Flavor>>.error(StateError('network down'))
                : Stream.value(<Flavor>[Flavor(id: 'p', name: 'Pistacchio')]);
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: FlavorsManager())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riprova'));
    await tester.pumpAndSettle();
    expect(find.text('Pistacchio'), findsOneWidget);
  });
}
