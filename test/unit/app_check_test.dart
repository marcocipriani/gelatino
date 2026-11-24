import 'package:flutter_test/flutter_test.dart';
import 'package:gelatino/firebase/app_check.dart';

void main() {
  test('App Check stays off on emulators and on web without a site key', () {
    expect(
      appCheckSkipReason(usesEmulators: true, isWeb: false, webSiteKey: 'k'),
      'emulators',
    );
    expect(
      appCheckSkipReason(usesEmulators: false, isWeb: true, webSiteKey: ''),
      isNotNull,
    );
    expect(
      appCheckSkipReason(usesEmulators: false, isWeb: true, webSiteKey: 'k'),
      isNull,
    );
    expect(
      appCheckSkipReason(usesEmulators: false, isWeb: false, webSiteKey: ''),
      isNull,
    );
  });
}
