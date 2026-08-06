import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router and login depend on the injected auth session', () {
    final router = File('lib/router.dart').readAsStringSync();
    final login = File('lib/screens/login_screen.dart').readAsStringSync();

    expect(router, contains('appRouterProvider'));
    expect(router, contains('routerAuthSessionProvider'));
    expect(login, contains('routerAuthSessionProvider'));
    expect(router, isNot(contains('FirebaseAuth.instance')));
    expect(login, isNot(contains('FirebaseAuth.instance')));
  });

  test('collection consumes saved private place state only', () {
    for (final path in <String>['lib/screens/collection_screen.dart']) {
      final source = File(path).readAsStringSync();

      expect(source, contains('savedPlacesProvider'), reason: path);
      expect(source, isNot(contains('likedPlacesProvider')), reason: path);
      expect(source, isNot(contains('favoritePlacesProvider')), reason: path);
      expect(source, isNot(contains('wishlisted_by_uids')), reason: path);
      expect(source, isNot(contains('favorited_by_uids')), reason: path);
      expect(source, isNot(contains('liked_by_uids')), reason: path);
    }
  });

  test('runtime has no global users or check-ins collection query', () {
    final runtime = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in runtime) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(matches(RegExp(r'''collection\(['"]users['"]\)'''))),
        reason: file.path,
      );
      expect(
        source,
        isNot(matches(RegExp(r'''collection\(['"]check_ins['"]\)'''))),
        reason: file.path,
      );
    }
  });

  test(
    'interactive runtime excludes legacy arrays and server-owned writes',
    () {
      final runtime = <String>[
        ...Directory(
          'lib/screens',
        ).listSync(recursive: true).whereType<File>().map((file) => file.path),
        ...Directory(
          'lib/providers',
        ).listSync(recursive: true).whereType<File>().map((file) => file.path),
        ...Directory(
          'lib/widgets',
        ).listSync(recursive: true).whereType<File>().map((file) => file.path),
      ].where((path) => path.endsWith('.dart'));

      for (final path in runtime) {
        final source = File(path).readAsStringSync();
        for (final forbidden in <String>[
          'friend_uids',
          'liked_by_uids',
          'favorited_by_uids',
          'wishlisted_by_uids',
          'addPoints',
          'incrementAffinity',
          'bootstrapRomePlaces',
          'bootstrapDefaultFlavors',
          '41.9028',
          '12.4964',
        ]) {
          expect(
            source,
            isNot(contains(forbidden)),
            reason: '$path: $forbidden',
          );
        }
      }
    },
  );
}
