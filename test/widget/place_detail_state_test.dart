import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place.dart';
import 'package:gelatino/models/place_aggregate.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_aggregate_providers.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/screens/place_detail_screen.dart';
import 'package:gelatino/widgets/semantic_state_button.dart';

final class DetailFakeUser implements User {
  const DetailFakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('place actions stay disabled while private state is loading', (
    tester,
  ) async {
    await pumpDetail(tester, const AsyncLoading<PlaceState?>());

    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('Stato personale non disponibile.'), findsNothing);
  });

  testWidgets('place state error is visible and actions stay disabled', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      AsyncError<PlaceState?>(StateError('offline'), StackTrace.empty),
    );

    expect(saveButton(tester).onPressed, isNull);
    expect(find.text('Stato personale non disponibile.'), findsOneWidget);
  });

  testWidgets('place statistics come from the authoritative aggregate', (
    tester,
  ) async {
    await pumpDetail(tester, const AsyncData<PlaceState?>(null));

    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(
      find.text('Nessuna attività visibile per questa gelateria.'),
      findsNothing,
    );
    expect(
      find.text('Ancora nessun check-in registrato. Fai tu il primo!'),
      findsNothing,
    );
  });
}

Future<void> pumpDetail(
  WidgetTester tester,
  AsyncValue<PlaceState?> state,
) async {
  final place = Place(
    id: 'place-1',
    name: 'Giolitti',
    address: 'Via Uffici del Vicario 40',
    location: const GeoPoint(41.9, 12.5),
    geohash: 'sr2yk',
    createdAt: DateTime(2026, 7, 15),
    addedByUid: 'alice',
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(const DetailFakeUser('alice')),
        currentUidProvider.overrideWithValue('alice'),
        placesProvider.overrideWith((ref) => Stream.value(<Place>[place])),
        placeAggregateProvider.overrideWith(
          (ref, placeId) => AsyncData<PlaceAggregate?>(
            PlaceAggregate(
              placeId: placeId,
              checkInCount: 8,
              ratingSum: 36,
              ratingAverage: 4.5,
              updatedAt: DateTime(2026, 7, 15),
            ),
          ),
        ),
        placeStateProvider.overrideWith((ref, placeId) => state),
      ],
      child: const MaterialApp(home: PlaceDetailScreen(placeId: 'place-1')),
    ),
  );
  await tester.pumpAndSettle();
}

SemanticStateButton saveButton(WidgetTester tester) =>
    tester.widget<SemanticStateButton>(
      find.byKey(const ValueKey<String>('place-save-action')),
    );
