import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/place_state.dart';
import 'package:gelatino/providers/auth_provider.dart';
import 'package:gelatino/providers/place_providers.dart';
import 'package:gelatino/repositories/place_state_repository.dart';
import 'package:gelatino/screens/profile_screen.dart';

void main() {
  testWidgets('first profile remove tap writes saved false', (tester) async {
    final repository = _RecordingPlaceStateRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUidProvider.overrideWithValue('alice'),
          placeStateRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileSavedPlaceRemoveButton(placeId: 'place-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('profile-remove-place-1')),
    );
    await tester.pumpAndSettle();

    expect(repository.savedWrites, <(String, String, bool)>[
      ('alice', 'place-1', false),
    ]);
  });
}

final class _RecordingPlaceStateRepository implements PlaceStateRepository {
  final List<(String, String, bool)> savedWrites = <(String, String, bool)>[];

  @override
  Stream<PlaceState?> watchState(String uid, String placeId) =>
      Stream<PlaceState?>.value(
        PlaceState.empty(placeId).copyWith(saved: true),
      );

  @override
  Future<void> setSaved(String uid, String placeId, bool value) async {
    savedWrites.add((uid, placeId, value));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
