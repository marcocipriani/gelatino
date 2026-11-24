import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/constants/app_strings.dart';
import 'package:gelatino/repositories/friendship_repository.dart';

void main() {
  tearDown(() => AppStrings.english = false);

  test('Italian devices get Italian, everyone else English', () {
    AppStrings.useDeviceLocale('it');
    expect(AppStrings.logout, 'Esci');
    expect(AppStrings.savedPlacesCount(2), '2 gelaterie salvate');

    AppStrings.useDeviceLocale('de');
    expect(AppStrings.logout, 'Log out');
    expect(AppStrings.savedPlacesCount(2), '2 saved gelaterias');
    expect(AppStrings.checkInStepLabels.first, 'Photo');
  });

  test('const failures translate their Italian message when read', () {
    const failure = FriendshipStateFailure();
    expect(failure.message, 'Questa amicizia non è più modificabile.');
    AppStrings.english = true;
    expect(failure.message, 'This friendship can no longer be changed.');
    expect(AppStrings.translated('Testo sconosciuto'), 'Testo sconosciuto');
  });
}
