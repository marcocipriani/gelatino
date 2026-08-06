import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/models/public_profile.dart';
import 'package:gelatino/screens/check_in/share_step.dart';
import 'package:gelatino/widgets/share/share_check_in_card.dart';

// Minimal 1x1 transparent PNG so Image.memory decodes without error.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42Y'
  'AAAAASUVORK5CYII=',
);

void main() {
  Widget wrap({required bool hasPrivatePhoto, Uint8List? photoBytes}) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ShareStep(
              placeName: 'Gelateria La Romana',
              typeName: 'Cono',
              flavorNames: const <String>['Pistacchio'],
              shareFlavors: const <Map<String, dynamic>>[
                <String, dynamic>{'name': 'Pistacchio', 'color_hex': '#93C572'},
              ],
              rating: 4,
              reviewText: '',
              hasPrivatePhoto: hasPrivatePhoto,
              photoBytes: photoBytes,
              friends: const AsyncData<List<PublicProfile>>(<PublicProfile>[]),
              selectedFriendIds: const <String>[],
              selectedFriendNames: const <String>[],
              enabled: true,
              onFriendChanged: (_, _) {},
              onRetryFriends: () {},
              onClearSelectedFriends: () {},
              publicationFailed: false,
            ),
          ),
        ),
      );

  testWidgets('secondary share button opens the branded card preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(hasPrivatePhoto: true, photoBytes: _onePixelPng),
    );

    expect(find.text('Condividi la tua card'), findsOneWidget);
    await tester.tap(find.text('Condividi la tua card'));
    await tester.pumpAndSettle();

    expect(find.byType(ShareCheckInCard), findsOneWidget);
    expect(find.text('Gelateria La Romana'), findsWidgets);
  });

  testWidgets('button is hidden until the private photo is ready', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(hasPrivatePhoto: false, photoBytes: null));
    expect(find.text('Condividi la tua card'), findsNothing);
  });
}
